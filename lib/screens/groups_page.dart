import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/limits.dart';
import '../models/collaborative_list.dart';
import '../theme/app_theme.dart';
import '../widgets/status_panel.dart';
import 'profile_screen.dart';

/// Picks a group to open and shows the UID others need to add this account.
///
/// CollaborativeWorkspace owns the list stream and the active scope.
class GroupsPage extends StatelessWidget {
  const GroupsPage({
    super.key,
    required this.uid,
    required this.lists,
    required this.onOpen,
    required this.onRetry,
    this.initializing = false,
    this.error,
    this.appBarBottom,
  });

  final String uid;
  final List<CollaborativeList> lists;
  final ValueChanged<CollaborativeList> onOpen;
  final VoidCallback onRetry;
  final bool initializing;
  final String? error;
  final PreferredSizeWidget? appBarBottom;

  Future<void> _copyUid(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      await Clipboard.setData(ClipboardData(text: uid));
      message = 'Account UID copied.';
    } on PlatformException {
      message = 'Could not copy. Select the UID and copy it manually.';
    }
    if (!messenger.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Every default group is named "My group", so equal names need the ID.
  String _subtitle(CollaborativeList list) {
    final role = list.ownerId == uid ? 'Owner' : 'Member';
    final duplicate =
        lists.where((other) => other.name == list.name).length > 1;
    final shortId = list.id.substring(
      0,
      list.id.length < 8 ? list.id.length : 8,
    );
    return '$role · ${list.memberIds.length}/$maxListMembers members'
        '${duplicate ? ' · $shortId' : ''}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('DO IT NOW!'),
      actions: const [ProfileButton(), SizedBox(width: 8)],
      bottom: appBarBottom,
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: EdgeInsets.all(compact ? 16 : 24),
              children: [
                StatusPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const StatusEyebrow('Your account UID'),
                      const SizedBox(height: 8),
                      SelectableText(
                        uid,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Share this UID with a group owner so they can add you.',
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _copyUid(context),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy UID'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Your groups',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (initializing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Preparing your group',
                    ),
                  ),
                if (error != null)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(error!),
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ...lists.map(
                  (list) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(
                        list.ownerId == uid
                            ? Icons.shield_outlined
                            : Icons.group_outlined,
                        color: AppColors.cyan,
                      ),
                      title: Text(
                        list.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        _subtitle(list),
                        style: const TextStyle(color: AppColors.secondaryText),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onOpen(list),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
