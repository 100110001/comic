class SuperResolutionJob {
  const SuperResolutionJob({
    required this.key,
    required this.imageId,
    required this.status,
    this.url,
    this.error,
  });
  final String key;
  final int imageId;
  final String status;
  final String? url;
  final String? error;
  bool get pending => status == 'queued' || status == 'running';

  factory SuperResolutionJob.fromJson(
    Map<String, dynamic> json,
    String serverUrl,
  ) {
    final key = json['key'] as String;
    final id = json['imageId'] as int;
    final status = json['status'] as String;
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(key) ||
        id < 0 ||
        !['queued', 'running', 'ready', 'failed'].contains(status)) {
      throw const FormatException('无效超分状态');
    }
    String? url;
    if (status == 'ready') {
      final relative = Uri.parse(json['url'] as String);
      if (relative.hasAuthority ||
          relative.hasScheme ||
          relative.path != '/api/super-resolution/files/$key') {
        throw const FormatException('无效超分图片地址');
      }
      url = Uri.parse('$serverUrl/').resolveUri(relative).toString();
    }
    return SuperResolutionJob(
      key: key,
      imageId: id,
      status: status,
      url: url,
      error: json['error'] as String?,
    );
  }
}
