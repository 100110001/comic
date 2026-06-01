class Comic {
  final int id;
  final String title;
  final String? author;
  final String? coverPath;
  const Comic({
    required this.id,
    required this.title,
    this.author,
    this.coverPath,
  });

  factory Comic.fromJson(Map<String, dynamic> j) => Comic(
    id: j['id'],
    title: j['title'],
    author: j['author'],
    coverPath: j['cover_path'],
  );

  String? get coverUrl {
    if (coverPath == null) return null;
    final rel = coverPath!
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^.*?/comic/'), '');
    return 'http://localhost:8888/static/$rel';
  }
}
