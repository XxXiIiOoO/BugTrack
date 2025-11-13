import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';

import '../models/bug.dart';

class ReportService {
  pw.Font? _regularFont;
  pw.Font? _boldFont;

  Future<File> _tempFile(String name) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/$name');
  }

  Future<void> _ensureFonts() async {
    if (_regularFont != null && _boldFont != null) {
      return;
    }
    final regularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    _regularFont = pw.Font.ttf(regularData);
    _boldFont = pw.Font.ttf(boldData);
  }

  pw.ThemeData _pdfTheme() {
    return pw.ThemeData.withFont(
      base: _regularFont!,
      bold: _boldFont ?? _regularFont!,
    );
  }

  Future<File> writeCsv(List<Bug> bugs) async {
    final rows = <List<dynamic>>[
      ['ID', 'Title', 'Status', 'Priority', 'Labels', 'Created', 'Deadline', 'Assignee'],
      for (final b in bugs)
        [
          b.id,
          b.title,
          b.status,
          b.priority,
          b.labels.join('|'),
          b.creationDate.toIso8601String(),
          b.estimatedCompletion?.toIso8601String() ?? '',
          b.assignedTo,
        ]
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final f = await _tempFile('bugs_report.csv');
    return f.writeAsString(csv, encoding: utf8);
  }

  Future<File> writePdf(List<Bug> bugs) async {
    await _ensureFonts();
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        theme: _pdfTheme(),
        build: (ctx) => [
          pw.Header(level: 0, child: pw.Text('Bugs Report', style: pw.TextStyle(font: _boldFont))),
          pw.Table.fromTextArray(
            headers: ['Title', 'Status', 'Priority', 'Created', 'Deadline'],
            data: bugs.map((b) => [
              b.title,
              b.status,
              b.priority,
              b.creationDate.toIso8601String().split('T').first,
              b.estimatedCompletion?.toIso8601String().split('T').first ?? '-',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    final f = await _tempFile('bugs_report.pdf');
    await f.writeAsBytes(await pdf.save());
    return f;
  }

  Future<void> share(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<File> writeStatsPdf({
    required String title,
    required String projectName,
    required String periodLabel,
    required String totalSummary,
    required Map<String, int> statusCounts,
    required Map<String, int> priorityCounts,
    required Map<String, int> monthlyCounts,
    required String statusesSectionTitle,
    required String prioritiesSectionTitle,
    required String monthsSectionTitle,
    required String keyColumnTitle,
    required String valueColumnTitle,
  }) async {
    await _ensureFonts();
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        theme: _pdfTheme(),
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(title, style: pw.TextStyle(font: _boldFont, fontSize: 20)),
          ),
          pw.Text(projectName, style: pw.TextStyle(font: _boldFont)),
          pw.Text(periodLabel),
          pw.SizedBox(height: 12),
          pw.Text(totalSummary),
          pw.SizedBox(height: 16),
          _mapTable(
            statusesSectionTitle,
            statusCounts,
            keyColumnTitle: keyColumnTitle,
            valueColumnTitle: valueColumnTitle,
          ),
          pw.SizedBox(height: 16),
          _mapTable(
            prioritiesSectionTitle,
            priorityCounts,
            keyColumnTitle: keyColumnTitle,
            valueColumnTitle: valueColumnTitle,
          ),
          pw.SizedBox(height: 16),
          _mapTable(
            monthsSectionTitle,
            monthlyCounts,
            keyColumnTitle: keyColumnTitle,
            valueColumnTitle: valueColumnTitle,
          ),
        ],
      ),
    );
    final f = await _tempFile('stats_report.pdf');
    await f.writeAsBytes(await pdf.save());
    return f;
  }

  pw.Widget _mapTable(
    String title,
    Map<String, int> data, {
    required String keyColumnTitle,
    required String valueColumnTitle,
  }) {
    final entries = data.entries.toList();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(font: _boldFont, fontSize: 14)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: [keyColumnTitle, valueColumnTitle],
          data: entries
              .map((e) => [
                    e.key,
                    e.value.toString(),
                  ])
              .toList(),
          headerStyle: pw.TextStyle(font: _boldFont),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }
}
