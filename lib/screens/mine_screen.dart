import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/comics_providers.dart';
import '../widgets/reading_lists.dart';

class MineScreen extends ConsumerStatefulWidget {
  const MineScreen({super.key});

  @override
  ConsumerState<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends ConsumerState<MineScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
    _controller.addListener(() {
      // 切 tab 时后台刷新对应列表，避免展示旧状态
      if (_controller.indexIsChanging) {
        switch (_controller.index) {
          case 0:
            ref.invalidate(recentReadingProvider);
            break;
          case 1:
            ref.invalidate(favoritesProvider);
            break;
          case 2:
            ref.invalidate(favoriteAuthorsProvider);
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161b22),
        title: const Text('我的', style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _controller,
          indicatorColor: const Color(0xFF58a6ff),
          labelColor: const Color(0xFF58a6ff),
          unselectedLabelColor: const Color(0xFF8b949e),
          tabs: const [
            Tab(text: '最近阅读'),
            Tab(text: '收藏'),
            Tab(text: '收藏作者'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [
          RecentReadingList(),
          FavoritesList(),
          FavoriteAuthorsList(),
        ],
      ),
    );
  }
}
