import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum FeedbackTone { success, info, warning, error }

/// A bordered status message that screen readers announce when it appears.
class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({super.key, required this.message, required this.tone});

  final String message;
  final FeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (tone) {
      FeedbackTone.success => (AppColors.success, Icons.check_circle_outline),
      FeedbackTone.info => (AppColors.cyan, Icons.info_outline),
      FeedbackTone.warning => (
        AppColors.mediumPriority,
        Icons.warning_amber_outlined,
      ),
      FeedbackTone.error => (AppColors.highPriority, Icons.error_outline),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.raisedSurface,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
