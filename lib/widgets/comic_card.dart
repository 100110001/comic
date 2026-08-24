import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../theme.dart';

class ComicCard extends StatelessWidget {
  final Comic comic;
  final VoidCallback? onTap;
  const ComicCard({super.key, required this.comic, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  comic.coverUrl != null
                      ? Image.network(
                          comic.coverUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, _, _) => _placeholder(),
                        )
                      : _placeholder(),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (comic.favorited) ...[
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(kRadiusSmall),
                            ),
                            child: const Icon(
                              Icons.favorite,
                              color: kFavorite,
                              size: 13,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(kRadiusSmall),
                          ),
                          child: Text(
                            '${comic.chapterCount}话 · ${comic.imageCount}P',
                            style: const TextStyle(color: kText1, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comic.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kText1,
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (comic.author != null)
                    Text(
                      comic.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kText2,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: kSurface2,
    child: const Icon(Icons.image_not_supported, color: kText2),
  );
}
