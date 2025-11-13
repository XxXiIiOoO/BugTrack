// lib/screens/kanban_screen.dart
import 'package:flutter/material.dart';
import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';

import '../models/bug.dart';
import '../widgets/bug_card.dart';

typedef OnMoveBug = Future<void> Function({
required String bugId,
required String fromStatus,
required String toStatus,
});

typedef OnReorderColumns = Future<void> Function(
    int oldListIndex,
    int newListIndex,
    );

class KanbanScreen extends StatefulWidget {
  /// Колонки: статус -> список задач
  final Map<String, List<Bug>> columns;

  /// Коллбек сохранения перемещения задачи между колонками (обнови Firestore)
  final OnMoveBug onMoveBug;

  /// (опц.) коллбек сохранения перестановки самих колонок (если нужно)
  final OnReorderColumns? onReorderColumns;

  const KanbanScreen({
    super.key,
    required this.columns,
    required this.onMoveBug,
    this.onReorderColumns,
  });

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  late List<String> _statuses; // порядок колонок

  @override
  void initState() {
    super.initState();
    _statuses = widget.columns.keys.toList(growable: true);
  }

  @override
  void didUpdateWidget(covariant KanbanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если набор статусов поменялся — синхронизируем порядок
    final newKeys = widget.columns.keys.toList();
    if (newKeys.toSet() != _statuses.toSet()) {
      _statuses = newKeys;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: DragAndDropLists(
          // Список колонок
          children: [
            for (final status in _statuses)
              DragAndDropList(
                header: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                children: [
                  for (final bug in widget.columns[status] ?? const <Bug>[])
                    DragAndDropItem(
                      child: SizedBox(
                        width: 300,
                        child: BugCard(bug: bug, dense: true),
                      ),
                    ),
                ],
              ),
          ],

          // === перетаскивание задач между колонками ===
          onItemReorder: (oldItemIndex, oldListIndex, newItemIndex, newListIndex) async {
            final fromStatus = _statuses[oldListIndex];
            final toStatus = _statuses[newListIndex];

            final fromList = widget.columns[fromStatus]!;
            final toList = widget.columns[toStatus]!;

            final moved = fromList.removeAt(oldItemIndex);
            toList.insert(newItemIndex, moved);

            setState(() {}); // обновим UI
            await widget.onMoveBug(
              bugId: moved.id,
              fromStatus: fromStatus,
              toStatus: toStatus,
            );
          },

          // === перестановка самих колонок (обязательный параметр в ^0.4.2) ===
          onListReorder: (oldListIndex, newListIndex) async {
            final moved = _statuses.removeAt(oldListIndex);
            _statuses.insert(newListIndex, moved);
            setState(() {});
            if (widget.onReorderColumns != null) {
              await widget.onReorderColumns!(oldListIndex, newListIndex);
            }
          },

          axis: Axis.horizontal,
          listPadding: const EdgeInsets.all(8),
          listWidth: 320,
        ),
      ),
    );
  }
}
