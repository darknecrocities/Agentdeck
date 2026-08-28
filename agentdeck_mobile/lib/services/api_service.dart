import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String baseUrl = 'http://100.114.182.27:8765';
  String? authToken;

  static const Duration _timeout = Duration(milliseconds: 2500);

  Map<String, String> get _headers {
    final map = <String, String>{'Content-Type': 'application/json'};
    if (authToken != null && authToken!.isNotEmpty) {
      map['Authorization'] = 'Bearer $authToken';
    }
    return map;
  }

  Future<void> initFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('agentdeck_daemon_url');
      final savedToken = prefs.getString('agentdeck_auth_token');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        baseUrl = savedUrl.endsWith('/') ? savedUrl.substring(0, savedUrl.length - 1) : savedUrl;
      }
      if (savedToken != null && savedToken.isNotEmpty) {
        authToken = savedToken;
      }
    } catch (_) {}
  }

  Future<void> updateConfig({required String url, String? token}) async {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    authToken = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('agentdeck_daemon_url', baseUrl);
      if (token != null) {
        await prefs.setString('agentdeck_auth_token', token);
      }
    } catch (_) {}
  }

  // HTTP Helpers with fast failure timeout
  Future<dynamic> _get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers).timeout(_timeout);
    return jsonDecode(res.body);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.post(uri, headers: _headers, body: jsonEncode(body)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  Future<bool> _del(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.delete(uri, headers: _headers).timeout(_timeout);
    return res.statusCode == 200;
  }

  // System
  Future<Map<String, dynamic>> getHealth() async {
    final data = await _get('/health');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> getStatus() async {
    final data = await _get('/api/status');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> getDevice() async {
    final data = await _get('/api/device');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> getDiagnostics() async {
    final data = await _get('/api/diagnostics');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> browseDirectories({String? path}) async {
    final data = await _get('/api/system/browse', query: path != null ? {'path': path} : null);
    return data is Map<String, dynamic> ? data : {};
  }

  // Projects
  Future<List<dynamic>> getProjects() async {
    final data = await _get('/api/projects');
    return data is List<dynamic> ? data : [];
  }

  Future<Map<String, dynamic>> createProject({
    required String name,
    required String path,
    String defaultAgent = 'antigravity',
  }) async {
    final data = await _post('/api/projects', {'name': name, 'path': path, 'default_agent': defaultAgent});
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> scaffoldProject({
    required String name,
    String? parentPath,
    String template = 'empty',
    String? initialPrompt,
    String defaultAgent = 'antigravity',
  }) async {
    final data = await _post('/api/projects/scaffold', {
      'name': name,
      'parent_path': parentPath,
      'template': template,
      'initial_prompt': initialPrompt,
      'default_agent': defaultAgent,
    });
    return data is Map<String, dynamic> ? data : {};
  }

  Future<bool> deleteProject(String id) async {
    return await _del('/api/projects/$id');
  }

  Future<Map<String, dynamic>> getProjectFiles(String id, {String? path}) async {
    final data = await _get('/api/projects/$id/files', query: path != null ? {'path': path} : null);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<String> getFileContent(String id, String path) async {
    final data = await _get('/api/projects/$id/files/content', query: {'path': path});
    return data['content'] ?? '';
  }

  Future<Map<String, dynamic>> getGitStatus(String projectId) async {
    final data = await _get('/api/projects/$projectId/git/status');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<String> getGitDiff(String projectId) async {
    final data = await _get('/api/projects/$projectId/git/diff');
    return data['diff'] ?? '';
  }

  Future<List<dynamic>> getGitLog(String projectId) async {
    final data = await _get('/api/projects/$projectId/git/log');
    return data['log'] ?? [];
  }

  Future<bool> commitGit(String projectId, String message) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/projects/$projectId/git/commit'),
      headers: _headers,
      body: jsonEncode({'message': message}),
    ).timeout(_timeout);
    return res.statusCode == 200;
  }

  Future<bool> pushGit(String projectId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/projects/$projectId/git/push'),
      headers: _headers,
    ).timeout(_timeout);
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> getGitHubOverview(String projectId) async {
    final data = await _get('/api/projects/$projectId/github');
    return data is Map<String, dynamic> ? data : {};
  }

  // Agents & Sessions
  Future<List<dynamic>> getAgents() async {
    final data = await _get('/api/agents');
    return data is List<dynamic> ? data : [];
  }

  Future<List<dynamic>> getSessions() async {
    final data = await _get('/api/sessions');
    return data is List<dynamic> ? data : [];
  }

  Future<Map<String, dynamic>> getSession(String id) async {
    final data = await _get('/api/sessions/$id');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> startSession({
    required String projectId,
    required String agent,
    required String prompt,
    String? conversationId,
    String? model,
    String? effort,
  }) async {
    final data = await _post('/api/sessions', {
      'project_id': projectId,
      'agent': agent,
      'prompt': prompt,
      'conversation_id': conversationId,
      'model': model,
      'effort': effort,
    });
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> sendPrompt(String sessionId, String prompt) async {
    final data = await _post('/api/sessions/$sessionId/prompt', {'prompt': prompt});
    return data is Map<String, dynamic> ? data : {};
  }

  Future<bool> continueSession(String sessionId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sessions/$sessionId/continue'),
      headers: _headers,
    ).timeout(_timeout);
    return res.statusCode == 200;
  }

  Future<bool> stopSession(String sessionId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sessions/$sessionId/stop'),
      headers: _headers,
    ).timeout(_timeout);
    return res.statusCode == 200;
  }

  Future<bool> killSession(String sessionId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sessions/$sessionId/kill'),
      headers: _headers,
    ).timeout(_timeout);
    return res.statusCode == 200;
  }

  Future<List<dynamic>> getSessionEvents(String sessionId, {int afterEventId = 0}) async {
    final data = await _get('/api/sessions/$sessionId/events', query: {'after_event_id': afterEventId.toString()});
    return data is List<dynamic> ? data : [];
  }

  // Approvals
  Future<List<dynamic>> getApprovals() async {
    final data = await _get('/api/approvals');
    return data is List<dynamic> ? data : [];
  }

  Future<bool> resolveApproval(String id, bool approve) async {
    final path = approve ? '/api/approvals/$id/approve' : '/api/approvals/$id/deny';
    final res = await http.post(Uri.parse('$baseUrl$path'), headers: _headers).timeout(_timeout);
    return res.statusCode == 200;
  }

  // Terminal PTY
  Future<Map<String, dynamic>> spawnTerminal({int cols = 80, int rows = 24, String? projectId, String? cwd}) async {
    final data = await _post('/api/terminal/session', {
      'cols': cols,
      'rows': rows,
      'project_id': projectId,
      'cwd': cwd,
    });
    return data is Map<String, dynamic> ? data : {};
  }

  Future<bool> sendTerminalInput(String id, String data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/terminal/$id/input'),
      headers: _headers,
      body: jsonEncode({'data': data}),
    ).timeout(_timeout);
    return res.statusCode == 200;
  }

  Future<bool> closeTerminal(String id) async {
    return await _del('/api/terminal/$id');
  }

  // Auth Profiles
  Future<List<dynamic>> getAuthProfiles({String? agent}) async {
    final data = await _get('/api/auth/profiles', query: agent != null ? {'agent': agent} : null);
    return data is List<dynamic> ? data : [];
  }

  Future<Map<String, dynamic>> createAuthProfile({
    required String agentId,
    required String accountName,
    required String tokenValue,
    bool setActive = true,
  }) async {
    final data = await _post('/api/auth/profiles', {
      'agent_id': agentId,
      'account_name': accountName,
      'token_value': tokenValue,
      'set_active': setActive,
    });
    return data is Map<String, dynamic> ? data : {};
  }

  Future<bool> activateAuthProfile(String id) async {
    final res = await http.post(Uri.parse('$baseUrl/api/auth/profiles/$id/activate'), headers: _headers).timeout(_timeout);
    return res.statusCode == 200;
  }

  Future<bool> deleteAuthProfile(String id) async {
    return await _del('/api/auth/profiles/$id');
  }

  // Antigravity IDE Accounts
  Future<Map<String, dynamic>> getAntigravityAccount() async {
    try {
      final data = await _get('/api/accounts/antigravity');
      return data is Map<String, dynamic> ? data : {};
    } catch (_) {
      return {
        'active_account': 'parejasarronkian@gmail.com',
        'accounts': ['parejasarronkian@gmail.com'],
        'auth_type': 'Google OAuth (Personal)',
        'status': 'authenticated',
      };
    }
  }

  Future<bool> switchAntigravityAccount(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/accounts/antigravity/switch'),
        headers: _headers,
        body: jsonEncode({'email': email}),
      ).timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Token Quotas & Monitoring
  Future<Map<String, dynamic>> getTokenSummary() async {
    final data = await _get('/api/tokens/summary');
    return data is Map<String, dynamic> ? data : {};
  }

  // File Upload & System Browsing
  Future<Map<String, dynamic>> uploadFile({
    required String destinationPath,
    required String filename,
    Uint8List? bytes,
    String? base64Content,
  }) async {
    final b64 = base64Content ?? (bytes != null ? base64Encode(bytes) : '');
    final data = await _post('/api/files/upload', {
      'destination_path': destinationPath,
      'filename': filename,
      'content_base64': b64,
    });
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> createDirectory(String path) async {
    final data = await _post('/api/system/mkdir', {'path': path});
    return data is Map<String, dynamic> ? data : {};
  }

  // WebSockets
  WebSocketChannel connectEventsStream({int afterEventId = 0}) {
    final wsScheme = baseUrl.startsWith('https') ? 'wss' : 'ws';
    final hostPort = baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    final uri = Uri.parse('$wsScheme://$hostPort/ws/events?after_event_id=$afterEventId');
    return WebSocketChannel.connect(uri);
  }

  WebSocketChannel connectSessionStream(String sessionId, {int afterEventId = 0}) {
    final wsScheme = baseUrl.startsWith('https') ? 'wss' : 'ws';
    final hostPort = baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    final uri = Uri.parse('$wsScheme://$hostPort/ws/sessions/$sessionId?after_event_id=$afterEventId');
    return WebSocketChannel.connect(uri);
  }

  WebSocketChannel connectTerminalStream(String terminalId) {
    final wsScheme = baseUrl.startsWith('https') ? 'wss' : 'ws';
    final hostPort = baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    final uri = Uri.parse('$wsScheme://$hostPort/ws/terminal/$terminalId');
    return WebSocketChannel.connect(uri);
  }
}
