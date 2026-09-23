import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/pack.dart';
import '../../data/models/ticket.dart';
import '../../data/repositories/ticket_repository.dart';
import '../../services/printer_service.dart';
import 'pos_controller.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  PosController? _controller;
  static final _amountFormat = NumberFormat('#,##0', 'fr_FR');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _controller = PosController(
      repository: context.read<TicketRepository>(),
      printer: FakePrinterService(),
    )..load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PosController>.value(
      value: _controller!,
      child: Consumer<PosController>(
        builder: (context, controller, _) {
          return Scaffold(
            appBar: AppBar(title: const Text('Caisse')),
            body: RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (controller.errorMessage != null)
                    _ErrorBanner(message: controller.errorMessage!),
                  _PackGrid(
                    controller: controller,
                    formatAmount: _formatAmount,
                  ),
                  const SizedBox(height: 24),
                  Text('Dernières ventes', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  _SalesList(controller: controller),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatAmount(int amount) =>
      '${_amountFormat.format(amount).replaceAll(RegExp('[\\u00A0\\u202F]'), ' ')} F';
}

class _PackGrid extends StatelessWidget {
  const _PackGrid({required this.controller, required this.formatAmount});

  final PosController controller;
  final String Function(int amount) formatAmount;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading && controller.packs.isEmpty) {
      return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
    }
    if (controller.packs.isEmpty) {
      return const SizedBox(height: 220, child: Center(child: Text('Aucun forfait configuré')));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: controller.packs.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 132,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final pack = controller.packs[index];
        return Stack(
          children: [
            SizedBox.expand(
              child: FilledButton(
                onPressed: controller.isBusy
                    ? null
                    : pack.availableStock == 0
                        ? () => _showStockAlert(context, pack)
                        : () => _sell(context, pack),
                style: FilledButton.styleFrom(
                  backgroundColor: pack.availableStock == 0 ? Colors.grey : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(formatAmount(pack.price), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${_shortDuration(pack.duration)} · ${pack.availableStock} dispos', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            if (pack.availableStock > 0 && pack.availableStock < 10)
              Positioned(top: 7, right: 7, child: _StockBadge(count: pack.availableStock)),
          ],
        );
      },
    );
  }

  String _shortDuration(String duration) {
    return duration
        .replaceAll('Heures', 'h')
        .replaceAll('Heure', 'h')
        .replaceAll('heures', 'h')
        .replaceAll('heure', 'h');
  }

  Future<void> _sell(BuildContext context, Pack pack) async {
    final controller = context.read<PosController>();
    await controller.sell(pack);
    if (!context.mounted || controller.lastTicket == null) return;
    HapticFeedback.lightImpact();
    if (controller.printError != null) {
      await _showPrintFailure(context, controller);
    } else {
      await _showSuccess(context, controller.lastTicket!);
    }
    if (context.mounted) controller.clearLastSale();
  }

  void _showStockAlert(BuildContext context, Pack pack) {
    if (pack.availableStock != 0) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stock épuisé'),
        content: Text('Stock épuisé pour ce forfait'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }

  Future<void> _showSuccess(BuildContext context, Ticket ticket) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future<void>.delayed(const Duration(milliseconds: 3500), () {
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        });
        return AlertDialog(
          title: const Text('Ticket vendu'),
          content: SelectableText(ticket.code, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Future<void> _showPrintFailure(BuildContext context, PosController controller) async {
    final ticket = controller.lastTicket!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Impression échouée'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('La vente est enregistrée. Code du ticket :'),
          const SizedBox(height: 10),
          SelectableText(ticket.code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await controller.reprint(ticket);
            },
            child: const Text('Réimprimer'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await controller.cancel(ticket);
            },
            child: const Text('Annuler la vente'),
          ),
        ],
      ),
    );
  }
}

class _SalesList extends StatelessWidget {
  const _SalesList({required this.controller});

  final PosController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.lastSales.isEmpty) return const Text('Aucune vente récente.');
    return Column(
      children: controller.lastSales.map((ticket) => _SaleTile(ticket: ticket, controller: controller)).toList(),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.ticket, required this.controller});

  final Ticket ticket;
  final PosController controller;

  @override
  Widget build(BuildContext context) {
    final time = ticket.soldAt?.length == 19 ? ticket.soldAt!.substring(11, 16) : ticket.soldAt ?? '';
    return Card(
      child: ListTile(
        title: Text('${ticket.packName ?? 'Forfait'} · ${ticket.code}'),
        subtitle: Text(time),
        trailing: Wrap(spacing: 4, children: [
          IconButton(tooltip: 'Réimprimer', onPressed: controller.isBusy ? null : () => controller.reprint(ticket), icon: const Icon(Icons.print_outlined)),
          IconButton(tooltip: 'Annuler', onPressed: controller.isBusy ? null : () => _cancel(context), icon: const Icon(Icons.undo)),
        ]),
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la vente ?'),
        content: Text('Le ticket ${ticket.code} sera marqué comme annulé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Annuler')),
        ],
      ),
    );
    if (confirmed == true) await controller.cancel(ticket);
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.orange,
      child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MaterialBanner(
        content: Text(message),
        actions: [TextButton(onPressed: () {}, child: const Text('Fermer'))],
      ),
    );
  }
}
