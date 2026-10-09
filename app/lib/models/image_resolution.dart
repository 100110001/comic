import 'super_resolution_job.dart';

class ImageResolution {
  const ImageResolution({
    required this.imageId,
    required this.originalUrl,
    this.superResolution,
    this.error,
  });
  final int imageId;
  final String originalUrl;
  final SuperResolutionJob? superResolution;
  final String? error;
  factory ImageResolution.fromJson(
    Map<String, dynamic> json,
    String serverUrl,
  ) {
    final id = json['id'] as int;
    final relative = Uri.parse(json['url'] as String);
    if (id <= 0 ||
        relative.hasScheme ||
        relative.hasAuthority ||
        !relative.path.startsWith('/static/') ||
        relative.fragment.isNotEmpty)
      throw const FormatException('无效原图响应');
    final job = json['superResolution'];
    final parsed = job == null
        ? null
        : SuperResolutionJob.fromJson(job as Map<String, dynamic>, serverUrl);
    if (parsed != null && parsed.imageId != id)
      throw const FormatException('超分页面不匹配');
    return ImageResolution(
      imageId: id,
      originalUrl: Uri.parse('$serverUrl/').resolveUri(relative).toString(),
      superResolution: parsed,
      error: json['error'] as String?,
    );
  }
}
