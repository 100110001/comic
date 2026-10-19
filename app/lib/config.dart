const String defaultServerUrl = 'http://192.168.124.4:8888';
const Duration requestTimeout = Duration(seconds: 15);

/// 只读取已完成发布的 Release 清单，避免先公布版本后上传安装包。
const String kUpdateManifestUrl =
    'https://github.com/100110001/comic/releases/latest/download/update.json';

/// 手动下载安装包的 GitHub 最新发布页。
const String kReleasePageUrl =
    'https://github.com/100110001/comic/releases/latest';
