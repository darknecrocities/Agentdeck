import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class Workstation {
  final String id;
  final String name;
  final String os; // 'macOS', 'Windows', 'Linux'
  final String endpoint; // e.g. 'http://100.64.0.1:8765' or 'http://127.0.0.1:8765'
  final String? authToken;
  final bool isCurrent;
  final bool isPrimary; // pinned as the default/startup workstation

  Workstation({
    required this.id,
    required this.name,
    required this.os,
    required this.endpoint,
    this.authToken,
    this.isCurrent = false,
    this.isPrimary = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'os': os,
        'endpoint': endpoint,
        'authToken': authToken,
        'isCurrent': isCurrent,
        'isPrimary': isPrimary,
      };

  factory Workstation.fromJson(Map<String, dynamic> json) => Workstation(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Workstation',
        os: json['os'] ?? 'macOS',
        endpoint: json['endpoint'] ?? 'http://127.0.0.1:8765',
        authToken: json['authToken'],
        isCurrent: json['isCurrent'] == true,
        isPrimary: json['isPrimary'] == true,
      );

  Workstation copyWith({
    bool? isCurrent,
    bool? isPrimary,
    String? name,
    String? os,
    String? endpoint,
    String? authToken,
  }) {
    return Workstation(
      id: id,
      name: name ?? this.name,
      os: os ?? this.os,
      endpoint: endpoint ?? this.endpoint,
      authToken: authToken ?? this.authToken,
      isCurrent: isCurrent ?? this.isCurrent,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

class WorkstationManager extends ChangeNotifier {
  static final WorkstationManager _instance = WorkstationManager._internal();
  factory WorkstationManager() => _instance;
  WorkstationManager._internal();

  static const String _storageKey = 'agentdeck_saved_workstations_v2';

  List<Workstation> _workstations = [];
  final Map<String, int> _latencies = {};

  List<Workstation> get workstations => List.unmodifiable(_workstations);
  Map<String, int> get latencies => Map.unmodifiable(_latencies);

  int? get activeLatency => currentWorkstation != null ? _latencies[currentWorkstation!.id] : null;

  Workstation? get currentWorkstation =>
      _workstations.isNotEmpty ? _workstations.firstWhere((w) => w.isCurrent, orElse: () => _workstations.first) : null;

  Workstation? get activeWorkstation => currentWorkstation;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        final List<dynamic> list = jsonDecode(data);
        _workstations = list
            .map((item) => Workstation.fromJson(item))
            .where((w) => !w.endpoint.contains('.100:8765') && !w.endpoint.contains('.200:8765'))
            .toList();
      }

      // Ensure standard default workstations are available
      const envHost = String.fromEnvironment('AGENTDECK_HOST', defaultValue: '');
      const envTailscale = String.fromEnvironment('TAILSCALE_HOST_IP', defaultValue: '');

      if (envTailscale.isNotEmpty && !_workstations.any((w) => w.endpoint.contains(envTailscale))) {
        _workstations.insert(
          0,
          Workstation(
            id: 'tailscale-env',
            name: 'Tailscale Mesh Node',
            os: 'macOS',
            endpoint: 'http://$envTailscale:8765',
            isCurrent: true,
          ),
        );
      } else if (envHost.isNotEmpty && !_workstations.any((w) => w.endpoint.contains(envHost))) {
        _workstations.insert(
          0,
          Workstation(
            id: 'env-host',
            name: 'Configured Workstation',
            os: 'macOS',
            endpoint: envHost.startsWith('http') ? envHost : 'http://$envHost:8765',
            isCurrent: true,
          ),
        );
      }

      final hasLocal = _workstations.any((w) => w.endpoint.contains('127.0.0.1'));
      if (!hasLocal) {
        _workstations.add(
          Workstation(
            id: 'local-primary',
            name: 'Local USB Bridge / Host',
            os: defaultTargetPlatform == TargetPlatform.macOS
                ? 'macOS'
                : (defaultTargetPlatform == TargetPlatform.windows ? 'Windows' : 'Linux'),
            endpoint: 'http://127.0.0.1:8765',
            isCurrent: _workstations.isEmpty,
          ),
        );
      }

      await _persist();

      final active = currentWorkstation;
      if (active != null) {
        await ApiService().updateConfig(url: active.endpoint, token: active.authToken);
      }
      notifyListeners();

      // Proactively probe endpoints to pick fastest responsive node
      for (final ws in _workstations) {
        try {
          final res = await http.get(Uri.parse('${ws.endpoint}/health')).timeout(const Duration(milliseconds: 1200));
          if (res.statusCode == 200) {
            await switchTo(ws.id);
            break;
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> switchTo(String id) async {
    _workstations = _workstations.map((w) => w.copyWith(isCurrent: w.id == id)).toList();
    await _persist();
    final active = currentWorkstation;
    if (active != null) {
      await ApiService().updateConfig(url: active.endpoint, token: active.authToken);
    }
    notifyListeners();
  }

  Future<void> addWorkstation(Workstation ws) async {
    _workstations.removeWhere((w) => w.id == ws.id);
    _workstations.add(ws);
    await _persist();
    notifyListeners();
  }

  Future<void> updateWorkstation(Workstation updated) async {
    final idx = _workstations.indexWhere((w) => w.id == updated.id);
    if (idx != -1) {
      _workstations[idx] = updated;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> setPrimary(String id) async {
    _workstations = _workstations.map((w) => w.copyWith(isPrimary: w.id == id)).toList();
    // Also switch active connection to the primary
    await switchTo(id);
  }

  Future<void> removeWorkstation(String id) async {
    _workstations.removeWhere((w) => w.id == id);
    if (_workstations.isNotEmpty && !_workstations.any((w) => w.isCurrent)) {
      _workstations[0] = _workstations[0].copyWith(isCurrent: true);
    }
    await _persist();
    notifyListeners();
  }

  Future<({bool online, int latencyMs})> pingWithLatency(String endpoint) async {
    final sw = Stopwatch()..start();
    try {
      final clean = endpoint.endsWith('/') ? endpoint.substring(0, endpoint.length - 1) : endpoint;

      // 1. Direct HTTP probe to the workstation daemon
      try {
        final res = await http.get(Uri.parse('$clean/health')).timeout(const Duration(milliseconds: 1800));
        sw.stop();
        if (res.statusCode == 200) {
          return (online: true, latencyMs: sw.elapsedMilliseconds);
        }
      } catch (_) {}

      // 2. Ask primary host daemon to ping over Tailscale mesh
      final hostCandidates = [ApiService().baseUrl];
      for (final host in hostCandidates) {
        try {
          final probeUrl = Uri.parse('$host/api/system/ping_workstation?endpoint=${Uri.encodeComponent(clean)}');
          final probeRes = await http.get(probeUrl).timeout(const Duration(milliseconds: 2000));
          sw.stop();
          if (probeRes.statusCode == 200) {
            final data = jsonDecode(probeRes.body);
            if (data['online'] == true) {
              return (online: true, latencyMs: sw.elapsedMilliseconds);
            }
          }
        } catch (_) {}
      }

      sw.stop();
      return (online: false, latencyMs: 0);
    } catch (_) {
      sw.stop();
      return (online: false, latencyMs: 0);
    }
  }

  Future<bool> pingWorkstation(String endpoint) async {
    final res = await pingWithLatency(endpoint);
    return res.online;
  }

  Future<Map<String, bool>> pingAll() async {
    final Map<String, bool> results = {};
    for (final ws in _workstations) {
      final res = await pingWithLatency(ws.endpoint);
      results[ws.id] = res.online;
      if (res.online) {
        _latencies[ws.id] = res.latencyMs;
      } else {
        _latencies.remove(ws.id);
      }
    }
    notifyListeners();
    return results;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_workstations.map((w) => w.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (_) {}
  }
}
