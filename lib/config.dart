/// 后端地址：构建时用 --dart-define=API_BASE_URL=http://... 覆盖，默认本机。
const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8888',
);
const Duration requestTimeout = Duration(seconds: 15);

/// 更新清单地址（公开 releases 仓的 update.json）。
const String kUpdateManifestUrl =
    'https://raw.githubusercontent.com/100110001/comic-releases/main/update.json';
