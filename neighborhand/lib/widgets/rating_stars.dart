import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A row of stars with the review count, e.g. "★★★★☆ 4.6 (12)".
/// Shows "New" when nobody has reviewed yet, so a blank space never reads as zero stars.
class RatingStars extends StatelessWidget {
  final double? rating;
  final int reviewCount;
  final double size;

  /// Off for a single review's own stars, where the number repeats the stars.
  final bool showCount;

  const RatingStars({
    super.key,
    required this.rating,
    required this.reviewCount,
    this.size = 16,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    final value = rating;
    if (value == null || reviewCount == 0) {
      return Text(
        'New',
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            value >= star
                ? Icons.star
                : value >= star - 0.5
                    ? Icons.star_half
                    : Icons.star_border,
            size: size,
            color: AppColors.accentDark,
          ),
        if (showCount) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${value.toStringAsFixed(1)} ($reviewCount)',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Five tappable stars. Reports the chosen rating as you tap.
class StarPicker extends StatelessWidget {
  final int rating;
  final ValueChanged<int>? onChanged;

  const StarPicker({super.key, required this.rating, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          IconButton(
            onPressed: onChanged == null ? null : () => onChanged!(star),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            constraints: const BoxConstraints(),
            tooltip: '$star star${star == 1 ? '' : 's'}',
            icon: Icon(
              star <= rating ? Icons.star : Icons.star_border,
              size: 36,
              color: star <= rating ? AppColors.accentDark : AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}
