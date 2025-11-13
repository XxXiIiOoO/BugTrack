// lib/screens/home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/bug.dart';
import '../models/bug_filter.dart';
import '../models/project.dart';
import '../models/role.dart';
import '../state/app_state.dart';
import '../service/report_service.dart';
import '../service/user_cache.dart';
import '../widgets/bug_card.dart';
import '../widgets/bug_filter_sheet.dart';
import '../widgets/main_drawer.dart';
import 'edit_bug_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.filter, this.action});

  final String? filter;
  final String? action;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final selected = <String>{};
  BugFilter _filter = BugFilter.empty;
  String _searchTerm = '';
  final ReportService _reportService = ReportService();
  List<Bug> _lastFilteredBugs = const [];
  String? _pendingAction;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _filter = _filterFromQuery(widget.filter);
    _searchTerm = '';
    _pendingAction = widget.action;
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      setState(() {
        _filter = _filterFromQuery(widget.filter);
        _searchTerm = '';
      });
    }
    if (oldWidget.action != widget.action) {
      _pendingAction = widget.action;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final project = appState.activeProject;
    final projectId = project?.id;
    final projectRole = appState.activeProjectRole ?? Role.tester;
    final currentUserId = appState.currentUser?.id;
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final hasSearch = _searchTerm.isNotEmpty;
    final hasFilterBadge = !_filter.isEmpty;

    if (projectId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('home.title'))),
        drawer: const MainDrawer(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.t('home.noProject')),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.go('/projects'),
                icon: const Icon(Icons.workspaces),
                label: Text(l10n.t('home.createProject')),
              ),
            ],
          ),
        ),
      );
    }

    final canCreateBug = can(projectRole, Permission.createBug);
    final canChangeAny = can(projectRole, Permission.changeStatusAny);
    final canChangeAssigned = can(projectRole, Permission.changeStatusAssigned) || canChangeAny;

    final selectionActions = <Widget>[];
    if (canChangeAny) {
      selectionActions.add(
        IconButton(
          tooltip: l10n.t('home.actions.bulkComplete'),
          icon: const Icon(Icons.done_all),
          onPressed: () => _bulkChangeStatus('Done'),
        ),
      );
    }
    if (currentUserId != null && canChangeAssigned) {
      selectionActions.add(
        IconButton(
          tooltip: l10n.t('home.actions.assignToMe'),
          icon: const Icon(Icons.person),
          onPressed: _bulkAssignToMe,
        ),
      );
    }
    if (projectRole == Role.admin) {
      selectionActions.addAll([
        IconButton(
          tooltip: l10n.t('home.actions.highPriority'),
          icon: const Icon(Icons.flag),
          onPressed: () => _bulkSetPriority('High'),
        ),
        IconButton(
          tooltip: l10n.t('home.actions.addLabel'),
          icon: const Icon(Icons.label),
          onPressed: () => _bulkAddLabel('important'),
        ),
        IconButton(
          tooltip: l10n.t('home.actions.assignMember'),
          icon: const Icon(Icons.group_add_outlined),
          onPressed: _bulkAssignToMember,
        ),
        IconButton(
          tooltip: l10n.t('home.actions.delete'),
          icon: const Icon(Icons.delete),
          onPressed: _bulkDelete,
        ),
      ]);
    }

    final defaultActions = <Widget>[
      IconButton(
        icon: Icon(Icons.search, color: hasSearch ? theme.colorScheme.primary : null),
        tooltip: l10n.t('home.search.title'),
        onPressed: _openSearchDialog,
      ),
      IconButton(
        icon: Icon(Icons.filter_alt, color: hasFilterBadge ? theme.colorScheme.primary : null),
        tooltip: l10n.t('home.filters.title'),
        onPressed: () => _openFilterSheet(currentUserId),
      ),
      PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'export_csv':
              _exportReport(_ReportFormat.csv);
              break;
            case 'export_pdf':
              _exportReport(_ReportFormat.pdf);
              break;
            case 'share_filter':
              _shareFilter();
              break;
            case 'filter_unassigned':
              setState(() {
                _filter = _filter.setUnassignedOnly(true);
              });
              break;
            case 'filter_overdue':
              setState(() {
                _filter = _filter.setOverdueOnly(true);
              });
              break;
            case 'filter_reset':
              _clearAllFilters();
              break;
          }
        },
        itemBuilder: (ctx) {
          final entries = <PopupMenuEntry<String>>[];
          if (projectRole == Role.admin) {
            entries.addAll([
              PopupMenuItem(
                value: 'filter_unassigned',
                child: Text(l10n.t('home.filters.quickUnassigned')),
              ),
              PopupMenuItem(
                value: 'filter_overdue',
                child: Text(l10n.t('home.filters.quickOverdue')),
              ),
              PopupMenuItem(
                value: 'filter_reset',
                child: Text(l10n.t('home.filters.quickReset')),
              ),
              const PopupMenuDivider(),
            ]);
          }
          entries.add(
            PopupMenuItem(
              value: 'share_filter',
              child: Text(l10n.t('home.filters.share')),
            ),
          );
          entries.add(const PopupMenuDivider());
          entries.addAll([
            PopupMenuItem(
              value: 'export_csv',
              enabled: !_isExporting,
              child: Text(l10n.t('drawer.exportCsv')),
            ),
            PopupMenuItem(
              value: 'export_pdf',
              enabled: !_isExporting,
              child: Text(l10n.t('drawer.exportPdf')),
            ),
          ]);
          return entries;
        },
      ),
    ];

    final appBarActions = selected.isEmpty
        ? defaultActions
        : selectionActions.isNotEmpty
            ? selectionActions
            : [
                IconButton(
                  tooltip: l10n.t('home.permissionDenied'),
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.t('home.permissionDenied'))),
                    );
                  },
                ),
              ];

    final query = _buildQuery(projectId, _filter, currentUserId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selected.isEmpty
              ? l10n.t('home.title')
              : l10n.t('home.selected', params: {'count': '${selected.length}'}),
        ),
        actions: appBarActions,
      ),
      drawer: const MainDrawer(),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final bugs = docs.map(Bug.fromDoc).toList();
          final filteredBugs = _applyClientFilters(bugs, currentUserId);
          final hasActiveFilters = !_filter.isEmpty || _searchTerm.isNotEmpty;
          _lastFilteredBugs = filteredBugs;
          _maybeHandlePendingAction();

          final resultIndicator = Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.t('home.results.count', params: {'count': '${filteredBugs.length}'}),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );

          if (filteredBugs.isEmpty) {
            return Column(
              children: [
                resultIndicator,
                if (hasActiveFilters) _ActiveFiltersBanner(
                  chips: _buildFilterChips(l10n),
                  onClearAll: _clearAllFilters,
                ),
                Expanded(
                  child: Center(
                    child: Text(l10n.t('home.noData')),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              resultIndicator,
              if (hasActiveFilters) _ActiveFiltersBanner(
                chips: _buildFilterChips(l10n),
                onClearAll: _clearAllFilters,
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: filteredBugs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final bug = filteredBugs[index];
                    final isSelected = selected.contains(bug.id);
                    return InkWell(
                      onLongPress: () => _toggle(bug.id),
                      onTap: () {
                        if (selected.isNotEmpty) {
                          _toggle(bug.id);
                        } else {
                          _openBugActions(bug, projectRole, currentUserId, projectId);
                        }
                      },
                      child: Container(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                            : null,
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggle(bug.id),
                            ),
                            Expanded(
                              child: BugCard(
                                bug: bug,
                                onTap: () => _openBugActions(bug, projectRole, currentUserId, projectId),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: canCreateBug
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/new'),
              icon: const Icon(Icons.add),
              label: Text(l10n.t('home.newBug')),
            )
          : null,
    );
  }

  void _toggle(String id) {
    setState(() {
      if (!selected.add(id)) {
        selected.remove(id);
      }
    });
  }

  BugFilter _filterFromQuery(String? preset) {
    switch (preset) {
      case 'mine':
        return BugFilter(assignedToMe: true);
      case 'high':
        return BugFilter(priorities: {'High'});
      case 'new':
        return BugFilter(recentOnly: true);
      case 'due':
        return BugFilter(overdueOnly: true);
      default:
        return BugFilter.empty;
    }
  }

  List<Widget> _buildFilterChips(AppLocalizations l10n) {
    final chips = <Widget>[];
    for (final status in _filter.statuses) {
      chips.add(
        InputChip(
          label: Text(_statusLabel(l10n, status)),
          onDeleted: () {
            setState(() {
              _filter = _filter.toggleStatus(status);
            });
          },
        ),
      );
    }
    for (final priority in _filter.priorities) {
      chips.add(
        InputChip(
          label: Text(_priorityLabel(l10n, priority)),
          onDeleted: () {
            setState(() {
              _filter = _filter.togglePriority(priority);
            });
          },
        ),
      );
    }
    if (_filter.assignedToMe) {
      chips.add(
        InputChip(
          label: Text(l10n.t('home.filters.assignedChip')),
          onDeleted: () {
            setState(() {
              _filter = _filter.setAssignedToMe(false);
            });
          },
        ),
      );
    }
    if (_filter.unassignedOnly) {
      chips.add(
        InputChip(
          label: Text(l10n.t('home.filters.unassignedChip')),
          onDeleted: () {
            setState(() {
              _filter = _filter.setUnassignedOnly(false);
            });
          },
        ),
      );
    }
    if (_filter.createdByMe) {
      chips.add(
        InputChip(
          label: Text(l10n.t('home.filters.createdChip')),
          onDeleted: () {
            setState(() {
              _filter = _filter.setCreatedByMe(false);
            });
          },
        ),
      );
    }
    if (_filter.overdueOnly) {
      chips.add(
        InputChip(
          label: Text(l10n.t('home.filters.overdueChip')),
          onDeleted: () {
            setState(() {
              _filter = _filter.setOverdueOnly(false);
            });
          },
        ),
      );
    }
    if (_filter.recentOnly) {
      chips.add(
        InputChip(
          label: Text(l10n.t('home.filters.recentChip')),
          onDeleted: () {
            setState(() {
              _filter = _filter.setRecentOnly(false);
            });
          },
        ),
      );
    }
    if (_searchTerm.isNotEmpty) {
      chips.add(
        InputChip(
          label: Text(l10n.t('home.search.label', params: {'query': _searchTerm})),
          onDeleted: () {
            setState(() {
              _searchTerm = '';
            });
          },
        ),
      );
    }
    return chips;
  }

  void _clearAllFilters() {
    if (_filter.isEmpty && _searchTerm.isEmpty) return;
    setState(() {
      _filter = BugFilter.empty;
      _searchTerm = '';
    });
  }

  Future<void> _openFilterSheet(String? currentUserId) async {
    final result = await showModalBottomSheet<BugFilter>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => BugFilterSheet(
        initial: _filter,
        l10n: context.l10n,
        canUseAssignedFilters: currentUserId != null && currentUserId.isNotEmpty,
        previewBugs: _lastFilteredBugs,
        onShareFilter: _shareFilter,
      ),
    );
    if (result != null) {
      setState(() {
        _filter = result;
      });
    }
  }

  Future<void> _exportReport(_ReportFormat format) async {
    if (_isExporting) return;
    if (_lastFilteredBugs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('home.export.empty'))),
      );
      return;
    }
    setState(() => _isExporting = true);
    final l10n = context.l10n;
    try {
      final file = switch (format) {
        _ReportFormat.csv => await _reportService.writeCsv(_lastFilteredBugs),
        _ReportFormat.pdf => await _reportService.writePdf(_lastFilteredBugs),
      };
      await _reportService.share(file);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            format == _ReportFormat.csv ? l10n.t('home.export.csvReady') : l10n.t('home.export.pdfReady'),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('home.export.error', params: {'error': '$e'}))),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _shareFilter() async {
    final l10n = context.l10n;
    final summary = _buildFilterSummary(l10n);
    await Share.share(summary);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('home.filters.shareSent'))),
      );
    }
  }

  String _buildFilterSummary(AppLocalizations l10n) {
    final lines = <String>[];
    if (_filter.statuses.isNotEmpty) {
      final statuses = _filter.statuses.map((s) => _statusLabel(l10n, s)).join(', ');
      lines.add('${l10n.t('home.filters.statusSection')}: $statuses');
    }
    if (_filter.priorities.isNotEmpty) {
      final priorities = _filter.priorities.map((p) => _priorityLabel(l10n, p)).join(', ');
      lines.add('${l10n.t('home.filters.prioritySection')}: $priorities');
    }
    if (_filter.assignedToMe) {
      lines.add(l10n.t('home.filters.assignedToMe'));
    }
    if (_filter.unassignedOnly) {
      lines.add(l10n.t('home.filters.unassignedOnly'));
    }
    if (_filter.createdByMe) {
      lines.add(l10n.t('home.filters.createdByMe'));
    }
    if (_filter.overdueOnly) {
      lines.add(l10n.t('home.filters.overdueOnly'));
    }
    if (_filter.recentOnly) {
      lines.add(l10n.t('home.filters.recentOnly'));
    }
    if (_searchTerm.isNotEmpty) {
      lines.add('${l10n.t('home.search.title')}: "$_searchTerm"');
    }
    if (lines.isEmpty) {
      lines.add(l10n.t('home.filters.none'));
    }
    lines.add(l10n.t('home.results.count', params: {'count': '${_lastFilteredBugs.length}'}));
    return '${l10n.t('home.filters.shareTitle')}\n${lines.join('\n')}';
  }

  void _maybeHandlePendingAction() {
    final action = _pendingAction;
    if (action == null) return;
    _pendingAction = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (action) {
        case 'export_csv':
          _exportReport(_ReportFormat.csv);
          break;
        case 'export_pdf':
          _exportReport(_ReportFormat.pdf);
          break;
        case 'share_filter':
          _shareFilter();
          break;
      }
      context.go('/home');
    });
  }


  Future<void> _openSearchDialog() async {
    final controller = TextEditingController(text: _searchTerm);
    final l10n = context.l10n;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('home.search.title')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: l10n.t('home.search.hint')),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.t('confirm.cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: Text(l10n.t('home.search.clear'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.t('home.filters.apply')),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        _searchTerm = result;
      });
    }
  }

  Query<Map<String, dynamic>> _buildQuery(String projectId, BugFilter filter, String? currentUserId) {
    var query = _projectBugs(projectId).orderBy('creationDate', descending: true);

    if (filter.statuses.isNotEmpty) {
      final statuses = filter.statuses.toList();
      if (statuses.length == 1) {
        query = query.where('status', isEqualTo: statuses.first);
      } else {
        query = query.where('status', whereIn: statuses);
      }
    }

    if (filter.priorities.isNotEmpty) {
      final priorities = filter.priorities.toList();
      if (priorities.length == 1) {
        query = query.where('priority', isEqualTo: priorities.first);
      } else {
        query = query.where('priority', whereIn: priorities);
      }
    }

    if (filter.assignedToMe && currentUserId != null && currentUserId.isNotEmpty) {
      query = query.where('assignedTo', isEqualTo: currentUserId);
    } else if (filter.unassignedOnly) {
      query = query.where('assignedTo', isEqualTo: '');
    }

    if (filter.createdByMe && currentUserId != null && currentUserId.isNotEmpty) {
      query = query.where('createdBy', isEqualTo: currentUserId);
    }

    return query;
  }

  CollectionReference<Map<String, dynamic>> _projectBugs(String projectId) {
    return FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('bugs');
  }

  List<Bug> _applyClientFilters(List<Bug> bugs, String? currentUserId) {
    final now = DateTime.now();
    final term = _searchTerm.toLowerCase();
    return bugs.where((bug) {
      if (_filter.assignedToMe && currentUserId != null && bug.assignedTo != currentUserId) {
        return false;
      }
      if (_filter.unassignedOnly && bug.assignedTo.isNotEmpty) {
        return false;
      }
      if (_filter.createdByMe && currentUserId != null && bug.createdBy != currentUserId) {
        return false;
      }
      if (_filter.statuses.isNotEmpty && !_filter.statuses.contains(bug.status)) {
        return false;
      }
      if (_filter.priorities.isNotEmpty && !_filter.priorities.contains(bug.priority)) {
        return false;
      }
      if (_filter.overdueOnly) {
        final due = bug.estimatedCompletion;
        final isDone = bug.status.toLowerCase() == 'done';
        if (due == null || !due.isBefore(now) || isDone) {
          return false;
        }
      }
      if (_filter.recentOnly) {
        final since = now.subtract(const Duration(hours: 24));
        if (!bug.creationDate.isAfter(since)) {
          return false;
        }
      }
      if (term.isNotEmpty) {
        final haystack = [
          bug.title,
          bug.description,
          bug.priority,
          bug.status,
          bug.id,
          ...bug.labels,
        ].join(' ').toLowerCase();
        if (!haystack.contains(term)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _updateBugStatus(Bug bug, String newStatus) async {
    final projectId = _requireProjectId();
    if (projectId == null) return;
    final appState = context.read<AppState>();
    final role = appState.activeProjectRole ?? Role.tester;
    final currentUserId = appState.currentUser?.id;
    final canAny = can(role, Permission.changeStatusAny);
    final canAssigned = can(role, Permission.changeStatusAssigned);
    final isMine = currentUserId != null && bug.assignedTo == currentUserId;
    if (!canAny && !(canAssigned && isMine)) {
      _showNoPermission();
      return;
    }
    try {
      await _projectBugs(projectId).doc(bug.id).update({
        'status': newStatus,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      if (mounted) {
        final label = _statusLabel(context.l10n, newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('home.statusUpdated', params: {'status': label}))),
        );
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _assignBugToCurrentUser(Bug bug) async {
    final projectId = _requireProjectId();
    if (projectId == null) return;
    final appState = context.read<AppState>();
    final role = appState.activeProjectRole ?? Role.tester;
    final currentUser = appState.currentUser;
    if (currentUser == null) {
      _showNoPermission();
      return;
    }
    final canAny = can(role, Permission.changeStatusAny);
    final canAssigned = can(role, Permission.changeStatusAssigned);
    if (!canAny && !canAssigned) {
      _showNoPermission();
      return;
    }
    try {
      await _projectBugs(projectId).doc(bug.id).update({
        'assignedTo': currentUser.id,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('home.taskAssigned'))),
        );
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _updateBugPriority(Bug bug, String priority) async {
    final projectId = _requireProjectId();
    if (projectId == null) return;
    if (!_isAdmin()) return;
    try {
      await _projectBugs(projectId).doc(bug.id).update({
        'priority': priority,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      if (mounted) {
        final label = _priorityLabel(context.l10n, priority);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('home.priorityUpdated', params: {'priority': label}))),
        );
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteBugSingle(Bug bug) async {
    final projectId = _requireProjectId();
    if (projectId == null) return;
    if (!_isAdmin()) return;
    try {
      await _projectBugs(projectId).doc(bug.id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('home.taskDeleted'))),
        );
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _bulkChangeStatus(String newStatus) async {
    final projectId = _requireProjectId();
    if (projectId == null) return;
    if (!_ensureAnyPermission(const [Permission.changeStatusAny])) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in selected) {
      final ref = _projectBugs(projectId).doc(id);
      batch.update(ref, {'status': newStatus, 'updatedAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
    setState(selected.clear);
  }

  Future<void> _bulkAssignToMe() async {
    final projectId = _requireProjectId();
    if (projectId == null) return;
    if (!_ensureAnyPermission(const [Permission.changeStatusAssigned, Permission.changeStatusAny])) return;
    final uid = context.read<AppState>().currentUser?.id;
    if (uid == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in selected) {
      final ref = _projectBugs(projectId).doc(id);
      batch.update(ref, {'assignedTo': uid, 'updatedAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
    setState(selected.clear);
  }

  Future<void> _bulkAssignToMember() async {
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('home.actions.selectRequired'))),
      );
      return;
    }
    if (!_isAdmin()) return;
    final appState = context.read<AppState>();
    final Project? project = appState.activeProject;
    if (project == null) return;
    final l10n = context.l10n;
    final userCache = UserCache.instance;
    final memberOptions = <_MemberOption>[];
    for (final memberId in project.memberIds) {
      final name = await userCache.getName(memberId);
      memberOptions.add(_MemberOption(id: memberId, label: name));
    }
    if (!mounted) return;
    final selectedMemberId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.t('home.actions.assignMember')),
        children: [
          for (final option in memberOptions)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, option.id),
              child: Text(option.label),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('confirm.cancel')),
          ),
        ],
      ),
    );
    if (selectedMemberId == null || selectedMemberId.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final bugId in selected) {
      final ref = _projectBugs(project.id).doc(bugId);
      batch.update(ref, {'assignedTo': selectedMemberId, 'updatedAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
    if (!mounted) return;
    setState(selected.clear);
    final memberName = memberOptions.firstWhere(
      (element) => element.id == selectedMemberId,
      orElse: () => _MemberOption(id: selectedMemberId, label: l10n.t('home.filters.assignedToMe')),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.t('home.actions.assignedToMember', params: {'name': memberName.label}))),
    );
  }

  Future<void> _bulkSetPriority(String priority) async {
    final projectId = _requireProjectId();
    if (projectId == null) return;
    if (!_isAdmin()) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in selected) {
      final ref = _projectBugs(projectId).doc(id);
      batch.update(ref, {'priority': priority, 'updatedAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
    setState(selected.clear);
  }

  Future<void> _bulkAddLabel(String label) async {
    final projectId = _requireProjectId();
    if (projectId == null) return;
    if (!_isAdmin()) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in selected) {
      final ref = _projectBugs(projectId).doc(id);
      batch.update(ref, {
        'labels': FieldValue.arrayUnion([label]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    setState(selected.clear);
  }

  Future<void> _bulkDelete() async {
    final projectId = _requireProjectId();
    if (projectId == null) return;
    if (!_isAdmin()) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in selected) {
      final ref = _projectBugs(projectId).doc(id);
      batch.delete(ref);
    }
    await batch.commit();
    setState(selected.clear);
  }

  String? _requireProjectId() {
    final projectId = context.read<AppState>().activeProjectId;
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('home.noProject'))),
      );
    }
    return projectId;
  }

  bool _isAdmin() {
    final role = context.read<AppState>().activeProjectRole ?? Role.tester;
    final allowed = role == Role.admin;
    if (!allowed) {
      _showNoPermission();
    }
    return allowed;
  }

  bool _ensureAnyPermission(List<Permission> permissions) {
    final role = context.read<AppState>().activeProjectRole ?? Role.tester;
    final allowed = permissions.any((perm) => can(role, perm));
    if (!allowed) {
      _showNoPermission();
    }
    return allowed;
  }

  void _showNoPermission() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.t('home.permissionAction'))),
    );
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.t('common.error', params: {'error': '$error'}))),
    );
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return l10n.t('status.open');
      case 'in progress':
        return l10n.t('status.inProgress');
      case 'done':
        return l10n.t('status.done');
      default:
        return status;
    }
  }

  String _priorityLabel(AppLocalizations l10n, String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return l10n.t('newBug.priority.low');
      case 'medium':
        return l10n.t('newBug.priority.medium');
      case 'high':
        return l10n.t('newBug.priority.high');
      default:
        return priority;
    }
  }

  Future<void> _openEditBug(Bug bug) async {
    final updated = await Navigator.of(context).push<Bug>(
      MaterialPageRoute(builder: (_) => EditBugScreen(bug: bug)),
    );
    if (updated != null && mounted) {
      setState(() {});
    }
  }

  void _openBugActions(Bug bug, Role role, String? currentUserId, String projectId) {
    final parentContext = context;
    final l10n = parentContext.l10n;
    final canChangeAny = can(role, Permission.changeStatusAny);
    final canChangeAssigned = can(role, Permission.changeStatusAssigned);
    final isAssignedToMe = currentUserId != null && bug.assignedTo == currentUserId;
    final canEditAny = can(role, Permission.editAnyBug);
    final canEdit = canEditAny || (can(role, Permission.editAssignedBug) && isAssignedToMe);
    final canDelete = role == Role.admin;

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final statusOptions = [
          {'value': 'Open', 'label': l10n.t('status.open')},
          {'value': 'In Progress', 'label': l10n.t('status.inProgress')},
          {'value': 'Done', 'label': l10n.t('status.done')},
        ];
        final priorityOptions = [
          {'value': 'Low', 'label': l10n.t('newBug.priority.low')},
          {'value': 'Medium', 'label': l10n.t('newBug.priority.medium')},
          {'value': 'High', 'label': l10n.t('newBug.priority.high')},
        ];

        final tiles = <Widget>[
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(l10n.t('home.openDetails')),
            onTap: () {
              Navigator.pop(ctx);
              parentContext.push('/bug/${bug.id}?project=$projectId');
            },
          ),
        ];

        if (canEdit) {
          tiles.add(
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.t('home.actions.edit')),
              onTap: () {
                Navigator.pop(ctx);
                _openEditBug(bug);
              },
            ),
          );
        }

        if (canChangeAny || (canChangeAssigned && isAssignedToMe)) {
          tiles.add(const Divider());
          tiles.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(l10n.t('home.changeStatus'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
          tiles.addAll(
            statusOptions.map(
              (option) => ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(option['label']!),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateBugStatus(bug, option['value']!);
                },
              ),
            ),
          );
        }

        if ((canChangeAssigned || canChangeAny) && currentUserId != null && bug.assignedTo != currentUserId) {
          tiles.add(
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(l10n.t('home.actions.assignToMe')),
              onTap: () {
                Navigator.pop(ctx);
                _assignBugToCurrentUser(bug);
              },
            ),
          );
        }

        if (canDelete) {
          tiles.add(const Divider());
          tiles.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(l10n.t('home.changePriority'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
          tiles.addAll(
            priorityOptions.map(
              (option) => ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(option['label']!),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateBugPriority(bug, option['value']!);
                },
              ),
            ),
          );
          tiles.add(
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.t('home.actions.delete')),
              textColor: Theme.of(ctx).colorScheme.error,
              iconColor: Theme.of(ctx).colorScheme.error,
              onTap: () {
                Navigator.pop(ctx);
                _deleteBugSingle(bug);
              },
            ),
          );
        }

        tiles.add(
          ListTile(
            leading: const Icon(Icons.close),
            title: Text(l10n.t('confirm.cancel')),
            onTap: () => Navigator.pop(ctx),
          ),
        );

        return SafeArea(child: Wrap(children: tiles));
      },
    );
  }
}

enum _ReportFormat {
  csv,
  pdf,
}

class _ActiveFiltersBanner extends StatelessWidget {
  const _ActiveFiltersBanner({required this.chips, required this.onClearAll});

  final List<Widget> chips;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips,
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onClearAll,
            icon: const Icon(Icons.clear),
            label: Text(l10n.t('home.filters.clearInline')),
          ),
        ],
      ),
    );
  }
}

class _MemberOption {
  _MemberOption({required this.id, required this.label});

  final String id;
  final String label;
}
