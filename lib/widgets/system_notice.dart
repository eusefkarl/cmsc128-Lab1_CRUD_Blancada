import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// How long a [SystemNotice] message stays before its owner clears it.
const Duration systemNoticeDuration = Duration(seconds: 3);

/// A brief announcement that slides in over the page, separate from SnackBar
/// so it cannot replace a bar the user may still need, such as Undo.
class SystemNotice extends StatelessWidget {
  const SystemNotice({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -0.4),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: message == null
            ? const SizedBox.shrink()
            : Semantics(
                key: ValueKey(message),
                container: true,
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.panel),
                    border: Border.all(color: AppColors.purple, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x667D2DFF), blurRadius: 20),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ExcludeSemantics(
                        child: Icon(Icons.bolt, color: AppColors.cyan),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w700,
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
}
