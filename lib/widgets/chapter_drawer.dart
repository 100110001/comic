import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../theme.dart';

class ChapterDrawer extends StatelessWidget {
  final List<Chapter> chapters;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  const ChapterDrawer({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: kSurface1,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '目录',
                style: TextStyle(
                  color: kText1,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: chapters.isEmpty
                  ? const Center(
                      child: Text('暂无章节', style: TextStyle(color: kText2)),
                    )
                  : ListView.builder(
                      itemCount: chapters.length,
                      itemBuilder: (ctx, i) {
                        final selected = i == currentIndex;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: kSurface2,
                          title: Text(
                            chapters[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? kAccent : kText1,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () => onSelect(i),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
