import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/bug.dart';
import '../models/bug_filter.dart';

class BugFilterSheet extends StatefulWidget {
  BugFilterSheet({
    super.key,
    required this.initial,
    required this.l10n,
    this.canUseAssignedFilters = true,
    this.previewBugs = const [],
    this.onShareFilter,
  });

  final BugFilter initial;
  final AppLocalizations l10n;
  final bool canUseAssignedFilters;
  final List<Bug> previewBugs;
  final VoidCallback? onShareFilter;

  @override
  State<BugFilterSheet> createState() => _BugFilterSheetState();
}

class _BugFilterSheetState extends State<BugFilterSheet> {
  static const List<String> _statuses = ['Open', 'In Progress', 'Done'];
  static const List<String> _priorities = ['Low', 'Medium', 'High'];

  late BugFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final theme = Theme.of(context);
    final hasFilters = !_filter.isEmpty;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.t('home.filters.title'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: hasFilters
                          ? () {
                              setState(() => _filter = _filter.clear());
                            }
                          : null,
                      child: Text(l10n.t('home.filters.clearInline')),
                    ),
                  ],
                ),
              ),
              if (widget.previewBugs.isNotEmpty || widget.onShareFilter != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.previewBugs.isEmpty
                                      ? l10n.t('home.filters.previewEmpty')
                                      : l10n.t(
                                          'home.filters.previewTitle',
                                          params: {'count': '${widget.previewBugs.length}'},
                                        ),
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              if (widget.onShareFilter != null)
                                TextButton.icon(
                                  onPressed: widget.onShareFilter,
                                  icon: const Icon(Icons.share),
                                  label: Text(l10n.t('home.filters.share')),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (widget.previewBugs.isEmpty)
                            Text(
                              l10n.t('home.filters.previewEmptyHint'),
                              style: theme.textTheme.bodySmall,
                            )
                          else ...[
                            for (final bug in widget.previewBugs.take(3))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.bug_report, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            bug.title.isEmpty
                                                ? l10n.t('bug.untitled')
                                                : bug.title,
                                            style: theme.textTheme.bodyMedium,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (bug.labels.isNotEmpty)
                                            Text(
                                              bug.labels.join(', '),
                                              style: theme.textTheme.bodySmall,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (widget.previewBugs.length > 3)
                              Text(
                                l10n.t(
                                  'home.filters.previewMore',
                                  params: {
                                    'count': '${widget.previewBugs.length - 3}',
                                  },
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(text: l10n.t('home.filters.statusSection')),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final status in _statuses)
                            FilterChip(
                              label: Text(_statusLabel(l10n, status)),
                              selected: _filter.statuses.contains(status),
                              onSelected: (value) {
                                setState(() {
                                  _filter = _filter.toggleStatus(status);
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SectionTitle(text: l10n.t('home.filters.prioritySection')),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final priority in _priorities)
                            FilterChip(
                              label: Text(_priorityLabel(l10n, priority)),
                              selected: _filter.priorities.contains(priority),
                              onSelected: (value) {
                                setState(() {
                                  _filter = _filter.togglePriority(priority);
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (widget.canUseAssignedFilters) ...[
                        SwitchListTile(
                          value: _filter.assignedToMe,
                          onChanged: (value) {
                            setState(() {
                              _filter = _filter.setAssignedToMe(value);
                            });
                          },
                          title: Text(l10n.t('home.filters.assignedToMe')),
                          subtitle: Text(l10n.t('home.filters.assignedToMeHint')),
                        ),
                      ],
                      SwitchListTile(
                        value: _filter.unassignedOnly,
                        onChanged: (value) {
                          setState(() {
                            _filter = _filter.setUnassignedOnly(value);
                          });
                        },
                        title: Text(l10n.t('home.filters.unassignedOnly')),
                        subtitle: Text(l10n.t('home.filters.unassignedOnlyHint')),
                      ),
                      if (widget.canUseAssignedFilters)
                        SwitchListTile(
                          value: _filter.createdByMe,
                          onChanged: (value) {
                            setState(() {
                              _filter = _filter.setCreatedByMe(value);
                            });
                          },
                          title: Text(l10n.t('home.filters.createdByMe')),
                        ),
                      SwitchListTile(
                        value: _filter.recentOnly,
                        onChanged: (value) {
                          setState(() {
                            _filter = _filter.setRecentOnly(value);
                          });
                        },
                        title: Text(l10n.t('home.filters.recentOnly')),
                        subtitle: Text(l10n.t('home.filters.recentHint')),
                      ),
                      SwitchListTile(
                        value: _filter.overdueOnly,
                        onChanged: (value) {
                          setState(() {
                            _filter = _filter.setOverdueOnly(value);
                          });
                        },
                        title: Text(l10n.t('home.filters.overdueOnly')),
                        subtitle: Text(l10n.t('home.filters.overdueHint')),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.t('confirm.cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, _filter),
                        child: Text(l10n.t('home.filters.apply')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
