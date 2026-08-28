import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class Workstation {
  final String id;
  final String name;
  final String os; // 'macOS', 'Windows', 'Linux'
  final String endpoint; // e.g. 'http://100.114.182.27:8765'
  final String? authToken;
  final bool isCurrent;

  Workstation({
    required this.id,
    required this.name,
    required this.os,
    required this.endpoint,
    this.authToken,
    this.isCurrent = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'os': os,
        'endpoint': endpoint,
        'authToken': authToken,
        'isCurrent': isCurrent,
      };

  factory Workstation.fromJson(Map<String, dynamic> json) => Workstation(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Workstation',
        os: json['os'] ?? 'macOS',
        endpoint: json['endpoint'] ?? 'http://100.114.182.27:8765',
        authToken: json['authToken'],
        isCurrent: json['isCurrent'] == true,
      );

  Workstation copyWith({bool? isCurrent, String? name, String? os, String? endpoint, String? authToken}) {
    return Workstation(
      id: id,
      name: name ?? this.name,
      os: os ?? this.os,
      endpoint: endpoint ?? this.endpoint,
      authToken: authToken ?? this.authToken,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}

class WorkstationManager {
  static final WorkstationManager _instance = WorkstationManager._internal();
  factory WorkstationManager() => _instance;
  WorkstationManager._internal();

  static const String _storageKey = 'agentdeck_saved_workstations_v2';

  List<Workstation> _workstations = [];

  List<Workstation> get workstations => List.unmodifiable(_workstations);

  Workstation? get currentWorkstation =>
      _workstations.isNotEmpty ? _workstations.firstWhere((w) => w.isCurrent, orElse: () => _workstations.first) : null;

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

      // Default real fleet machines
      if (_workstations.isEmpty) {
        _workstations = [
          Workstation(
            id: 'mac-main',
            name: 'MacBook Air (Primary)',
            os: 'macOS',
            endpoint: 'http://100.114.182.27:8765',
            isCurrent: true,
          ),
          Workstation(
            id: 'win-darknecrocities',
            name: 'Windows PC (darknecrocities)',
            os: 'Windows',
            endpoint: 'http://100.94.58.13:8765',
            isCurrent: false,
          ),
        ];
        await _persist();
      } else {
        // Ensure Windows PC darknecrocities is present
        if (!_workstations.any((w) => w.endpoint.contains('100.94.58.13'))) {
          _workstations.add(
            Workstation(
              id: 'win-darknecrocities',
              name: 'Windows PC (darknecrocities)',
              os: 'Windows',
              endpoint: 'http://100.94.58.13:8765',
              isCurrent: false,
            ),
          );
          await _persist();
        }
      }

      final active = currentWorkstation;
      if (active != null) {
        await ApiService().updateConfig(url: active.endpoint, token: active.authToken);
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
  }

  Future<void> addWorkstation(Workstation ws) async {
    _workstations.add(ws);
    await _persist();
  }

  Future<void> removeWorkstation(String id) async {
    _workstations.removeWhere((w) => w.id == id);
    if (_workstations.isNotEmpty && !_workstations.any((w) => w.isCurrent)) {
      _workstations[0] = _workstations[0].copyWith(isCurrent: true);
    }
    await _persist();
  }

  Future<bool> pingWorkstation(String endpoint) async {
    try {
      final clean = endpoint.endsWith('/') ? endpoint.substring(0, endpoint.length - 1) : endpoint;

      // 1. First ask the active daemon to test the workstation (works across Tailscale mesh)
      try {
        final currentUrl = ApiService().baseUrl;
        final probeUrl = Uri.parse('$currentUrl/api/system/ping_workstation?endpoint=${Uri.encodeComponent(clean)}');
        final probeRes = await http.get(probeUrl).timeout(const Duration(milliseconds: 1500));
        if (probeRes.statusCode == 200) {
          final data = jsonDecode(probeRes.body);
          if (data['online'] == true) {
            return true;
          }
        }
      } catch (_) {}

      // 2. Direct HTTP probe fallback
      final res = await http.get(Uri.parse('$clean/health')).timeout(const Duration(milliseconds: 1500));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, bool>> pingAll() async {
    final Map<String, bool> results = {};
    for (final ws in _workstations) {
      results[ws.id] = await pingWorkstation(ws.endpoint);
    }
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
