import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/report.dart';

class ReportExportService {
  final _amountFormat = NumberFormat('#,##0', 'fr_FR');

  Future<void> shareReport(SalesReport report, String periodLabel, String generatedAt) async {
    final directory = await getTemporaryDirectory();
    final csvFile = File('${directory.path}/bilan_wifi.csv');
    final textFile = File('${directory.path}/bilan_wifi.txt');
    await csvFile.writeAsBytes(utf8.encode('\uFEFF${_csv(report, periodLabel)}'));
    await textFile.writeAsString(_text(report, periodLabel, generatedAt));
    await SharePlus.instance.share(
      ShareParams(
        text: 'Bilan Wi-Fi - $periodLabel',
        files: [XFile(csvFile.path), XFile(textFile.path)],
      ),
    );
  }

  String _csv(SalesReport report, String periodLabel) {
    final rows = <List<String>>[
      ['Période', 'Forfait', 'Quantité', 'Prix unitaire', 'Total'],
      ...report.byPack.map((item) => [
            periodLabel,
            item.packName,
            '${item.quantity}',
            '${item.unitPrice}',
            '${item.total}',
          ]),
    ];
    return rows.map((row) => row.map(_escape).join(';')).join('\r\n');
  }

  String _text(SalesReport report, String periodLabel, String generatedAt) {
    final lines = <String>[
      'BILAN WI-FI',
      'Période : $periodLabel',
      'Généré le : $generatedAt',
      '',
      'Chiffre d’affaires : ${_format(report.totalAmount)}',
      'Tickets vendus : ${report.salesCount}',
      'Tickets annulés : ${report.cancelledCount}',
      '',
      'VENTILATION PAR FORFAIT',
      ...report.byPack.map((item) => '${item.quantity} × ${_format(item.unitPrice)} = ${_format(item.total)}'),
    ];
    return lines.join('\n');
  }

  String _format(int amount) => '${_amountFormat.format(amount).replaceAll(RegExp('[\\u00A0\\u202F]'), ' ')} F';

  String _escape(String value) => '"${value.replaceAll('"', '""')}"';
}
