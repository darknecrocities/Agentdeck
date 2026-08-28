import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String baseUrl = 'http://127.0.0.1:8765';
  String? authToken;

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

  // System
  Future<Map<String, dynamic>> getHealth() async {
    final res = await http.get(Uri.parse('$baseUrl/health'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getStatus() async {
    final res = await http.get(Uri.parse('$baseUrl/api/status'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getDevice() async {
    final res = await http.get(Uri.parse('$baseUrl/api/device'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getDiagnostics() async {
    final res = await http.get(Uri.parse('$baseUrl/api/diagnostics'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> browseDirectories({String? path}) async {
    final uri = Uri.parse('$baseUrl/api/system/browse').replace(
      queryParameters: path != null ? {'path': path} : null,
    );
    final res = await http.get(uri, headers: _headers);
    return jsonDecode(res.body);
  }

  // Projects
  Future<List<dynamic>> getProjects() async {
    final res = await http.get(Uri.parse('$baseUrl/api/projects'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> createProject({
    required String name,
    required String path,
    String defaultAgent = 'antigravity',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/projects'),
      headers: _headers,
      body: jsonEncode({'name': name, 'path': path, 'default_agent': defaultAgent}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> scaffoldProject({
    required String name,
    String? parentPath,
    String template = 'empty',
    String? initialPrompt,
    String defaultAgent = 'antigravity',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/projects/scaffold'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'parent_path': parentPath,
        'template': template,
        'initial_prompt': initialPrompt,
        'default_agent': defaultAgent,
      }),
    );
    return jsonDecode(res.body);
  }

  Future<bool> deleteProject(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/projects/$id'), headers: _headers);
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> getProjectFiles(String id, {String? path}) async {
    final uri = Uri.parse('$baseUrl/api/projects/$id/files').replace(
      queryParameters: path != null ? {'path': path} : null,
    );
    final res = await http.get(uri, headers: _headers);
    return jsonDecode(res.body);
  }

  Future<String> getFileContent(String id, String path) async {
    final uri = Uri.parse('$baseUrl/api/projects/$id/files/content').replace(
      queryParameters: {'path': path},
    );
    final res = await http.get(uri, headers: _headers);
    final data = jsonDecode(res.body);
    return data['content'] ?? '';
  }

  Future<Map<String, dynamic>> getGitStatus(String projectId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/projects/$projectId/git/status'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<String> getGitDiff(String projectId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/projects/$projectId/git/diff'), headers: _headers);
    final data = jsonDecode(res.body);
    return data['diff'] ?? '';
  }

  Future<List<dynamic>> getGitLog(String projectId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/projects/$projectId/git/log'), headers: _headers);
    final data = jsonDecode(res.body);
    return data['log'] ?? [];
  }

  Future<bool> commitGit(String projectId, String message) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/projects/$projectId/git/commit'),
      headers: _headers,
      body: jsonEncode({'message': message}),
    );
    return res.statusCode == 200;
  }

  Future<bool> pushGit(String projectId) async {
    final res = await http.post(Uri.parse('$baseUrl/api/projects/$projectId/git/push'), headers: _headers);
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> getGitHubOverview(String projectId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/projects/$projectId/github'), headers: _headers);
    return jsonDecode(res.body);
  }

  // Agents & Sessions
  Future<List<dynamic>> getAgents() async {
    final res = await http.get(Uri.parse('$baseUrl/api/agents'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getSessions() async {
    final res = await http.get(Uri.parse('$baseUrl/api/sessions'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getSession(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/sessions/$id'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> startSession({
    required String projectId,
    required String agent,
    required String prompt,
    String? conversationId,
    String? model,
    String? effort,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sessions'),
      headers: _headers,
      body: jsonEncode({
        'project_id': projectId,
        'agent': agent,
        'prompt': prompt,
        'conversation_id': conversationId,
        'model': model,
        'effort': effort,
      }),
    );
    return jsonDecode(res.body);
  }

  Future<bool> sendPrompt(String sessionId, String prompt) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sessions/$sessionId/prompt'),
      headers: _headers,
      body: jsonEncode({'prompt': prompt}),
    );
    return res.statusCode == 200;
  }

  Future<bool> continueSession(String sessionId) async {
    final res = await http.post(Uri.parse('$baseUrl/api/sessions/$sessionId/continue'), headers: _headers);
    return res.statusCode == 200;
  }

  Future<bool> stopSession(String sessionId) async {
    final res = await http.post(Uri.parse('$baseUrl/api/sessions/$sessionId/stop'), headers: _headers);
    return res.statusCode == 200;
  }

  Future<List<dynamic>> getSessionEvents(String sessionId, {int afterEventId = 0}) async {
    final uri = Uri.parse('$baseUrl/api/sessions/$sessionId/events').replace(
      queryParameters: {'after_event_id': afterEventId.toString()},
    );
    final res = await http.get(uri, headers: _headers);
    return jsonDecode(res.body);
  }

  // Approvals
  Future<List<dynamic>> getApprovals() async {
    final res = await http.get(Uri.parse('$baseUrl/api/approvals'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<bool> resolveApproval(String id, bool approve) async {
    final endpoint = approve ? 'approve' : 'deny';
    final res = await http.post(Uri.parse('$baseUrl/api/approvals/$id/$endpoint'), headers: _headers);
    return res.statusCode == 200;
  }

  // Terminals
  Future<List<dynamic>> getTerminals() async {
    final res = await http.get(Uri.parse('$baseUrl/api/terminal/sessions'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> spawnTerminal({String? projectId, int cols = 80, int rows = 24}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/terminal/session'),
      headers: _headers,
      body: jsonEncode({'project_id': projectId, 'cols': cols, 'rows': rows}),
    );
    return jsonDecode(res.body);
  }

  // Auth Profiles & Account Switching
  Future<List<dynamic>> getAuthProfiles({String? agent}) async {
    final uri = Uri.parse('$baseUrl/api/auth/profiles').replace(
      queryParameters: agent != null ? {'agent': agent} : null,
    );
    final res = await http.get(uri, headers: _headers);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> createAuthProfile({
    required String agentId,
    required String accountName,
    required String tokenValue,
    bool setActive = true,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/profiles'),
      headers: _headers,
      body: jsonEncode({
        'agent_id': agentId,
        'account_name': accountName,
        'token_value': tokenValue,
        'set_active': setActive,
      }),
    );
    return jsonDecode(res.body);
  }

  Future<bool> activateAuthProfile(String id) async {
    final res = await http.post(Uri.parse('$baseUrl/api/auth/profiles/$id/activate'), headers: _headers);
    return res.statusCode == 200;
  }

  Future<bool> deleteAuthProfile(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/auth/profiles/$id'), headers: _headers);
    return res.statusCode == 200;
  }

  // Token Monitoring & Model Quotas
  Future<Map<String, dynamic>> getTokenSummary() async {
    final res = await http.get(Uri.parse('$baseUrl/api/tokens/summary'), headers: _headers);
    return jsonDecode(res.body);
  }

  // Remote File & Media Upload
  Future<Map<String, dynamic>> uploadFile({
    required String destinationPath,
    required String filename,
    required List<int> bytes,
  }) async {
    final base64Content = base64Encode(bytes);
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/upload'),
      headers: _headers,
      body: jsonEncode({
        'destination_path': destinationPath,
        'filename': filename,
        'content_base64': base64Content,
      }),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> createDirectory(String path) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/system/mkdir'),
      headers: _headers,
      body: jsonEncode({'path': path}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getAntigravityAccount() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/accounts/antigravity'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {
      'active_account': 'developer@example.com',
      'accounts': ['developer@example.com'],
      'auth_type': 'Google OAuth (Personal)',
      'status': 'authenticated',
    };
  }

  Future<bool> switchAntigravityAccount(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/accounts/antigravity/switch'),
        headers: _headers,
        body: jsonEncode({'email': email}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
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
