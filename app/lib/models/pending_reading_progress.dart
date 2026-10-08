import 'comic.dart';
import 'reading_progress_entry.dart';

/// 仅保存尚未由服务器确认的阅读断点。
class PendingReadingProgress {
  const PendingReadingProgress({required this.entry, required this.revision});

  final ReadingProgressEntry entry;
  final int revision;

  String get serverUrl => entry.comic.serverUrl;
  String get key => '$serverUrl\u0000${entry.comic.id}';
  ({int chapterId, int pageNumber}) get position =>
      (chapterId: entry.chapterId, pageNumber: entry.pageNumber);

  Map<String, Object?> toJson() => {
    'serverUrl': serverUrl,
    'revision': revision,
    'comic': {
      'id': entry.comic.id,
      'title': entry.comic.title,
      'author': entry.comic.author,
      'cover_path': entry.comic.coverPath,
      'chapter_count': entry.comic.chapterCount,
      'image_count': entry.comic.imageCount,
    },
    'chapterId': entry.chapterId,
    'chapterTitle': entry.chapterTitle,
    'pageNumber': entry.pageNumber,
  };

  factory PendingReadingProgress.fromJson(Map<String, dynamic> json) {
    final comic = Comic.fromJson(
      json['comic'] as Map<String, dynamic>,
      serverUrl: json['serverUrl'] as String,
    );
    final chapterId = json['chapterId'] as int;
    final page = json['pageNumber'] as int;
    final revision = json['revision'] as int;
    if (comic.id <= 0 || chapterId <= 0 || page < 0 || revision <= 0) {
      throw const FormatException('无效的本机阅读断点');
    }
    return PendingReadingProgress(
      entry: ReadingProgressEntry(
        comic: comic,
        chapterId: chapterId,
        chapterTitle: json['chapterTitle'] as String,
        pageNumber: page,
      ),
      revision: revision,
    );
  }
}
