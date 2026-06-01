class Comic {
  final int id;
  final String title;
  final String? author;
  final String? coverPath;
  final int chapterCount;
  final int imageCount;

  const Comic({
    required this.id,
    required this.title,
    this.author,
    this.coverPath,
    this.chapterCount = 0,
    this.imageCount = 0,
  });

  factory Comic.fromJson(Map<String, dynamic> j) => Comic(
    id: j['id'],
    title: j['title'],
    author: j['author'],
    coverPath: j['cover_path'],
    chapterCount: int.tryParse(j['chapter_count']?.toString() ?? '0') ?? 0,
    imageCount: int.tryParse(j['image_count']?.toString() ?? '0') ?? 0,
  );

  String? get coverUrl {
    if (coverPath == null) return null;
    final rel = coverPath!
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^.*?/comic/'), '');
    return 'http://localhost:8888/static/$rel';
  }
}
