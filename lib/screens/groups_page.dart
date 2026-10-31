import 'package:flutter/material.dart';

import '../core/limits.dart';
import '../models/collaborative_list.dart';
import '../theme/app_theme.dart';
import '../widgets/copy_uid_button.dart';
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
    required this.onCreate,
    this.initializing = false,
    this.error,
    this.appBarBottom,
  });

  final String uid;
  final List<CollaborativeList> lists;
  final ValueChanged<CollaborativeList> onOpen;
  final VoidCallback onRetry;
  final VoidCallback onCreate;
  final bool initializing;
  final String? error;
  final PreferredSizeWidget? appBarBottom;

  /// Every default group starts as "My group", so equal names need the ID.
  String _subtitle(CollaborativeList list) {
    final role = list.ownerId == uid ? 'Owner' : 'Member';
    final duplicate =
        lists.where((other) => other.name == list.name).length > 1;
    return '$role · ${list.memberIds.length}/$maxListMembers members'
        '${duplicate ? ' · ${shortId(list.id)}' : ''}';
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
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxContentWidth,
            ),
            child: ListView(
              padding: EdgeInsets.all(compact ? 16 : 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Your groups',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontFamily: AppFonts.display,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      FilledButton.icon(
                        onPressed: onCreate,
                        icon: const Icon(Icons.add),
                        label: const Text('New group'),
                      ),
                    ],
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
                const SizedBox(height: 12),
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
                      CopyUidButton(uid: uid),
                    ],
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
