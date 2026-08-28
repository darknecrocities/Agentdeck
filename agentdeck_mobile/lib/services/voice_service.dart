import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  final ValueNotifier<bool> isListening = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);
  final ValueNotifier<String> lastWords = ValueNotifier<String>('');
  final ValueNotifier<double> soundLevel = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> isPluginAvailable = ValueNotifier<bool>(true);

  bool _ttsEnabled = true;
  bool _autoPauseMicOnTts = true;
  double _speechRate = 0.44; // Natural, conversational speed
  double _speechPitch = 0.50; // Deep male AI voice (Android pitch 0.50)
  bool _initialized = false;
  List<Map<String, String>> _deviceVoices = [];
  bool _voicesLoaded = false;

  bool get ttsEnabled => _ttsEnabled;
  bool get autoPauseMicOnTts => _autoPauseMicOnTts;
  double get speechRate => _speechRate;
  double get speechPitch => _speechPitch;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _ttsEnabled = prefs.getBool('voice_tts_enabled') ?? true;
      _autoPauseMicOnTts = prefs.getBool('voice_auto_pause_mic') ?? true;
      _speechRate = prefs.getDouble('voice_speech_rate') ?? 0.44;
      _speechPitch = prefs.getDouble('voice_speech_pitch') ?? 0.50;

      // Configure TTS handlers safely
      try {
        await _tts.setSharedInstance(true);
        await _tts.awaitSpeakCompletion(true);
        await _tts.setLanguage("en-US");

        _tts.setStartHandler(() {
          isSpeaking.value = true;
          if (_autoPauseMicOnTts && isListening.value) {
            stopListening();
          }
        });

        _tts.setCompletionHandler(() {
          isSpeaking.value = false;
        });

        _tts.setCancelHandler(() {
          isSpeaking.value = false;
        });

        _tts.setErrorHandler((msg) {
          isSpeaking.value = false;
          debugPrint('TTS Error: $msg');
        });

        await _loadDeviceVoices();
        await _applyMaleVoice();
      } on MissingPluginException catch (_) {
        debugPrint('Notice: flutter_tts native binding requires a full "flutter run" restart.');
        isPluginAvailable.value = false;
      } catch (e) {
        debugPrint('TTS init error: $e');
      }

      // Init STT safely
      try {
        await _stt.initialize(
          onError: (err) {
            isListening.value = false;
            debugPrint('STT Error: ${err.errorMsg}');
          },
          onStatus: (status) {
            if (status == 'notListening' || status == 'done') {
              isListening.value = false;
            } else if (status == 'listening') {
              isListening.value = true;
            }
          },
        );
      } on MissingPluginException catch (_) {
        debugPrint('Notice: speech_to_text native binding requires a full "flutter run" restart.');
        isPluginAvailable.value = false;
      } catch (e) {
        debugPrint('STT init error: $e');
      }
    } catch (e) {
      debugPrint('VoiceService init failed: $e');
    }
  }

  Future<void> _loadDeviceVoices() async {
    if (_voicesLoaded) return;
    try {
      final voices = await _tts.getVoices;
      if (voices is List && voices.isNotEmpty) {
        _deviceVoices = List<Map<String, String>>.from(
          voices.map((v) {
            if (v is Map) {
              return Map<String, String>.from(v.map((k, val) => MapEntry(k.toString(), val.toString())));
            }
            return <String, String>{};
          }).where((m) => m.isNotEmpty),
        );
        _voicesLoaded = true;
      }
    } catch (e) {
      debugPrint('[TTS] Failed to fetch device voices: $e');
    }
  }

  // Enforces the single deep male voice exclusively
  Future<void> _applyMaleVoice() async {
    if (!_voicesLoaded) {
      await _loadDeviceVoices();
    }

    final isAndroid = Platform.isAndroid;
    Map<String, String>? selectedMaleVoice;

    // Priority male neural voices
    final priorityMaleKeys = [
      'en-us-x-rgd', // Deep Male
      'en-us-x-iom', // Bold Male
      'en-us-x-iol',
      'en-us-x-tpd',
      'daniel',
      'arthur',
      'gordon',
      'david',
      'guy',
      'wavenet-d',
      'wavenet-b',
      'male',
    ];

    // Filter English voices
    final englishVoices = _deviceVoices.where((v) {
      final loc = (v['locale'] ?? v['language'] ?? '').toLowerCase();
      return loc.startsWith('en');
    }).toList();

    // 1. Try finding explicit male priority keys while rejecting all female voices
    for (final key in priorityMaleKeys) {
      for (final v in englishVoices) {
        final name = (v['name'] ?? '').toLowerCase();
        if (name.contains('female') ||
            name.contains('sfg') ||
            name.contains('iob') ||
            name.contains('tpc') ||
            name.contains('samantha') ||
            name.contains('karen') ||
            name.contains('aria') ||
            name.contains('zira')) {
          continue;
        }
        if (name.contains(key)) {
          selectedMaleVoice = v;
          break;
        }
      }
      if (selectedMaleVoice != null) break;
    }

    // 2. Fallback: Filter out all female voices
    if (selectedMaleVoice == null) {
      final nonFemale = englishVoices.where((v) {
        final name = (v['name'] ?? '').toLowerCase();
        return !name.contains('female') &&
            !name.contains('sfg') &&
            !name.contains('iob') &&
            !name.contains('tpc') &&
            !name.contains('samantha') &&
            !name.contains('karen') &&
            !name.contains('zira');
      }).toList();

      if (nonFemale.isNotEmpty) {
        selectedMaleVoice = nonFemale.first;
      }
    }

    if (selectedMaleVoice != null) {
      try {
        await _tts.setVoice(selectedMaleVoice);
      } catch (e) {
        debugPrint('[TTS] Failed to set voice: $e');
      }
    }

    final targetPitch = isAndroid ? 0.50 : 0.75;
    _speechPitch = targetPitch;
    try {
      await _tts.setPitch(targetPitch);
      await _tts.setSpeechRate(_speechRate);
    } catch (_) {}
  }

  Future<void> updateSettings({
    bool? ttsEnabled,
    bool? autoPauseMic,
    double? rate,
    double? pitch,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (ttsEnabled != null) {
      _ttsEnabled = ttsEnabled;
      await prefs.setBool('voice_tts_enabled', ttsEnabled);
    }
    if (autoPauseMic != null) {
      _autoPauseMicOnTts = autoPauseMic;
      await prefs.setBool('voice_auto_pause_mic', autoPauseMic);
    }
    if (rate != null) {
      _speechRate = rate;
      try {
        await _tts.setSpeechRate(rate);
      } catch (_) {}
      await prefs.setDouble('voice_speech_rate', rate);
    }
    if (pitch != null) {
      _speechPitch = pitch;
      try {
        await _tts.setPitch(pitch);
      } catch (_) {}
      await prefs.setDouble('voice_speech_pitch', pitch);
    }
  }

  // Speak AI responses or Agent status with deep male natural speech
  Future<void> speak(String rawText) async {
    if (!_ttsEnabled || rawText.trim().isEmpty) return;
    await init();

    // 1. Automatic Echo Cancellation / Mic Pause
    if (_autoPauseMicOnTts && isListening.value) {
      await stopListening();
    }

    // 2. Re-apply Male Voice
    await _applyMaleVoice();

    // 3. Clean markdown, formatting, ANSI and code artifacts for crisp spoken voice
    String cleaned = rawText
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' Code block executed. ')
        .replaceAll(RegExp(r'`.*?`'), '')
        .replaceAll(RegExp(r'[#*_~>|-]'), ' ')
        .replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '') // ANSI escape codes
        .replaceAll(RegExp(r'https?:\/\/\S+'), 'link')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.length > 500) {
      cleaned = '${cleaned.substring(0, 480)}...';
    }

    if (cleaned.isNotEmpty) {
      try {
        await _tts.stop();
        await _tts.setPitch(_speechPitch);
        await _tts.setSpeechRate(_speechRate);
        await _tts.speak(cleaned);
      } catch (e) {
        debugPrint('VoiceService speak caught: $e');
      }
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    isSpeaking.value = false;
  }

  // Listen to user voice (Speech-to-Text)
  Future<bool> startListening({
    required Function(String text, bool isFinal) onResult,
  }) async {
    await init();

    if (isSpeaking.value) {
      await stopSpeaking();
    }

    try {
      final available = await _stt.initialize();
      if (!available) {
        isListening.value = false;
        return false;
      }

      lastWords.value = '';
      isListening.value = true;

      await _stt.listen(
        onResult: (result) {
          lastWords.value = result.recognizedWords;
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
        onSoundLevelChange: (level) {
          soundLevel.value = level;
        },
      );
      return true;
    } catch (e) {
      debugPrint('VoiceService startListening caught: $e');
      isListening.value = false;
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _stt.stop();
    } catch (_) {}
    isListening.value = false;
  }

  Future<void> toggleListening({
    required Function(String text, bool isFinal) onResult,
  }) async {
    if (isListening.value) {
      await stopListening();
    } else {
      await startListening(onResult: onResult);
    }
  }
}
