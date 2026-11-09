import 'package:flutter/material.dart';
import 'package:spoton/src/models/event.dart';

import 'colors.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.date,
    required this.favorite,
    required this.onTap,
    this.onFavorite,
  });
  final Event event;
  final String date;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(event.categoryIcon, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.categoryName.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    event.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(date),
                  Text(
                    event.local,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    event.formattedPrice,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onFavorite,
              isSelected: favorite,
              tooltip: favorite ? 'Remover dos favoritos' : 'Favoritar',
              selectedIcon: const Icon(Icons.favorite, color: AppColors.accent),
              icon: const Icon(Icons.favorite_border),
            ),
          ],
        ),
      ),
    ),
  );
}
