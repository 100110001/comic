class UpdateInfo {
  final String latestVersion;
  final String? releaseNotes;
  final String? windowsUrl;
  final String? androidUrl;

  const UpdateInfo({
    required this.latestVersion,
    this.releaseNotes,
    this.windowsUrl,
    this.androidUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> j) {
    final platforms = (j['platforms'] as Map<String, dynamic>?) ?? const {};
    final windows = platforms['windows'] as Map<String, dynamic>?;
    final android = platforms['android'] as Map<String, dynamic>?;
    return UpdateInfo(
      latestVersion: (j['latestVersion'] as String?) ?? '',
      releaseNotes: j['releaseNotes'] as String?,
      windowsUrl: windows?['downloadUrl'] as String?,
      androidUrl: android?['downloadUrl'] as String?,
    );
  }
}
