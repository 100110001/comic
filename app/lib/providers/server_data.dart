import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'comics_providers.dart';
import 'discovery_providers.dart';
import 'reader_providers.dart';
import 'server_provider.dart';

/// 保存新服务器并销毁所有绑定旧数据源的会话状态。
Future<bool> saveServerUrl(WidgetRef ref, String input) async {
  final changed = await ref.read(serverSessionProvider.notifier).save(input);
  if (!changed) return false;

  ref.read(randomSeedProvider.notifier).reshuffle();
  ref.invalidate(randomLibraryProvider);
  ref.invalidate(searchProvider);
  ref.invalidate(discoveryProvider);
  ref.invalidate(favoritesProvider);
  ref.invalidate(favoriteAuthorsProvider);
  ref.invalidate(favoriteAuthorBooksProvider);
  ref.invalidate(recentReadingProvider);
  ref.invalidate(comicDetailProvider);
  ref.invalidate(chapterImagesProvider);
  return true;
}
