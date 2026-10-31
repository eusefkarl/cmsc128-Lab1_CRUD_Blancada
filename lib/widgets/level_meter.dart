import 'package:flutter/material.dart';

import '../core/progression.dart';
import '../theme/app_theme.dart';

class LevelMeter extends StatelessWidget {
  const LevelMeter({super.key, required this.progression});

  final Progression progression;

  @override
  Widget build(BuildContext context) {
    final xp = progression.xpIntoLevel;
    final needed = progression.xpToNextLevel;
    return Semantics(
      label: 'Level ${progression.level}',
      value: '$xp of $needed XP',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    'Level ${progression.level}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontFamily: AppFonts.display,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$xp / $needed XP',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: TweenAnimationBuilder<double>(
                // A new level starts a new bar instead of sweeping backward.
                key: ValueKey(progression.level),
                tween: Tween(end: progression.levelRatio),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  color: AppColors.success,
                  backgroundColor: AppColors.divider,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
