import 'package:flutter/material.dart';
import '../models/chapter.dart';

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
      backgroundColor: const Color(0xFF161b22),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '目录',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Color(0xFF21262d), height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (ctx, i) {
                  final selected = i == currentIndex;
                  return ListTile(
                    dense: true,
                    selected: selected,
                    selectedTileColor: const Color(0xFF1f2937),
                    title: Text(
                      chapters[i].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF58a6ff)
                            : Colors.white,
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
