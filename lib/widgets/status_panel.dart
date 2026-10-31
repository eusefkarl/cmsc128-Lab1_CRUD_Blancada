import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatusPanel extends StatelessWidget {
  const StatusPanel({super.key, required this.child, this.padding = 20});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.raisedSurface, AppColors.surface],
      ),
      borderRadius: BorderRadius.circular(AppRadii.panel),
      border: Border.all(color: AppColors.glowBorder),
      boxShadow: const [AppShadows.glow],
    ),
    child: Stack(
      children: [
        Padding(padding: EdgeInsets.all(padding), child: child),
        const Positioned(
          left: 0,
          top: 0,
          child: ExcludeSemantics(child: _CornerMark(top: true, left: true)),
        ),
        const Positioned(
          right: 0,
          top: 0,
          child: ExcludeSemantics(child: _CornerMark(top: true, left: false)),
        ),
        const Positioned(
          left: 0,
          bottom: 0,
          child: ExcludeSemantics(child: _CornerMark(top: false, left: true)),
        ),
        const Positioned(
          right: 0,
          bottom: 0,
          child: ExcludeSemantics(child: _CornerMark(top: false, left: false)),
        ),
      ],
    ),
  );
}

class _CornerMark extends StatelessWidget {
  const _CornerMark({required this.top, required this.left});

  final bool top;
  final bool left;

  static const _edge = BorderSide(color: AppColors.cyan, width: 2);
  static const _corner = Radius.circular(AppRadii.panel);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 14,
    height: 14,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: top ? _edge : BorderSide.none,
          bottom: top ? BorderSide.none : _edge,
          left: left ? _edge : BorderSide.none,
          right: left ? BorderSide.none : _edge,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? _corner : Radius.zero,
          topRight: top && !left ? _corner : Radius.zero,
          bottomLeft: !top && left ? _corner : Radius.zero,
          bottomRight: !top && !left ? _corner : Radius.zero,
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
      fontFamily: AppFonts.display,
      color: AppColors.cyan,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    ),
  );
}
