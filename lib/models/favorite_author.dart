class FavoriteAuthor {
  final String author;
  final int comicCount;

  const FavoriteAuthor({required this.author, required this.comicCount});

  factory FavoriteAuthor.fromJson(Map<String, dynamic> j) => FavoriteAuthor(
    author: j['author'] ?? '',
    comicCount: int.tryParse(j['comic_count']?.toString() ?? '0') ?? 0,
  );
}
