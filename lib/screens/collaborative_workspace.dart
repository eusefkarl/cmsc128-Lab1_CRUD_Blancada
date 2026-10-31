import 'dart:async';

import 'package:flutter/material.dart';

import '../core/action_error.dart';
import '../core/limits.dart';
import '../core/validation.dart';
import '../models/collaborative_list.dart';
import '../services/collaboration_service.dart';
import '../services/task_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/input_lock.dart';
import 'groups_page.dart';
import 'task_home_page.dart';

const int _personalTab = 0;
const int _groupsTab = 1;

/// An action with no [onSelected] is shown disabled, with [tooltip] saying why.
typedef _GroupAction = ({
  String label,
  IconData icon,
  VoidCallback? onSelected,
  String? tooltip,
});

/// Hosts the Personal and Groups tabs. A fresh keyed task screen owns each
/// scope's stream, forms and Undo timers.
class CollaborativeWorkspace extends StatefulWidget {
  const CollaborativeWorkspace({super.key, this.service});
  final CollaborationService? service;

  @override
  State<CollaborativeWorkspace> createState() => _CollaborativeWorkspaceState();
}

class _CollaborativeWorkspaceState extends State<CollaborativeWorkspace>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late CollaborationService _service;
  StreamSubscription<List<CollaborativeList>>? _subscription;
  List<CollaborativeList> _lists = [];
  String? _selectedId;
  late TaskRepository _repository;
  String? _error;
  bool _initializing = true;
  int _generation = 0;
  DialogRoute<dynamic>? _groupDialog;

  void _closeGroupDialog() {
    final route = _groupDialog;
    _groupDialog = null;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _start();
  }

  @override
  void didUpdateWidget(CollaborativeWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _tabs.index = _personalTab;
      _start();
    }
  }

  void _start() {
    _closeGroupDialog();
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    _service = widget.service ?? FirebaseCollaborationService();
    _lists = [];
    _selectedId = null;
    _repository = _service.tasksFor(null);
    _error = null;
    _initializing = true;
    _subscription = _service.watchLists().listen(
      (lists) {
        if (!mounted || generation != _generation) return;
        final revoked =
            _selectedId != null && !lists.any((list) => list.id == _selectedId);
        setState(() {
          _lists = lists;
          if (revoked) _setScope(null);
        });
        if (revoked) _notify('Access to that group ended.');
      },
      onError: (Object error) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _lists = [];
          _setScope(null);
          _error = 'Groups are unavailable. Retry to reconnect.';
        });
      },
    );
    unawaited(_initialize(generation));
  }

  Future<void> _initialize(int generation) async {
    try {
      await _service.ensureDefaultList();
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(
        () => _error = 'Could not prepare your group. Retry to reconnect.',
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _initializing = false);
      }
    }
  }

  @override
  void dispose() {
    _closeGroupDialog();
    ++_generation;
    unawaited(_subscription?.cancel());
    _tabs.dispose();
    super.dispose();
  }

  void _notify(String message) {
    // The active tab's page owns the scaffold below this context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    });
  }

  void _setScope(String? id) {
    _closeGroupDialog();
    _selectedId = id;
    _repository = _service.tasksFor(id);
  }

  void _accessLost() {
    if (!mounted || _selectedId == null) return;
    setState(() => _setScope(null));
    _notify('Access to that group ended.');
  }

  // Any tab tap closes the open group, so tapping Groups inside a group returns
  // to the picker and leaving a group disposes its task screen.
  void _selectTab(int _) => setState(() => _setScope(null));

  @override
  Widget build(BuildContext context) {
    // Fixed tabs cannot scroll out of reach on a narrow display.
    final compact = MediaQuery.sizeOf(context).width < 700;
    final tabs = TabBar(
      controller: _tabs,
      isScrollable: !compact,
      tabAlignment: compact ? TabAlignment.fill : TabAlignment.start,
      onTap: _selectTab,
      tabs: const [
        Tab(text: 'Personal'),
        Tab(text: 'Groups'),
      ],
    );
    final selected = _lists.where((list) => list.id == _selectedId).firstOrNull;
    if (_tabs.index == _groupsTab && selected == null) {
      return GroupsPage(
        uid: _service.uid,
        lists: _lists,
        initializing: _initializing,
        error: _error,
        onRetry: () => setState(_start),
        onOpen: (list) => setState(() => _setScope(list.id)),
        onCreate: _createGroup,
        appBarBottom: tabs,
      );
    }
    return TaskHomePage(
      key: ValueKey(
        '${_service.uid}:${_selectedId ?? 'personal'}:$_generation',
      ),
      repository: _repository,
      listName: selected?.name ?? 'Personal',
      onAccessLost: _selectedId == null ? null : _accessLost,
      creatorNames: selected == null ? null : _service.displayNames,
      appBarBottom: tabs,
      listControls: selected == null ? null : _groupHeader(selected),
    );
  }

  Widget _groupHeader(CollaborativeList list) {
    final service = _service;
    final owner = list.ownerId == service.uid;
    final compact = MediaQuery.sizeOf(context).width < 700;
    final inset = compact ? 16.0 : 24.0;
    final actions = <_GroupAction>[
      if (owner) ...[
        (
          label: 'Manage members',
          icon: Icons.manage_accounts_outlined,
          onSelected: () => _showGroupDialog(
            (_) => _MembersDialog(list: list, service: service),
          ),
          tooltip: null,
        ),
        (
          label: 'Rename group',
          icon: Icons.drive_file_rename_outline,
          onSelected: () => _showGroupDialog(
            (_) => _GroupNameDialog(
              title: 'Rename group',
              submitLabel: 'Save',
              initialName: list.name,
              onSubmit: (name) => service.renameList(list.id, name),
            ),
          ),
          tooltip: null,
        ),
      ] else ...[
        (
          label: 'Manage members',
          icon: Icons.manage_accounts_outlined,
          onSelected: null,
          tooltip: 'Only the group owner can manage members',
        ),
        (
          label: 'Leave group',
          icon: Icons.logout,
          onSelected: () => _leaveGroup(list),
          tooltip: null,
        ),
      ],
    ];
    final identity = <Widget>[
      TextButton.icon(
        onPressed: () => setState(() => _setScope(null)),
        icon: const Icon(Icons.arrow_back),
        label: const Text('All groups'),
      ),
      Text(
        owner
            ? 'Owner · ${list.memberIds.length}/$maxListMembers members'
            : 'Member · shared task access',
      ),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(inset - 12, 8, compact ? 4 : inset, 0),
          child: compact
              ? Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: identity,
                      ),
                    ),
                    if (actions.isNotEmpty)
                      PopupMenuButton<_GroupAction>(
                        tooltip: 'Group actions',
                        onSelected: (action) => action.onSelected?.call(),
                        itemBuilder: (_) => [
                          for (final action in actions)
                            PopupMenuItem(
                              value: action,
                              enabled: action.onSelected != null,
                              child: _withActionTooltip(
                                action,
                                Row(
                                  children: [
                                    Icon(action.icon),
                                    const SizedBox(width: 12),
                                    Flexible(child: Text(action.label)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...identity,
                      for (final action in actions)
                        _withActionTooltip(
                          action,
                          TextButton.icon(
                            onPressed: action.onSelected,
                            icon: Icon(action.icon),
                            label: Text(action.label),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// Hover shows the tooltip with a mouse, and a tap shows it on touch screens.
  Widget _withActionTooltip(_GroupAction action, Widget child) {
    final tooltip = action.tooltip;
    if (tooltip == null) return child;
    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      child: child,
    );
  }

  Future<T?> _showGroupDialog<T>(WidgetBuilder builder) async {
    final route = DialogRoute<T>(context: context, builder: builder);
    _groupDialog = route;
    final result = await Navigator.of(context).push(route);
    if (_groupDialog == route) _groupDialog = null;
    return result;
  }

  Future<void> _createGroup() async {
    final service = _service;
    final generation = _generation;
    String? created;
    final confirmed = await _showGroupDialog<bool>(
      (_) => _GroupNameDialog(
        title: 'New group',
        submitLabel: 'Create',
        onSubmit: (name) async {
          await service.createList(name);
          created = name;
        },
      ),
    );
    if (mounted && generation == _generation && confirmed == true) {
      _notify('Created $created.');
    }
  }

  Future<void> _leaveGroup(CollaborativeList list) async {
    final service = _service;
    final generation = _generation;
    final confirmed = await _showGroupDialog<bool>(
      (dialogContext) => AlertDialog(
        title: Text('Leave ${list.name}?'),
        content: const Text(
          'You lose access right away. Tasks you created stay in the group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: AppButtonStyles.danger,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave group'),
          ),
        ],
      ),
    );
    if (!mounted || generation != _generation || confirmed != true) return;
    // Close the group first. Its task screen commits pending deletions while
    // this account is still a member, and losing the list is no longer news.
    setState(() => _setScope(null));
    await WidgetsBinding.instance.endOfFrame;
    String message;
    try {
      await service.leaveList(list.id);
      message = 'You left ${list.name}.';
    } catch (error) {
      debugPrint('Could not leave the group: $error');
      message = actionErrorMessage(error);
    }
    if (mounted && generation == _generation) _notify(message);
  }
}

class _MembersDialog extends StatefulWidget {
  const _MembersDialog({required this.list, required this.service});
  final CollaborativeList list;
  final CollaborationService service;
  @override
  State<_MembersDialog> createState() => _MembersDialogState();
}

class _MembersDialogState extends State<_MembersDialog> {
  final _memberUid = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _result = GlobalKey();
  late final List<String> _members = List.of(widget.list.memberIds);
  final Map<String, String> _names = {};
  bool _loadingNames = true;
  bool _namesFailed = false;
  String? _confirmingRemoval;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNames(_members));
  }

  @override
  void dispose() {
    _memberUid.dispose();
    super.dispose();
  }

  Future<void> _loadNames(List<String> uids) async {
    try {
      _names.addAll(await widget.service.displayNames(uids));
    } catch (_) {
      _namesFailed = true;
    }
    if (mounted) setState(() => _loadingNames = false);
  }

  String _memberLabel(String member) {
    if (_loadingNames) return 'Loading name…';
    final name = _names[member];
    if (name == null) {
      return _namesFailed ? member : 'Unknown account · $member';
    }
    final shared = _members.where((other) => _names[other] == name).length > 1;
    return shared ? '$name · ${shortId(member)}' : name;
  }

  Future<void> _perform(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final message = await action();
      if (mounted) setState(() => _message = message);
    } catch (error) {
      if (mounted) setState(() => _message = actionErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
      // Removing from a long list can leave the result scrolled out of view.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final result = _result.currentContext;
        if (result != null) unawaited(Scrollable.ensureVisible(result));
      });
    }
  }

  void _add() {
    if (!_form.currentState!.validate()) return;
    final memberUid = _memberUid.text.trim();
    _perform(() async {
      final result = await widget.service.addMember(widget.list.id, memberUid);
      if (!_members.contains(memberUid)) _members.add(memberUid);
      await _loadNames([memberUid]);
      return result == 'already-member'
          ? 'This account is already a member.'
          : 'Member added.';
    });
  }

  void _remove(String memberUid) => _perform(() async {
    await widget.service.removeMember(widget.list.id, memberUid);
    _members.remove(memberUid);
    _confirmingRemoval = null;
    return 'Member removed.';
  });

  Widget _memberRow(String member) {
    final isOwner = member == widget.list.ownerId;
    final confirming = member == _confirmingRemoval;
    final label = _memberLabel(member);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isOwner && !_loadingNames ? '$label (owner)' : label,
                ),
              ),
              if (!isOwner && !confirming)
                IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _confirmingRemoval = member;
                          _message = null;
                        }),
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: 'Remove member',
                ),
            ],
          ),
          // Confirmed inline: _closeGroupDialog only removes this one route.
          if (confirming)
            Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('They lose access right away.'),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _confirmingRemoval = null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _remove(member),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.highPriority,
                  ),
                  child: const Text('Remove'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text('Members of ${widget.list.name}'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter the account UID of a registered user. They can copy it from their Groups tab. Members can create, edit and delete tasks in this group.',
            ),
            const SizedBox(height: 12),
            InputLock(
              locked: _busy,
              child: TextFormField(
                controller: _memberUid,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                autovalidateMode: AutovalidateMode.onUserInteractionIfError,
                onFieldSubmitted: (_) {
                  if (!_busy) _add();
                },
                decoration: const InputDecoration(labelText: 'Account UID'),
                validator: (value) => isValidAccountUid(value ?? '')
                    ? null
                    : 'Enter a valid account UID.',
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (_message != null)
              Padding(
                key: _result,
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(liveRegion: true, child: Text(_message!)),
              ),
            const SizedBox(height: 16),
            Text(
              'Current members (${_members.length}/$maxListMembers)',
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_namesFailed)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Member names could not be loaded, so UIDs are shown.',
                ),
              ),
            ..._members.map(_memberRow),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton(
        onPressed: _busy ? null : _add,
        child: const Text('Add member'),
      ),
    ],
  );
}

/// Names a new group or renames an existing one. Pops true once [onSubmit]
/// succeeds, and otherwise stays open with the reason.
class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    this.initialName = '',
  });
  final String title;
  final String submitLabel;
  final String initialName;
  final Future<void> Function(String name) onSubmit;
  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.onSubmit(_name.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = actionErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.title),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InputLock(
              locked: _busy,
              child: TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: maxListNameLength,
                autovalidateMode: AutovalidateMode.onUserInteractionIfError,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(labelText: 'Group name'),
                validator: (value) => isValidListName(value ?? '')
                    ? null
                    : invalidListNameMessage,
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(liveRegion: true, child: Text(_message!)),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(widget.submitLabel),
      ),
    ],
  );
}
