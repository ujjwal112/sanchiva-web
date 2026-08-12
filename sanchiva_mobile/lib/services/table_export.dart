import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'download_helper.dart';

/// Generic CSV / PDF export for tabular loan & credit data.
Future<void> exportTableReport({
  required String baseName,
  required String title,
  required List<String> headers,
  required List<List<String>> rows,
  required String format, // csv | pdf
}) async {
  if (rows.isEmpty) {
    throw Exception('No rows to download');
  }

  if (format == 'pdf') {
    final bytes = await _toPdf(title: title, headers: headers, rows: rows);
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

  final csv = _toCsv(headers, rows);
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

String _toCsv(List<String> headers, List<List<String>> rows) {
  String esc(String s) {
    final t = s.replaceAll('"', '""');
    return '"$t"';
  }

  final b = StringBuffer(headers.map(esc).join(','));
  b.writeln();
  for (final r in rows) {
    b.writeln(r.map(esc).join(','));
  }
  return b.toString();
}

Future<Uint8List> _toPdf({
  required String title,
  required List<String> headers,
  required List<List<String>> rows,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('${rows.length} rows'),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ),
  );
  return doc.save();
}
