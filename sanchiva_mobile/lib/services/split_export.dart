import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/split.dart';
import 'download_helper.dart';

final _dateFmt = DateFormat('dd MMM yyyy');
/// e.g. 12_sep_2026
final _fileDateStamp = DateFormat('dd_MMM_yyyy');

/// Safe Excel base name: "Rishikesh Trip" → "rishikesh_trip"
String _groupFileSlug(String name) {
  var s = name.trim().toLowerCase();
  // Spaces → underscores
  s = s.replaceAll(RegExp(r'\s+'), '_');
  // Drop characters unsafe for filenames
  s = s.replaceAll(RegExp(r'[^a-z0-9_\-]'), '');
  // Collapse multiple underscores
  s = s.replaceAll(RegExp(r'_+'), '_');
  s = s.replaceAll(RegExp(r'^_+|_+$'), '');
  return s.isEmpty ? 'split_group' : s;
}

/// Multi-sheet Excel (.xlsx) for a split group:
/// Expenses · Balance · Settled
Future<void> exportSplitGroupExcel(SplitGroupDetail detail) async {
  final hasEntries =
      detail.expenses.isNotEmpty || detail.settlements.isNotEmpty;
  if (!hasEntries) {
    throw Exception('No entries to download yet');
  }

  final sheets = <_SheetData>[
    _SheetData(
      name: 'Expenses',
      headers: const [
        'Date',
        'Description',
        'Amount',
        'Paid by',
        'Split among',
        'Notes',
        'Amount edited',
      ],
      rows: detail.expenses.map((e) {
        final among = e.shares.isEmpty
            ? ''
            : e.shares.map((s) => s.displayName).join(', ');
        return [
          _dateFmt.format(e.expenseDate),
          e.description,
          e.amount.toStringAsFixed(2),
          e.paidByDisplay,
          among,
          e.notes,
          e.amountEditCount > 0 ? '${e.amountEditCount}×' : '',
        ];
      }).toList(),
    ),
    _SheetData(
      name: 'Balance',
      headers: const [
        'Member',
        'Balance',
        'Status',
      ],
      rows: detail.balances.map((b) {
        final abs = b.balance.abs();
        final status = abs < 0.01
            ? 'settled'
            : b.balance > 0
                ? 'owed'
                : 'owes';
        return [
          b.displayName,
          b.balance.toStringAsFixed(2),
          status,
        ];
      }).toList(),
    ),
    _SheetData(
      name: 'Settled',
      headers: const [
        'Date',
        'From',
        'To',
        'Amount',
        'Notes',
      ],
      rows: detail.settlements
          .map(
            (s) => [
              _dateFmt.format(s.settledDate),
              s.fromDisplay,
              s.toDisplay,
              s.amount.toStringAsFixed(2),
              s.notes,
            ],
          )
          .toList(),
    ),
  ];

  final bytes = _buildMultiSheetXlsx(sheets);
  // e.g. rishikesh_trip_12_sep_2026.xlsx
  final slug = _groupFileSlug(detail.name);
  final datePart = _fileDateStamp.format(DateTime.now()).toLowerCase();
  final filename = '${slug}_$datePart.xlsx';
  final title = '${detail.name} · Splits export';

  if (kIsWeb) {
    downloadBytes(
      bytes,
      filename,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    return;
  }

  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$filename';
  final x = XFile.fromData(
    bytes,
    name: filename,
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  await x.saveTo(path);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(path)], text: title),
  );
}

// ── Minimal multi-sheet XLSX (OOXML) via archive — no excel package ────────

class _SheetData {
  _SheetData({
    required this.name,
    required this.headers,
    required this.rows,
  });

  final String name;
  final List<String> headers;
  final List<List<String>> rows;
}

/// Builds a valid multi-sheet .xlsx as bytes.
Uint8List _buildMultiSheetXlsx(List<_SheetData> sheets) {
  if (sheets.isEmpty) {
    throw Exception('No sheets to write');
  }

  final archive = Archive();

  void addXml(String path, String xml) {
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile(path, data.length, data));
  }

  // Content types
  final overrideParts = StringBuffer();
  for (var i = 0; i < sheets.length; i++) {
    overrideParts.writeln(
      '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
    );
  }
  addXml(
    '[Content_Types].xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '$overrideParts'
    '<Override PartName="/xl/styles.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '</Types>',
  );

  // Package relationships
  addXml(
    '_rels/.rels',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
    'Target="xl/workbook.xml"/>'
    '</Relationships>',
  );

  // Workbook + sheet relationships
  final sheetEntries = StringBuffer();
  final sheetRels = StringBuffer();
  for (var i = 0; i < sheets.length; i++) {
    final id = i + 1;
    final safeSheetName = _escapeXml(_sheetName(sheets[i].name, i));
    sheetEntries.write(
      '<sheet name="$safeSheetName" sheetId="$id" r:id="rId$id"/>',
    );
    sheetRels.write(
      '<Relationship Id="rId$id" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet$id.xml"/>',
    );
  }
  // styles rel
  final stylesId = sheets.length + 1;
  sheetRels.write(
    '<Relationship Id="rId$stylesId" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
    'Target="styles.xml"/>',
  );

  addXml(
    'xl/workbook.xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets>$sheetEntries</sheets>'
    '</workbook>',
  );

  addXml(
    'xl/_rels/workbook.xml.rels',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '$sheetRels'
    '</Relationships>',
  );

  // Minimal styles (required by Excel)
  addXml(
    'xl/styles.xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
    '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
    '<borders count="1"><border/></borders>'
    '<cellStyleXfs count="1"><xf/></cellStyleXfs>'
    '<cellXfs count="1"><xf/></cellXfs>'
    '</styleSheet>',
  );

  for (var i = 0; i < sheets.length; i++) {
    addXml('xl/worksheets/sheet${i + 1}.xml', _worksheetXml(sheets[i]));
  }

  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}

String _worksheetXml(_SheetData sheet) {
  final rows = <List<String>>[sheet.headers, ...sheet.rows];
  final buf = StringBuffer();
  buf.write(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<sheetData>',
  );

  for (var r = 0; r < rows.length; r++) {
    final rowNum = r + 1;
    buf.write('<row r="$rowNum">');
    final cols = rows[r];
    for (var c = 0; c < cols.length; c++) {
      final ref = '${_colLetter(c)}$rowNum';
      final text = _escapeXml(cols[c]);
      // Numbers without quotes as numbers when pure numeric
      final raw = cols[c].trim();
      final asNum = double.tryParse(raw);
      if (asNum != null &&
          RegExp(r'^-?\d+(\.\d+)?$').hasMatch(raw) &&
          r > 0 &&
          (c == 2 || c == 1 || c == 3)) {
        // Prefer number type for amount-like columns; still safe for other nums
        buf.write('<c r="$ref"><v>$raw</v></c>');
      } else if (asNum != null && RegExp(r'^-?\d+(\.\d+)?$').hasMatch(raw)) {
        buf.write('<c r="$ref"><v>$raw</v></c>');
      } else {
        buf.write('<c r="$ref" t="inlineStr"><is><t>$text</t></is></c>');
      }
    }
    buf.write('</row>');
  }

  buf.write('</sheetData></worksheet>');
  return buf.toString();
}

String _colLetter(int index) {
  var n = index;
  final sb = StringBuffer();
  while (n >= 0) {
    sb.write(String.fromCharCode(65 + (n % 26)));
    n = (n ~/ 26) - 1;
  }
  return sb.toString().split('').reversed.join();
}

String _escapeXml(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

/// Excel sheet names max 31 chars, no \ / ? * [ ]
String _sheetName(String name, int index) {
  var n = name.replaceAll(RegExp(r'[\\/*?:\[\]]'), ' ').trim();
  if (n.isEmpty) n = 'Sheet${index + 1}';
  if (n.length > 31) n = n.substring(0, 31);
  return n;
}
