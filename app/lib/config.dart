const String baseUrl = 'http://192.168.124.4:8888';
const Duration requestTimeout = Duration(seconds: 15);

/// 更新清单地址（主仓库 releases/update.json，公开后免 token 访问）。
const String kUpdateManifestUrl =
    'https://raw.githubusercontent.com/100110001/comic/master/releases/update.json';
