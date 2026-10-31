import 'dart:async';

import 'package:flutter/material.dart';

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
  DialogRoute<void>? _groupDialog;

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
      appBarBottom: tabs,
      listControls: selected == null ? null : _groupHeader(selected),
    );
  }

  Widget _groupHeader(CollaborativeList list) {
    final service = _service;
    final owner = list.ownerId == service.uid;
    final inset = MediaQuery.sizeOf(context).width < 700 ? 16.0 : 24.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: EdgeInsets.fromLTRB(inset - 12, 8, inset, 0),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _setScope(null)),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('All groups'),
                ),
                Text(
                  owner
                      ? 'Owner · ${list.memberIds.length}/'
                            '$maxListMembers members'
                      : 'Member · shared task access',
                ),
                if (owner) ...[
                  TextButton.icon(
                    onPressed: () => _showGroupDialog(
                      (_) => _MembersDialog(list: list, service: service),
                    ),
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Manage members'),
                  ),
                  TextButton.icon(
                    onPressed: () => _showGroupDialog(
                      (_) => _RenameGroupDialog(list: list, service: service),
                    ),
                    icon: const Icon(Icons.drive_file_rename_outline),
                    label: const Text('Rename group'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showGroupDialog(WidgetBuilder builder) async {
    final route = DialogRoute<void>(context: context, builder: builder);
    _groupDialog = route;
    await Navigator.of(context).push(route);
    if (_groupDialog == route) _groupDialog = null;
  }
}

String _actionError(Object error) => switch (error) {
  StateError(:final message) => message,
  FormatException(:final message) => message,
  _ => 'Could not complete the request. Try again.',
};

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
      if (mounted) setState(() => _message = _actionError(error));
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

class _RenameGroupDialog extends StatefulWidget {
  const _RenameGroupDialog({required this.list, required this.service});
  final CollaborativeList list;
  final CollaborationService service;
  @override
  State<_RenameGroupDialog> createState() => _RenameGroupDialogState();
}

class _RenameGroupDialogState extends State<_RenameGroupDialog> {
  late final _name = TextEditingController(text: widget.list.name);
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
      await widget.service.renameList(widget.list.id, _name.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = _actionError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Rename group'),
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
      FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
    ],
  );
}
