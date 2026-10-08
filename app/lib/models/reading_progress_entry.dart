import '../config.dart';
import 'comic.dart';

class ReadingProgressEntry {
  final Comic comic;
  final int chapterId;
  final String chapterTitle;
  final int pageNumber;

  const ReadingProgressEntry({
    required this.comic,
    required this.chapterId,
    required this.chapterTitle,
    required this.pageNumber,
  });

  factory ReadingProgressEntry.fromJson(
    Map<String, dynamic> j, {
    String serverUrl = defaultServerUrl,
  }) => ReadingProgressEntry(
    comic: Comic.fromJson(j, serverUrl: serverUrl),
    chapterId: j['chapter_id'],
    chapterTitle: j['chapter_title'] ?? '',
    pageNumber: j['page_number'] ?? 0,
  );
}
