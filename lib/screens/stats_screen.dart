import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/bug.dart';
import '../service/report_service.dart';
import '../state/app_state.dart';
import '../widgets/main_drawer.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final ReportService _reportService = ReportService();
  _StatsPeriod _period = _StatsPeriod.last6Months;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appState = context.watch<AppState>();
    final project = appState.activeProject;
    final projectId = project?.id;

    if (projectId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('stats.title'))),
        drawer: const MainDrawer(),
        body: Center(child: Text(l10n.t('home.noProject'))),
      );
    }

    final projectNameRaw = project?.name ?? '';
    final projectName = projectNameRaw.isEmpty ? l10n.t('projects.untitled') : projectNameRaw;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('stats.title'))),
      drawer: const MainDrawer(),
      body: FutureBuilder<List<Bug>>(
        future: _load(projectId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.t('common.error', params: {'error': '${snapshot.error}'})));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bugs = snapshot.data!;
          if (bugs.isEmpty) {
            return Center(child: Text(l10n.t('stats.noData')));
          }

          final filteredBugs = _filterByPeriod(bugs);
          final byStatus = _countBy(filteredBugs, (b) => b.status, ['Open', 'In Progress', 'Done']);
          final byPriority = _countBy(filteredBugs, (b) => b.priority, ['Low', 'Medium', 'High']);
          final byMonth = _countByMonth(filteredBugs);
          final periodLabel = _periodLabel(l10n, _period);
          final filteredLabel = l10n.t('stats.filteredCount', params: {
            'period': periodLabel,
            'count': '${filteredBugs.length}',
          });
          final totalSummary = l10n.t('stats.total', params: {'count': '${filteredBugs.length}'});

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.t('stats.period.title'), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<_StatsPeriod>(
                        value: _period,
                        items: _StatsPeriod.values
                            .map(
                              (period) => DropdownMenuItem(
                                value: period,
                                child: Text(_periodLabel(l10n, period)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _period = value);
                          }
                        },
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      Text(filteredLabel),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _exporting || filteredBugs.isEmpty
                              ? null
                              : () => _exportStats(
                                    projectName: projectName,
                                    periodLabel: periodLabel,
                                    totalSummary: totalSummary,
                                    statusCounts: byStatus,
                                    priorityCounts: byPriority,
                                    monthlyCounts: byMonth,
                                    l10n: l10n,
                                  ),
                          icon: _exporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.picture_as_pdf),
                          label: Text(l10n.t('stats.exportPdf')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (filteredBugs.isEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.t('stats.noData')),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                _Card(title: l10n.t('stats.statuses'), child: _Pie(byStatus, l10n)),
                const SizedBox(height: 16),
                _Card(title: l10n.t('stats.priorities'), child: _Bars(byPriority, l10n)),
                const SizedBox(height: 16),
                _Card(
                  title: '${l10n.t('stats.byMonth')} (${periodLabel.toLowerCase()})',
                  child: _Line(byMonth, l10n),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportStats({
    required String projectName,
    required String periodLabel,
    required String totalSummary,
    required Map<String, int> statusCounts,
    required Map<String, int> priorityCounts,
    required Map<String, int> monthlyCounts,
    required AppLocalizations l10n,
  }) async {
    setState(() => _exporting = true);
    try {
      final file = await _reportService.writeStatsPdf(
        title: l10n.t('stats.title'),
        projectName: projectName,
        periodLabel: '${l10n.t('stats.period.title')}: $periodLabel',
        totalSummary: totalSummary,
        statusCounts: statusCounts,
        priorityCounts: priorityCounts,
        monthlyCounts: monthlyCounts,
        statusesSectionTitle: l10n.t('stats.statuses'),
        prioritiesSectionTitle: l10n.t('stats.priorities'),
        monthsSectionTitle: l10n.t('stats.byMonth'),
        keyColumnTitle: l10n.t('stats.column.metric'),
        valueColumnTitle: l10n.t('stats.column.value'),
      );
      await _reportService.share(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('stats.exportReady'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('stats.exportError', params: {'error': '$e'}))),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<List<Bug>> _load(String projectId) async {
    final snap = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('bugs')
        .get();
    return snap.docs.map((d) => Bug.fromDoc(d)).toList();
  }

  Map<String, int> _countBy(
    List<Bug> bugs,
    String Function(Bug) key,
    List<String> order,
  ) {
    final map = <String, int>{};
    for (final bug in bugs) {
      map.update(key(bug), (value) => value + 1, ifAbsent: () => 1);
    }
    final result = <String, int>{};
    for (final k in order) {
      result[k] = map[k] ?? 0;
    }
    for (final entry in map.entries) {
      result.putIfAbsent(entry.key, () => entry.value);
    }
    return result;
  }

  Map<String, int> _countByMonth(List<Bug> bugs) {
    if (bugs.isEmpty) return {};
    final monthsSpan = _period.months;
    final now = DateTime.now();
    final labels = <String>[];

    if (monthsSpan == null) {
      final earliest = bugs
          .map((b) => DateTime(b.creationDate.year, b.creationDate.month, 1))
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final end = DateTime(now.year, now.month, 1);
      final totalMonths = _monthsBetween(earliest, end) + 1;
      for (int i = 0; i < totalMonths; i++) {
        final date = DateTime(earliest.year, earliest.month + i, 1);
        labels.add(_monthKey(date));
      }
    } else {
      for (int i = 0; i < monthsSpan; i++) {
        final date = DateTime(now.year, now.month - (monthsSpan - 1 - i), 1);
        labels.add(_monthKey(date));
      }
    }

    final map = {for (final label in labels) label: 0};
    for (final bug in bugs) {
      final label = _monthKey(DateTime(bug.creationDate.year, bug.creationDate.month, 1));
      if (map.containsKey(label)) {
        map[label] = (map[label] ?? 0) + 1;
      }
    }
    return map;
  }

  int _monthsBetween(DateTime start, DateTime end) {
    return (end.year - start.year) * 12 + end.month - start.month;
  }

  List<Bug> _filterByPeriod(List<Bug> bugs) {
    final monthsSpan = _period.months;
    if (monthsSpan == null) return bugs;
    final now = DateTime.now();
    final since = DateTime(now.year, now.month - monthsSpan + 1, 1);
    return bugs.where((b) => !b.creationDate.isBefore(since)).toList();
  }

  String _monthKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}';

  String _periodLabel(AppLocalizations l10n, _StatsPeriod period) {
    switch (period) {
      case _StatsPeriod.last3Months:
        return l10n.t('stats.period.last3');
      case _StatsPeriod.last6Months:
        return l10n.t('stats.period.last6');
      case _StatsPeriod.last12Months:
        return l10n.t('stats.period.last12');
      case _StatsPeriod.all:
        return l10n.t('stats.period.all');
    }
  }
}

enum _StatsPeriod {
  last3Months(3),
  last6Months(6),
  last12Months(12),
  all(null);

  const _StatsPeriod(this.months);
  final int? months;
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(height: 220, child: child),
          ],
        ),
      ),
    );
  }
}

class _Pie extends StatelessWidget {
  final Map<String, int> data;
  final AppLocalizations l10n;
  const _Pie(this.data, this.l10n);
  @override
  Widget build(BuildContext context) {
    final total = (data.values.isEmpty) ? 1 : data.values.reduce((a, b) => a + b);
    final items = data.entries.toList();
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: [
                for (int i = 0; i < items.length; i++)
                  PieChartSectionData(
                    value: items[i].value.toDouble(),
                    title: '${(items[i].value * 100 / total).toStringAsFixed(0)}%',
                    radius: 70,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${_localizedKey(e.key)}: ${e.value}'),
              )
          ],
        )
      ],
    );
  }

  String _localizedKey(String key) {
    switch (key.toLowerCase()) {
      case 'open':
        return l10n.t('status.open');
      case 'in progress':
        return l10n.t('status.inProgress');
      case 'done':
        return l10n.t('status.done');
      default:
        return key;
    }
  }
}

class _Bars extends StatelessWidget {
  final Map<String, int> data;
  final AppLocalizations l10n;
  const _Bars(this.data, this.l10n);
  @override
  Widget build(BuildContext context) {
    final items = data.entries.toList();
    return BarChart(
      BarChartData(
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final index = v.toInt();
                if (index < 0 || index >= items.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _localizedPriority(items[index].key),
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < items.length; i++)
            BarChartGroupData(x: i, barRods: [BarChartRodData(toY: items[i].value.toDouble())])
        ],
      ),
    );
  }

  String _localizedPriority(String key) {
    switch (key.toLowerCase()) {
      case 'low':
        return l10n.t('newBug.priority.low');
      case 'medium':
        return l10n.t('newBug.priority.medium');
      case 'high':
        return l10n.t('newBug.priority.high');
      default:
        return key;
    }
  }
}

class _Line extends StatelessWidget {
  final Map<String, int> data;
  final AppLocalizations l10n;
  const _Line(this.data, this.l10n);
  @override
  Widget build(BuildContext context) {
    final items = data.entries.toList();
    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= items.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_monthLabel(items[i].key)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            barWidth: 3,
            spots: [
              for (int i = 0; i < items.length; i++) FlSpot(i.toDouble(), items[i].value.toDouble())
            ],
          )
        ],
      ),
    );
  }

  String _monthLabel(String iso) {
    final parts = iso.split('-');
    if (parts.length == 2) {
      final month = int.tryParse(parts[1]) ?? 0;
      final DateTime date = DateTime(0, month == 0 ? 1 : month);
      return DateFormat.MMM(l10n.locale.languageCode).format(date);
    }
    return iso;
  }
}
