import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import 'package:intl/intl.dart';

import '../../data/database/database_helper.dart';
import '../../data/models/report.dart';
import '../../data/repositories/ticket_repository.dart';
import 'report_controller.dart';
import 'report_export_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  ReportController? _controller;
  final _exporter = ReportExportService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _controller = ReportController(repository: context.read<TicketRepository>())..load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReportController>.value(
      value: _controller!,
      child: Consumer<ReportController>(
        builder: (context, controller, _) => Scaffold(
          appBar: AppBar(title: const Text('Bilan')),
          body: controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: controller.load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _PeriodSelector(controller: controller),
                      const SizedBox(height: 16),
                      _ReportSummary(controller: controller),
                      const SizedBox(height: 20),
                      _SectionTitle('Ventilation par forfait'),
                      ...controller.report.byPack.map((item) => _PackSaleRow(item: item)),
                      const SizedBox(height: 20),
                      _SectionTitle('Stock restant'),
                      ...controller.stock.map((item) => _StockRow(item: item)),
                      const SizedBox(height: 20),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        FilledButton.icon(onPressed: () => _export(context, controller), icon: const Icon(Icons.share), label: const Text('Exporter')),
                        OutlinedButton.icon(onPressed: () => _backup(context), icon: const Icon(Icons.save_alt), label: const Text('Sauvegarder la base')),
                        OutlinedButton.icon(onPressed: () => _restore(context, controller), icon: const Icon(Icons.restore), label: const Text('Restaurer')),
                      ]),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, ReportController controller) async {
    try {
      await _exporter.shareReport(controller.report, controller.period.label, controller.generatedAt);
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export impossible.')));
    }
  }

  Future<void> _backup(BuildContext context) async {
    try {
      final source = File(await DatabaseHelper.instance.databasePath);
      final result = await FilePicker.platform.saveFile(fileName: 'gestion_wifi.db', type: FileType.any);
      if (result == null) return;
      await source.copy(result);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Base sauvegardée.')));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sauvegarde impossible.')));
    }
  }

  Future<void> _restore(BuildContext context, ReportController controller) async {
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
      final sourcePath = picked?.files.single.path;
      if (sourcePath == null) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Restaurer la base ?'),
          content: const Text('Les données locales actuelles seront remplacées.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restaurer')),
          ],
        ),
      );
      if (confirmed != true) return;
      await DatabaseHelper.instance.close();
      final destination = await DatabaseHelper.instance.databasePath;
      await File(sourcePath).copy(destination);
      await controller.load();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Base restaurée.')));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restauration impossible.')));
    }
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.controller});

  final ReportController controller;

  @override
  Widget build(BuildContext context) => SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'Aujourd’hui', label: Text('Aujourd’hui')),
          ButtonSegment(value: 'Ce mois', label: Text('Ce mois')),
          ButtonSegment(value: 'Mois précédent', label: Text('Mois précédent')),
          ButtonSegment(value: 'Total', label: Text('Total')),
        ],
        selected: {controller.period.label},
        onSelectionChanged: (value) => controller.selectPeriod(value.first),
        showSelectedIcon: false,
      );
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.controller});

  final ReportController controller;
  static final _amountFormat = NumberFormat('#,##0', 'fr_FR');

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Chiffre d’affaires'),
            Text(_format(controller.report.totalAmount), style: Theme.of(context).textTheme.headlineMedium),
            Text('${controller.report.salesCount} tickets vendus'),
            Text('${controller.report.cancelledCount} tickets annulés'),
          ]),
        ),
      );

  String _format(int amount) =>
      '${_amountFormat.format(amount).replaceAll(RegExp('[\\u00A0\\u202F]'), ' ')} F';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: Theme.of(context).textTheme.titleLarge));
}

class _PackSaleRow extends StatelessWidget {
  const _PackSaleRow({required this.item});
  final PackSales item;
  @override
  Widget build(BuildContext context) => ListTile(
        title: Text('${_format(item.quantity)} × ${_format(item.unitPrice)} = ${_format(item.total)}'),
        subtitle: Text(item.packName),
      );

  String _format(int amount) =>
      '${NumberFormat('#,##0', 'fr_FR').format(amount).replaceAll(RegExp('[\\u00A0\\u202F]'), ' ')} F';
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.item});
  final PackStock item;
  @override
  Widget build(BuildContext context) => ListTile(title: Text(item.packName), trailing: Text('${item.availableStock} disponibles'));
}
