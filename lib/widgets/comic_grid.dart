import 'package:flutter/material.dart';
import '../models/comic.dart';
import 'comic_card.dart';

/// 按可用宽度返回漫画网格的列数：
/// <600 → 3 列；600–899 → 4 列；900–1199 → 5 列；
/// 1200–1599 → 6 列；≥1600 → 7 列。
int comicGridColumns(double width) {
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
  final ScrollController? controller;
  final void Function(Comic comic)? onTap;
  const ComicGrid({
    super.key,
    required this.comics,
    required this.loading,
    this.controller,
    this.onTap,
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
            // 卡片高度 = 封面（3:4，占卡宽×4/3）+ 固定文字区（约 48px），
            // 按实际卡宽动态计算高宽比，避免卡片底部留白或文字溢出。
            final cardWidth =
                (constraints.maxWidth - 24 - 10 * (columns - 1)) / columns;
            final childAspectRatio = cardWidth / (cardWidth * 4 / 3 + 48);
            return GridView.builder(
              controller: controller,
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: comics.length + (loading ? 1 : 0),
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
            );
          },
        ),
      ),
    );
  }
}
