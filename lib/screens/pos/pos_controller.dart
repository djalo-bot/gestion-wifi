import 'package:flutter/foundation.dart';

import '../../data/models/pack.dart';
import '../../data/models/ticket.dart';
import '../../data/repositories/ticket_repository.dart';
import '../../services/printer_service.dart';

class PosController extends ChangeNotifier {
  PosController({
    required TicketRepository repository,
    required PrinterService printer,
  })  : _repository = repository,
        _printer = printer;

  final TicketRepository _repository;
  final PrinterService _printer;

  List<Pack> packs = const [];
  List<Ticket> lastSales = const [];
  bool isLoading = true;
  bool isBusy = false;
  String? errorMessage;
  Ticket? lastTicket;
  Pack? lastPack;
  Object? printError;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _reloadData();
    } catch (_) {
      errorMessage = 'Impossible de charger les données locales.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sell(Pack pack) async {
    if (isBusy || pack.id == null) return;
    if (pack.availableStock == 0) {
      errorMessage = 'Stock épuisé pour ce forfait';
      notifyListeners();
      return;
    }

    isBusy = true;
    errorMessage = null;
    printError = null;
    notifyListeners();
    try {
      final ticket = await _repository.sellNextTicket(pack.id!);
      if (ticket == null) {
        errorMessage = 'Stock épuisé pour ce forfait';
        return;
      }
      lastTicket = ticket;
      lastPack = pack;
      try {
        await _printer.printTicket(ticket, pack);
      } catch (error) {
        printError = error;
      }
      await _reloadData();
    } catch (_) {
      errorMessage = 'La vente n’a pas pu être enregistrée.';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> reprint(Ticket ticket) async {
    if (isBusy) return;
    final pack = packs.where((item) => item.id == ticket.packId).firstOrNull;
    if (pack == null) {
      errorMessage = 'Forfait introuvable pour ce ticket.';
      notifyListeners();
      return;
    }

    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _printer.printTicket(ticket, pack);
    } catch (_) {
      errorMessage = 'Échec de la réimpression.';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> cancel(Ticket ticket) async {
    if (isBusy || ticket.id == null) return false;
    isBusy = true;
    notifyListeners();
    try {
      final cancelled = await _repository.cancelSale(ticket.id!);
      await _reloadData();
      return cancelled;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void clearLastSale() {
    lastTicket = null;
    lastPack = null;
    printError = null;
    notifyListeners();
  }

  Future<void> _reloadData() async {
    packs = await _repository.getPacksWithStock();
    lastSales = await _repository.getLastSales(5);
  }
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
