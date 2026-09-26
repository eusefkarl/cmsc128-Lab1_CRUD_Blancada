import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatusPanel extends StatelessWidget {
  const StatusPanel({super.key, required this.child, this.padding = 20});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider),
    ),
    child: Stack(
      children: [
        Padding(padding: EdgeInsets.all(padding), child: child),
        const Positioned(
          left: 0,
          top: 0,
          child: ExcludeSemantics(child: _CornerMark(topLeft: true)),
        ),
        const Positioned(
          right: 0,
          bottom: 0,
          child: ExcludeSemantics(child: _CornerMark(topLeft: false)),
        ),
      ],
    ),
  );
}

class _CornerMark extends StatelessWidget {
  const _CornerMark({required this.topLeft});

  final bool topLeft;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 16,
    height: 16,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: topLeft
              ? const BorderSide(color: AppColors.cyan, width: 2)
              : BorderSide.none,
          left: topLeft
              ? const BorderSide(color: AppColors.cyan, width: 2)
              : BorderSide.none,
          bottom: topLeft
              ? BorderSide.none
              : const BorderSide(color: AppColors.cyan, width: 2),
          right: topLeft
              ? BorderSide.none
              : const BorderSide(color: AppColors.cyan, width: 2),
        ),
        borderRadius: BorderRadius.only(
          topLeft: topLeft ? const Radius.circular(12) : Radius.zero,
          bottomRight: topLeft ? Radius.zero : const Radius.circular(12),
        ),
      ),
    ),
  );
}

class StatusEyebrow extends StatelessWidget {
  const StatusEyebrow(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppColors.cyan,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    ),
  );
}
