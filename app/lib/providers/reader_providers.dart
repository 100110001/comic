import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/image_item.dart';
import 'comics_providers.dart';
import 'server_provider.dart';

final chapterImagesProvider = FutureProvider.family<List<ImageItem>, int>(
  (ref, chapterId) => ref.watch(apiClientProvider).getChapterImages(chapterId),
);

Future<void> updateReadingProgress(
  WidgetRef ref, {
  required int comicId,
  required int chapterId,
  required int pageNumber,
}) async {
  final client = ref.read(apiClientProvider);
  await client.updateProgress(
    comicId: comicId,
    chapterId: chapterId,
    pageNumber: pageNumber,
  );
  if (ref.read(serverSessionProvider).generation != client.generation) return;
  ref.invalidate(recentReadingProvider);
  ref.invalidate(comicDetailProvider(comicId));
}
