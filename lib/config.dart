const String baseUrl = 'http://192.168.124.4:8888';
const Duration requestTimeout = Duration(seconds: 15);

/// 更新清单地址（公开 releases 仓的 update.json）。
const String kUpdateManifestUrl =
    'https://raw.githubusercontent.com/100110001/comic-releases/main/update.json';
