import '../data/models/pack.dart';
import '../data/models/ticket.dart';

abstract interface class PrinterService {
  Future<void> printTicket(Ticket ticket, Pack pack);
}

class FakePrinterService implements PrinterService {
  FakePrinterService({this.failPrinting = false});

  final bool failPrinting;

  @override
  Future<void> printTicket(Ticket ticket, Pack pack) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (failPrinting) {
      throw Exception('Impression simulée indisponible');
    }
  }
}
