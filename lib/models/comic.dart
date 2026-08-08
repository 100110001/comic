import '../config.dart';

class Comic {
  final int id;
  final String title;
  final String? author;
  final String? coverPath;
  final int chapterCount;
  final int imageCount;
  final bool favorited;

  const Comic({
    required this.id,
    required this.title,
    this.author,
    this.coverPath,
    this.chapterCount = 0,
    this.imageCount = 0,
    this.favorited = false,
  });

  factory Comic.fromJson(Map<String, dynamic> j) => Comic(
    id: j['id'],
    title: j['title'],
    author: j['author'],
    coverPath: j['cover_path'],
    chapterCount: int.tryParse(j['chapter_count']?.toString() ?? '0') ?? 0,
    imageCount: int.tryParse(j['image_count']?.toString() ?? '0') ?? 0,
    favorited: j['favorited'] == true || j['favorited'] == 1,
  );

  Comic withFavorited(bool value) => Comic(
    id: id,
    title: title,
    author: author,
    coverPath: coverPath,
    chapterCount: chapterCount,
    imageCount: imageCount,
    favorited: value,
  );

  String? get coverUrl {
    if (coverPath == null) return null;
    final rel = coverPath!
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^.*?/comic/'), '');
    return '$baseUrl/static/$rel';
  }
}
