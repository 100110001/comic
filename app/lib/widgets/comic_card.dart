import 'package:flutter/material.dart';
import 'display_network_image.dart';
import '../models/comic.dart';
import '../theme.dart';

class ComicCard extends StatefulWidget {
  final Comic comic;
  final VoidCallback? onTap;
  const ComicCard({super.key, required this.comic, this.onTap});

  /// 与网格共享文字区高度，预留单行标题和单行作者。
  static double textAreaHeight(TextScaler scaler) =>
      20 +
      (scaler.scale(14) * 1.4).ceilToDouble() +
      6 +
      (scaler.scale(12) * 1.4).ceilToDouble();

  @override
  State<ComicCard> createState() => _ComicCardState();
}

class _ComicCardState extends State<ComicCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final comic = widget.comic;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: Card(
          color: Colors.transparent,
          shape: const RoundedRectangleBorder(),
          clipBehavior: Clip.none,
          child: InkWell(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(kRadiusThumb),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        comic.coverUrl != null
                            ? DisplayNetworkImage(
                                comic.coverUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, _, _) =>
                                    _placeholder(context),
                              )
                            : _placeholder(context),
                        if (comic.favorited)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(
                                  kRadiusThumb,
                                ),
                              ),
                              child: Icon(
                                Icons.favorite,
                                color: c.favorite,
                                size: 16,
                              ),
                            ),
                          ),
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(
                                  kRadiusSmall,
                                ),
                              ),
                              child: Text(
                                '${comic.chapterCount}话 · ${comic.imageCount}P',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: ComicCard.textAreaHeight(
                    MediaQuery.textScalerOf(context),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tooltip(
                          message: comic.title,
                          child: Text(
                            comic.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.text1,
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 6),
                        Text(
                          comic.author ?? '未知作者',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.text2,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final c = context.appColors;
    return Container(
      color: c.surface2,
      child: Icon(Icons.auto_stories_outlined, color: c.text2, size: 32),
    );
  }
}
