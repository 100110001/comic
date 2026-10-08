import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/image_item.dart';
import 'server_provider.dart';

final chapterImagesProvider = FutureProvider.family<List<ImageItem>, int>(
  (ref, chapterId) => ref.watch(apiClientProvider).getChapterImages(chapterId),
);
