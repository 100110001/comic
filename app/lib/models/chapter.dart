class Chapter {
  final int id;
  final String title;
  final int sortOrder;

  const Chapter({
    required this.id,
    required this.title,
    required this.sortOrder,
  });

  factory Chapter.fromJson(Map<String, dynamic> j) =>
      Chapter(id: j['id'], title: j['title'], sortOrder: j['sort_order'] ?? 0);
}
