class UpdateInfo {
  final String latestVersion;
  final String? releaseNotes;
  final String? windowsUrl;
  final String? androidUrl;
  final String? windowsMinimumVersion;
  final String? androidMinimumVersion;
  final String? windowsMinimumReason;
  final String? androidMinimumReason;

  const UpdateInfo({
    required this.latestVersion,
    this.releaseNotes,
    this.windowsUrl,
    this.androidUrl,
    this.windowsMinimumVersion,
    this.androidMinimumVersion,
    this.windowsMinimumReason,
    this.androidMinimumReason,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> j) {
    final platforms = (j['platforms'] as Map<String, dynamic>?) ?? const {};
    final windows = platforms['windows'] as Map<String, dynamic>?;
    final android = platforms['android'] as Map<String, dynamic>?;
    final info = UpdateInfo(
      latestVersion: (j['latestVersion'] as String?) ?? '',
      releaseNotes: j['releaseNotes'] as String?,
      windowsUrl: windows?['downloadUrl'] as String?,
      androidUrl: android?['downloadUrl'] as String?,
      windowsMinimumVersion: windows?['minimumSupportedVersion'] as String?,
      androidMinimumVersion: android?['minimumSupportedVersion'] as String?,
      windowsMinimumReason: windows?['minimumSupportReason'] as String?,
      androidMinimumReason: android?['minimumSupportReason'] as String?,
    );
    stableVersionParts(info.latestVersion);
    for (final platform in [windows, android]) {
      if (platform == null) continue;
      final url = Uri.tryParse(platform['downloadUrl'] as String? ?? '');
      if (url == null ||
          url.scheme != 'https' ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty) {
        throw const FormatException('更新包地址无效');
      }
      final minimum = platform['minimumSupportedVersion'] as String?;
      if (minimum != null) {
        stableVersionParts(minimum);
        if (compareVersions(minimum, info.latestVersion) > 0) {
          throw const FormatException('最低支持版本高于最新版本');
        }
      }
    }
    return info;
  }

  Map<String, dynamic> toJson() => {
    'latestVersion': latestVersion,
    'releaseNotes': releaseNotes,
    'platforms': {
      if (windowsUrl != null)
        'windows': {
          'downloadUrl': windowsUrl,
          if (windowsMinimumVersion != null)
            'minimumSupportedVersion': windowsMinimumVersion,
          'minimumSupportReason': windowsMinimumReason,
        },
      if (androidUrl != null)
        'android': {
          'downloadUrl': androidUrl,
          if (androidMinimumVersion != null)
            'minimumSupportedVersion': androidMinimumVersion,
          'minimumSupportReason': androidMinimumReason,
        },
    },
  };
}

List<int> stableVersionParts(String version) {
  if (!RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$',
  ).hasMatch(version)) {
    throw const FormatException('版本号必须为稳定的 X.Y.Z');
  }
  return version.split('.').map(int.parse).toList();
}

int compareVersions(String a, String b) {
  final left = stableVersionParts(a);
  final right = stableVersionParts(b);
  for (var i = 0; i < 3; i++) {
    final compared = left[i].compareTo(right[i]);
    if (compared != 0) return compared;
  }
  return 0;
}
