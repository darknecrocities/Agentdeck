import 'dart:async';
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
  double _speechRate = 0.45; // Natural, clear conversational pacing (not rushed)
  double _speechPitch = 0.82; // Deep, commanding male AI voice
  String _selectedVoiceProfile = 'Deep Male Commander';
  bool _initialized = false;

  bool get ttsEnabled => _ttsEnabled;
  bool get autoPauseMicOnTts => _autoPauseMicOnTts;
  double get speechRate => _speechRate;
  double get speechPitch => _speechPitch;
  String get selectedVoiceProfile => _selectedVoiceProfile;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _ttsEnabled = prefs.getBool('voice_tts_enabled') ?? true;
      _autoPauseMicOnTts = prefs.getBool('voice_auto_pause_mic') ?? true;
      _speechRate = prefs.getDouble('voice_speech_rate') ?? 0.45;
      _speechPitch = prefs.getDouble('voice_speech_pitch') ?? 0.82;
      _selectedVoiceProfile = prefs.getString('voice_profile') ?? 'Deep Male Commander';

      // Configure TTS handlers safely
      try {
        await _tts.setLanguage("en-US");
        await _tts.setSpeechRate(_speechRate);
        await _tts.setPitch(_speechPitch);
        await _tts.setVolume(1.0);

        // Select Male Voice
        final voices = await _tts.getVoices;
        if (voices is List) {
          for (var v in voices) {
            if (v is Map) {
              final name = (v['name'] ?? '').toString().toLowerCase();
              final locale = (v['locale'] ?? '').toString().toLowerCase();
              final gender = (v['gender'] ?? '').toString().toLowerCase();
              if (locale.startsWith('en') &&
                  (gender == 'male' ||
                      name.contains('male') ||
                      name.contains('en-us-x-sfg') ||
                      name.contains('en-us-x-iom') ||
                      name.contains('en-us-x-tpd'))) {
                await _tts.setVoice({"name": v['name'], "locale": v['locale']});
                break;
              }
            }
          }
        }

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

  Future<void> setProfile(String profileName) async {
    _selectedVoiceProfile = profileName;
    if (profileName == 'Deep Male Commander') {
      _speechRate = 0.45;
      _speechPitch = 0.80;
    } else if (profileName == 'Calm Male Assistant') {
      _speechRate = 0.48;
      _speechPitch = 0.88;
    } else if (profileName == 'Fast Male Agent') {
      _speechRate = 0.55;
      _speechPitch = 0.85;
    }

    try {
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_speechPitch);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voice_profile', profileName);
    await prefs.setDouble('voice_speech_rate', _speechRate);
    await prefs.setDouble('voice_speech_pitch', _speechPitch);
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

    // 2. Clean markdown, formatting, ANSI and code artifacts for crisp spoken voice
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
        await _tts.setSpeechRate(_speechRate);
        await _tts.setPitch(_speechPitch);
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
