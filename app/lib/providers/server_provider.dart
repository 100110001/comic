import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../utils/user_error.dart';

const _serverUrlKey = 'serverUrl';

class ServerSession {
  const ServerSession({required this.url, required this.generation});

  final String url;
  final int generation;
}

String normalizeServerUrl(String input) {
  final trimmed = input.trim();
  final uri = Uri.tryParse(trimmed);
  final validScheme = uri?.scheme == 'http' || uri?.scheme == 'https';
  final validPath = uri?.path.isEmpty == true || uri?.path == '/';
  if (uri == null ||
      !validScheme ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      !validPath ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const UserVisibleException(
      UserErrorKind.invalidAddress,
      '请输入完整的 http:// 或 https:// 服务器地址',
    );
  }

  return uri.replace(path: '').toString().replaceFirst(RegExp(r'/$'), '');
}

Future<String> loadServerUrl() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_serverUrlKey);
  if (stored == null) return defaultServerUrl;
  try {
    return normalizeServerUrl(stored);
  } catch (_) {
    return defaultServerUrl;
  }
}

final serverSessionProvider =
    NotifierProvider<ServerSessionNotifier, ServerSession>(
      ServerSessionNotifier.new,
    );

class ServerSessionNotifier extends Notifier<ServerSession> {
  ServerSessionNotifier({String initialUrl = defaultServerUrl})
    : _initialUrl = initialUrl;

  final String _initialUrl;

  @override
  ServerSession build() => ServerSession(url: _initialUrl, generation: 0);

  Future<bool> save(String input) async {
    final normalized = normalizeServerUrl(input);
    if (normalized == state.url) return false;

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_serverUrlKey, normalized);
    if (!saved) {
      throw const UserVisibleException(
        UserErrorKind.persistence,
        '服务器地址保存失败，请重试',
      );
    }
    state = ServerSession(url: normalized, generation: state.generation + 1);
    return true;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final session = ref.watch(serverSessionProvider);
  final client = ApiClient(
    baseUrl: session.url,
    generation: session.generation,
  );
  ref.onDispose(client.close);
  return client;
});

final serverConnectionTestProvider = FutureProvider.autoDispose
    .family<void, String>((ref, input) async {
      final url = normalizeServerUrl(input);
      final client = ApiClient(baseUrl: url, generation: -1);
      ref.onDispose(client.close);
      await client.testConnection();
    });
