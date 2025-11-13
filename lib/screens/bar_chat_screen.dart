import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SimpleBarChart extends StatelessWidget {
  final Map<String, int> dataByStatus;

  const SimpleBarChart({super.key, required this.dataByStatus});

  @override
  Widget build(BuildContext context) {
    // Превратим в список (status, count)
    final entries = dataByStatus.entries.toList();
    // Построим bar-списки
    final barGroups = <BarChartGroupData>[];

    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: e.value.toDouble(),
              width: 20,
              color: Colors.blueAccent,
            )
          ],
          // Можно добавить borderRadius, etc.
        ),
      );
    }

    return BarChart(
      BarChartData(
        maxY: entries
                .map((e) => e.value)
                .reduce((a, b) => a > b ? a : b)
                .toDouble() +
            1,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                // val – индекс в списке; выводим status
                final index = val.toInt();
                if (index < 0 || index >= entries.length) return Container();
                return Text(entries[index].key,
                    style: const TextStyle(color: Colors.white, fontSize: 12));
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true),
      ),
    );
  }
}
