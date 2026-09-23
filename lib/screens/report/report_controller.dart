import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../data/database/database_helper.dart';
import '../../data/models/report.dart';
import '../../data/repositories/ticket_repository.dart';

class ReportPeriod {
  const ReportPeriod(this.label, this.from, this.to);

  final String label;
  final DateTime from;
  final DateTime to;
}

class ReportController extends ChangeNotifier {
  ReportController({required TicketRepository repository}) : _repository = repository;

  final TicketRepository _repository;
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  ReportPeriod period = _periodFor('Aujourd’hui');
  SalesReport report = const SalesReport(salesCount: 0, totalAmount: 0, cancelledCount: 0, byPack: []);
  List<PackStock> stock = const [];
  bool isLoading = true;
  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await Future.wait([
        _repository.getReport(_timestamp(period.from), _timestamp(period.to)),
        _repository.getStockByPack(),
      ]);
      report = result[0] as SalesReport;
      stock = result[1] as List<PackStock>;
    } catch (_) {
      errorMessage = 'Impossible de charger le bilan local.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectPeriod(String label) async {
    period = _periodFor(label);
    await load();
  }

  String get generatedAt => _dateFormat.format(DateTime.now());

  String _timestamp(DateTime value) => DatabaseHelper.localTimestamp(value);

  static ReportPeriod _periodFor(String label) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (label == 'Ce mois') {
      return ReportPeriod(label, DateTime(now.year, now.month), DateTime(now.year, now.month + 1).subtract(const Duration(seconds: 1)));
    }
    if (label == 'Mois précédent') {
      return ReportPeriod(label, DateTime(now.year, now.month - 1), DateTime(now.year, now.month).subtract(const Duration(seconds: 1)));
    }
    if (label == 'Total') {
      return ReportPeriod(label, DateTime(2000), DateTime(2099, 12, 31, 23, 59, 59));
    }
    return ReportPeriod(label, today, today.add(const Duration(days: 1)).subtract(const Duration(seconds: 1)));
  }
}
