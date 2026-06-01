import '../config.dart';

class ImageItem {
  final int id;
  final String filename;
  final int pageNumber;
  final String url;

  const ImageItem({
    required this.id,
    required this.filename,
    required this.pageNumber,
    required this.url,
  });

  factory ImageItem.fromJson(Map<String, dynamic> j) => ImageItem(
    id: j['id'],
    filename: j['filename'],
    pageNumber: j['pageNumber'],
    url: '$baseUrl${j['url']}',
  );
}
