import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/image_item.dart';
import '../services/api.dart';
import 'comics_providers.dart';

final chapterImagesProvider = FutureProvider.family<List<ImageItem>, int>(
  (ref, chapterId) => ApiService.getChapterImages(chapterId),
);

Future<void> updateReadingProgress(
  WidgetRef ref, {
  required int comicId,
  required int chapterId,
  required int pageNumber,
}) async {
  await ApiService.updateProgress(
    comicId: comicId,
    chapterId: chapterId,
    pageNumber: pageNumber,
  );
  ref.invalidate(recentReadingProvider);
  ref.invalidate(comicDetailProvider(comicId));
}
