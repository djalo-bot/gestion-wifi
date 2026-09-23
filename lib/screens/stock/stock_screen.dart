import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/ticket_repository.dart';
import 'stock_controller.dart';
import 'text_recognition_service.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  StockController? _controller;
  final _codesController = TextEditingController();
  final _recognitionService = TextRecognitionService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _controller = StockController(repository: context.read<TicketRepository>())..load();
    _codesController.addListener(() {
      if (_codesController.text != _controller?.rawCodes) {
        _controller?.setRawCodes(_codesController.text);
      }
    });
  }

  @override
  void dispose() {
    _codesController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StockController>.value(
      value: _controller!,
      child: Consumer<StockController>(
        builder: (context, controller, _) {
          if (_codesController.text != controller.rawCodes) {
            _codesController.value = TextEditingValue(
              text: controller.rawCodes,
              selection: TextSelection.collapsed(offset: controller.rawCodes.length),
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Stock')),
            body: controller.isLoading && controller.packs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _PackSelector(controller: controller),
                      const SizedBox(height: 16),
                      _CodeEditor(controller: controller, textController: _codesController),
                      const SizedBox(height: 12),
                      _ActionRow(controller: controller, onScan: _scan),
                      const SizedBox(height: 12),
                      _ReviewSummary(review: controller.review),
                      if (controller.review.invalidCodes.isNotEmpty)
                        _InvalidLines(codes: controller.review.invalidCodes),
                      if (controller.errorMessage != null)
                        _MessageBox(message: controller.errorMessage!, color: Colors.red.shade50),
                      if (controller.saveSummary != null) _SavedSummary(controller: controller),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Future<void> _scan() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Caméra refusée'),
          content: const Text('L’accès à la caméra est nécessaire pour scanner les codes.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
            if (cameraStatus.isPermanentlyDenied)
              TextButton(onPressed: openAppSettings, child: const Text('Ouvrir les réglages')),
          ],
        ),
      );
      return;
    }

    try {
      final text = await _recognitionService.captureLatinText();
      if (text != null && mounted) context.read<StockController>().appendRecognizedText(text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lecture du texte impossible.')),
      );
    }
  }
}

class _PackSelector extends StatelessWidget {
  const _PackSelector({required this.controller});

  final StockController controller;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: controller.selectedPackId,
      decoration: const InputDecoration(labelText: 'Forfait', border: OutlineInputBorder()),
      items: controller.packs
          .where((pack) => pack.id != null)
          .map((pack) => DropdownMenuItem(value: pack.id, child: Text('${pack.name} · ${pack.price} F')))
          .toList(),
      onChanged: controller.setSelectedPack,
    );
  }
}

class _CodeEditor extends StatelessWidget {
  const _CodeEditor({required this.controller, required this.textController});

  final StockController controller;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: textController,
      minLines: 8,
      maxLines: 14,
      decoration: const InputDecoration(
        labelText: 'Codes Wi-Fi',
        hintText: 'Un code par ligne, ou séparés par espace, virgule ou point-virgule',
        alignLabelWithHint: true,
        border: OutlineInputBorder(),
      ),
      style: TextStyle(
        height: 1.5,
        color: controller.review.invalidCodes.isEmpty ? null : Colors.black87,
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.controller, required this.onScan});

  final StockController controller;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      OutlinedButton.icon(onPressed: controller.isSaving ? null : onScan, icon: const Icon(Icons.document_scanner_outlined), label: const Text('Scanner')),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton.icon(
          onPressed: controller.isSaving || controller.review.validCodes.isEmpty ? null : controller.save,
          icon: controller.isSaving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
          label: const Text('Enregistrer'),
        ),
      ),
    ]);
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.review});

  final StockReview review;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${review.validCodes.length} valides / ${review.invalidCodes.length} invalides / ${review.duplicateCodes.length} doublons'),
    ]);
  }
}

class _InvalidLines extends StatelessWidget {
  const _InvalidLines({required this.codes});

  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      color: Colors.red.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lignes invalides', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...codes.map(
            (code) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              color: Colors.red.shade300,
              child: Text(code),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedSummary extends StatelessWidget {
  const _SavedSummary({required this.controller});

  final StockController controller;

  @override
  Widget build(BuildContext context) {
    return _MessageBox(
      color: Colors.green.shade50,
      message: '${controller.saveSummary}!'
          '${controller.savedDuplicates.isEmpty ? '' : '\nDoublons : ${controller.savedDuplicates.join(', ')}'}',
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      color: color,
      child: Text(message),
    );
  }
}
