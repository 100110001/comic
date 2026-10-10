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
  Widget build(BuildContext context) => Drawer(
    child: ChapterDirectory(
      chapters: chapters,
      currentIndex: currentIndex,
      onSelect: onSelect,
    ),
  );
}

/// 桌面侧栏与手机底部面板共用的章节内容。
class ChapterDirectory extends StatelessWidget {
  final List<Chapter> chapters;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  const ChapterDirectory({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '目录',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '共 ${chapters.length} 章',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭目录',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: chapters.isEmpty
                ? Center(
                    child: Text('暂无章节', style: TextStyle(color: c.text2)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: chapters.length,
                    itemBuilder: (ctx, i) {
                      final selected = i == currentIndex;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          selected: selected,
                          selectedTileColor: c.accent.withValues(alpha: 0.10),
                          title: Text(
                            chapters[i].title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: selected ? c.accent : c.text1,
                                  fontWeight: selected
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                          ),
                          trailing: selected
                              ? Icon(Icons.check, size: 18, color: c.accent)
                              : null,
                          onTap: () => onSelect(i),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
