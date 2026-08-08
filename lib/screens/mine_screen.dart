import 'package:flutter/material.dart';
import '../widgets/reading_lists.dart';

class MineScreen extends StatelessWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0d1117),
        appBar: AppBar(
          backgroundColor: const Color(0xFF161b22),
          title: const Text('我的', style: TextStyle(color: Colors.white)),
          bottom: const TabBar(
            indicatorColor: Color(0xFF58a6ff),
            labelColor: Color(0xFF58a6ff),
            unselectedLabelColor: Color(0xFF8b949e),
            tabs: [
              Tab(text: '最近阅读'),
              Tab(text: '收藏'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [RecentReadingList(), FavoritesList()],
        ),
      ),
    );
  }
}
