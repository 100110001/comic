import 'package:flutter/material.dart';
import '../models/comic.dart';
import 'comic_card.dart';
import 'status_views.dart';

/// 按可用宽度返回漫画网格的列数：
/// <480 → 2 列；480–599 → 3 列；600–899 → 4 列；900–1199 → 5 列；
/// 1200–1599 → 6 列；≥1600 → 7 列。
int comicGridColumns(double width) {
  if (width < 480) return 2;
  if (width < 600) return 3;
  if (width < 900) return 4;
  if (width < 1200) return 5;
  if (width < 1600) return 6;
  return 7;
}

/// 漫画网格：列数随可用宽度分档，超宽屏封顶 1920px 居中，
/// 保证各尺寸下卡片观感均匀。
class ComicGrid extends StatelessWidget {
  final List<Comic> comics;
  final bool loading;
  final double bottomPadding;
  final ScrollController? controller;
  final void Function(Comic comic)? onTap;
  final ValueChanged<int>? onColumnsChanged;
  final String emptyMessage;
  const ComicGrid({
    super.key,
    required this.comics,
    required this.loading,
    this.bottomPadding = 0,
    this.controller,
    this.onTap,
    this.onColumnsChanged,
    this.emptyMessage = '书库里还没有漫画',
  });

  static const double _maxGridWidth = 1920;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxGridWidth),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final columns = comicGridColumns(constraints.maxWidth);
            if (onColumnsChanged != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted) onColumnsChanged!(columns);
              });
            }
            final spacing = constraints.maxWidth < 600 ? 10.0 : 20.0;
            final padding = constraints.maxWidth < 600 ? 16.0 : 28.0;
            // 与卡片共享文字高度，系统放大字体后仍容纳两行标题和作者。
            final cardWidth =
                (constraints.maxWidth - padding * 2 - spacing * (columns - 1)) /
                columns;
            final textHeight = ComicCard.textAreaHeight(
              MediaQuery.textScalerOf(ctx),
            );
            final childAspectRatio =
                cardWidth / (cardWidth * 4 / 3 + textHeight);
            return Stack(
              children: [
                GridView.builder(
                  controller: controller,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    padding,
                    8,
                    padding,
                    24 + bottomPadding,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                  ),
                  itemCount:
                      comics.length + (loading && comics.isNotEmpty ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == comics.length) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final comic = comics[i];
                    return ComicCard(
                      comic: comic,
                      onTap: onTap == null ? null : () => onTap!(comic),
                    );
                  },
                ),
                if (comics.isEmpty)
                  IgnorePointer(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : StatusView(
                            icon: Icons.auto_stories_outlined,
                            message: emptyMessage,
                          ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
