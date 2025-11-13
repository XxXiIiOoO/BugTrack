import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/bug.dart';
import '../service/user_cache.dart';

/// Карточка задачи для списков и канбана.
/// [onTap] — действие по нажатию.
/// [dense] — компактный режим (для канбана/узких колонок).
class BugCard extends StatelessWidget {
  final Bug bug;
  final VoidCallback? onTap;
  final bool dense;

  const BugCard({
    super.key,
    required this.bug,
    this.onTap,
    this.dense = false,
  });

  // === helpers ===

  static final _date = DateFormat('dd.MM.yyyy');

  String _fmtDate(DateTime? d) => d == null ? '—' : _date.format(d);

  bool get _isOverdue {
    final due = bug.estimatedCompletion;
    if (due == null) return false;
    final done = bug.status.toLowerCase().contains('done');
    return !done && due.isBefore(DateTime.now());
  }

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.amber;
      case 'low':
      default:
        return Colors.green;
    }
  }

  Color _statusColor(BuildContext ctx, String s) {
    final cs = Theme.of(ctx).colorScheme;
    final v = s.toLowerCase();
    if (v.contains('open')) return cs.primary;
    if (v.contains('in progress')) return cs.tertiary;
    if (v.contains('done')) return Colors.teal;
    return cs.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;

    final titleStyle = dense
        ? text.titleSmall?.copyWith(fontWeight: FontWeight.w600)
        : text.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final metaStyle = dense
        ? text.bodySmall?.copyWith(color: Theme.of(context).hintColor)
        : text.bodyMedium?.copyWith(color: Theme.of(context).hintColor);
    final rowStyle = dense ? text.bodySmall : text.bodyMedium;

    final statusColor = _statusColor(context, bug.status);
    final priorityColor = _priorityColor(bug.priority);
    final statusLabel = _localizedStatus(l10n, bug.status);
    final priorityLabel = _localizedPriority(l10n, bug.priority);
    final labels = bug.labels;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(dense ? 10 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок + статус
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _TitleAndMeta(
                      id: bug.id,
                      title: bug.title.isEmpty ? l10n.t('bug.untitled') : bug.title,
                      created: _fmtDate(bug.creationDate),
                      titleStyle: titleStyle,
                      metaStyle: metaStyle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Pill(text: statusLabel, color: statusColor, compact: dense),
                ],
              ),

              const SizedBox(height: 8),

              // Исполнитель (имя из кеша), приоритет, дедлайн
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _AssigneeName(uid: bug.assignedTo, style: rowStyle),
                  _IconText(
                    icon: Icons.flag_outlined,
                    text: priorityLabel,
                    iconColor: priorityColor,
                    style: rowStyle,
                  ),
                  _IconText(
                    icon: Icons.event_outlined,
                    text: _fmtDate(bug.estimatedCompletion),
                    iconColor: _isOverdue ? Colors.red : null,
                    style: rowStyle?.copyWith(
                      color: _isOverdue ? Colors.red : null,
                      fontWeight: _isOverdue ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),

              if (labels.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final l in labels.take(dense ? 4 : 8))
                      _Tag(text: l, color: cs.secondaryContainer),
                    if (!dense && labels.length > 8)
                      _Tag(
                          text: '+${labels.length - 8}',
                          color: cs.surfaceContainerHighest),
                  ],
                ),
              ],

              // (опц.) короткое описание
              if (!dense && bug.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  bug.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _localizedStatus(AppLocalizations l10n, String status) {
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

  String _localizedPriority(AppLocalizations l10n, String priority) {
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

// ====== мелкие компоненты ======

class _AssigneeName extends StatelessWidget {
  final String uid;
  final TextStyle? style;
  const _AssigneeName({required this.uid, this.style});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (uid.isEmpty) {
      return _IconText(
        icon: Icons.person_outline,
        text: l10n.t('home.unassigned'),
        style: style,
      );
    }
    // Сначала пробуем отдать значение из кеша синхронно (если уже было)
    final cached = UserCache.instance.peek(uid);
    return StreamBuilder<String>(
      stream: UserCache.instance.watchName(uid),
      initialData: cached,
      builder: (context, snap) {
        final defaultName = l10n.t('admin.noName');
        final name = (snap.data?.isNotEmpty == true)
            ? snap.data!
            : (cached?.isNotEmpty == true ? cached! : defaultName);
        return _IconText(icon: Icons.person_outline, text: name, style: style);
      },
    );
  }
}

class _TitleAndMeta extends StatelessWidget {
  final String id;
  final String title;
  final String created;
  final TextStyle? titleStyle;
  final TextStyle? metaStyle;

  const _TitleAndMeta({
    required this.id,
    required this.title,
    required this.created,
    required this.titleStyle,
    required this.metaStyle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final meta = <String>[];
    if (id.isNotEmpty) meta.add('#$id');
    meta.add(l10n.t('bug.metaCreated', params: {'date': created}));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(meta.join(' • '), style: metaStyle),
      ],
    );
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;
  final TextStyle? style;
  final Color? iconColor;

  const _IconText({
    required this.icon,
    required this.text,
    this.style,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = text.isEmpty ? '—' : text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 18, color: iconColor ?? Theme.of(context).iconTheme.color),
        const SizedBox(width: 6),
        Text(t, style: style),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final bool compact;

  const _Pill({
    required this.text,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(0.12);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
