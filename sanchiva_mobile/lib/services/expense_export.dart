import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/format.dart' as core;
import '../models/expense.dart';
import 'download_helper.dart';

final _dateFmt = DateFormat('dd MMM yyyy');

/// Uses system display currency (Profile) — not live FX/metals.
String formatMoney(num v) => core.formatMoney(v);
String formatDate(DateTime d) => _dateFmt.format(d);

String expensesToCsv(List<Expense> rows) {
  final b = StringBuffer('Date,Item,Category,Paid via,Via detail,Amount\n');
  for (final r in rows) {
    final item = r.itemName.replaceAll('"', '""');
    final cat = r.category.replaceAll('"', '""');
    final via = r.paidVia.replaceAll('"', '""');
    final detail = r.paidViaDetail.replaceAll('"', '""');
    b.writeln('${r.dateIso},"$item","$cat","$via","$detail",${r.amount}');
  }
  return b.toString();
}

Future<Uint8List> expensesToPdf({
  required String title,
  required List<Expense> rows,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Total: ${formatMoney(rows.fold<double>(0, (s, e) => s + e.amount))}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: const ['Date', 'Item', 'Category', 'Paid via', 'Detail', 'Amount'],
          data: rows
              .map(
                (e) => [
                  e.dateIso,
                  e.itemName,
                  e.category,
                  e.paidVia,
                  e.paidViaDetail,
                  e.amount.toStringAsFixed(2),
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ),
  );
  return doc.save();
}

/// Share or download report (CSV and/or PDF). Works on mobile + Chrome web.
Future<void> exportExpensesReport({
  required String baseName,
  required String title,
  required List<Expense> rows,
  required String format, // csv | pdf
}) async {
  if (rows.isEmpty) {
    throw Exception('No expenses to download for this period');
  }

  if (format == 'pdf') {
    final bytes = await expensesToPdf(title: title, rows: rows);
    final name = '$baseName.pdf';
    if (kIsWeb) {
      downloadBytes(bytes, name, 'application/pdf');
    } else {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$name';
      final x = XFile.fromData(bytes, name: name, mimeType: 'application/pdf');
      await x.saveTo(path);
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: title));
    }
    return;
  }

  final csv = expensesToCsv(rows);
  final name = '$baseName.csv';
  if (kIsWeb) {
    downloadBytes(utf8.encode(csv), name, 'text/csv');
  } else {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$name';
    final x = XFile.fromData(utf8.encode(csv), name: name, mimeType: 'text/csv');
    await x.saveTo(path);
    await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: title));
  }
}
