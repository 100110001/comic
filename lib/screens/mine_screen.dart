import 'package:flutter/material.dart';
import '../widgets/reading_lists.dart';

class MineScreen extends StatefulWidget {
  const MineScreen({super.key});

  @override
  State<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends State<MineScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  final _authorsKey = GlobalKey<FavoriteAuthorsListState>();

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
    _controller.addListener(() {
      // 切到"收藏作者"tab 时刷新，避免展示收藏后的旧状态
      if (_controller.indexIsChanging && _controller.index == 2) {
        _authorsKey.currentState?.reload();
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
        children: [
          const RecentReadingList(),
          const FavoritesList(),
          FavoriteAuthorsList(key: _authorsKey),
        ],
      ),
    );
  }
}
