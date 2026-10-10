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
    final c = context.appColors;
    return Drawer(
      backgroundColor: c.surface1,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Text(
                '目录',
                style: TextStyle(
                  color: c.text1,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: chapters.isEmpty
                  ? Center(
                      child: Text('暂无章节', style: TextStyle(color: c.text2)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: chapters.length,
                      itemBuilder: (ctx, i) {
                        final selected = i == currentIndex;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: c.accent.withValues(alpha: 0.10),
                          title: Text(
                            chapters[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? c.accent : c.text1,
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
