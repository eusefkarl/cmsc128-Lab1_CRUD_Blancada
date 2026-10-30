import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/collaborative_list.dart';
import '../services/collaboration_service.dart';
import '../services/task_repository.dart';
import 'task_home_page.dart';

/// A fresh keyed task screen owns each scope's stream, forms and Undo timers.
class CollaborativeWorkspace extends StatefulWidget {
  const CollaborativeWorkspace({super.key, this.service});
  final CollaborationService? service;

  @override
  State<CollaborativeWorkspace> createState() => _CollaborativeWorkspaceState();
}

class _CollaborativeWorkspaceState extends State<CollaborativeWorkspace> {
  late CollaborationService _service;
  StreamSubscription<List<CollaborativeList>>? _subscription;
  List<CollaborativeList> _lists = [];
  String? _selectedId;
  late TaskRepository _repository;
  String? _error;
  bool _initializing = true;
  int _generation = 0;
  DialogRoute<void>? _memberDialog;

  void _closeMemberDialog() {
    final route = _memberDialog;
    _memberDialog = null;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(CollaborativeWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) _start();
  }

  void _start() {
    _closeMemberDialog();
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
        if (revoked) {
          _notify('Access to that list ended. Personal is now active.');
        }
      },
      onError: (Object error) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _lists = [];
          _setScope(null);
          _error = 'Collaborative lists are unavailable. Retry to reconnect.';
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
    _closeMemberDialog();
    ++_generation;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _notify(String message) {
    // TaskHomePage owns the scaffold below this context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    });
  }

  void _setScope(String? id) {
    _closeMemberDialog();
    _selectedId = id;
    _repository = _service.tasksFor(id);
  }

  void _accessLost() {
    if (!mounted || _selectedId == null) return;
    setState(() => _setScope(null));
    _notify('Access to that list ended. Personal is now active.');
  }

  @override
  Widget build(BuildContext context) {
    final selected = _lists.where((list) => list.id == _selectedId).firstOrNull;
    final owner = selected?.ownerId == _service.uid;
    return TaskHomePage(
      key: ValueKey(
        '${_service.uid}:${_selectedId ?? 'personal'}:$_generation',
      ),
      repository: _repository,
      listName: selected?.name ?? 'Personal',
      onAccessLost: _selectedId == null ? null : _accessLost,
      listControls: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedId),
              initialValue: _selectedId ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Active list'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Personal')),
                ..._lists.map(
                  (list) => DropdownMenuItem(
                    value: list.id,
                    child: Text(
                      '${list.name} · ${list.ownerId == _service.uid ? 'Owned' : 'Joined'}'
                      '${_lists.where((other) => other.name == list.name).length > 1 ? ' · ${list.id.substring(0, list.id.length < 8 ? list.id.length : 8)}' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (id) =>
                  setState(() => _setScope(id == '' ? null : id)),
            ),
            if (_initializing)
              const LinearProgressIndicator(
                semanticsLabel: 'Preparing your group',
              ),
            if (_error != null)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(_error!),
                  TextButton(
                    onPressed: () => setState(_start),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            if (selected != null)
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    owner
                        ? 'Owner · ${selected.memberIds.length}/20 members'
                        : 'Member · shared task access',
                  ),
                  if (owner)
                    TextButton.icon(
                      onPressed: () => _showMemberDialog(selected),
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Add member'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMemberDialog(CollaborativeList list) async {
    final service = _service;
    final route = DialogRoute<void>(
      context: context,
      builder: (_) => _AddMemberDialog(
        listName: list.name,
        service: service,
        listId: list.id,
      ),
    );
    _memberDialog = route;
    await Navigator.of(context).push(route);
    if (_memberDialog == route) _memberDialog = null;
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog({
    required this.listName,
    required this.service,
    required this.listId,
  });
  final String listName;
  final String listId;
  final CollaborationService service;
  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final message = await action();
      if (mounted) setState(() => _message = message);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(
          () => _message =
              error.message ?? 'Could not add this member. Try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not complete the request. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Add member to ${widget.listName}'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Use the email of a registered account. Members can create, edit and delete tasks in this list.',
              ),
              if (!widget.service.emailVerified) ...[
                const SizedBox(height: 12),
                const Text('Verify your own email before adding members.'),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _perform(() async {
                          await widget.service.sendVerification();
                          return 'Verification email sent. Open its link, then check verification.';
                        }),
                  child: const Text('Send verification email'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _perform(() async {
                          return await widget.service.refreshVerification()
                              ? 'Email verified. You can now add a member.'
                              : 'Email is not verified yet. Open the emailed link first.';
                        }),
                  child: const Text('Check verification'),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Registered email',
                ),
                validator: (value) =>
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter a valid email address.',
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_message!),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton(
        onPressed: _busy || !widget.service.emailVerified
            ? null
            : () {
                if (!_form.currentState!.validate()) return;
                _perform(() async {
                  final result = await widget.service.addMember(
                    widget.listId,
                    _email.text,
                  );
                  return result == 'already-member'
                      ? 'This account is already a member.'
                      : 'Member added.';
                });
              },
        child: const Text('Add member'),
      ),
    ],
  );
}
