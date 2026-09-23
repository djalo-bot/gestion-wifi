import 'package:flutter/foundation.dart';

import '../../data/models/pack.dart';
import '../../data/repositories/ticket_repository.dart';

class StockReview {
  const StockReview({
    required this.validCodes,
    required this.invalidCodes,
    required this.duplicateCodes,
  });

  final List<String> validCodes;
  final List<String> invalidCodes;
  final List<String> duplicateCodes;
}

class StockController extends ChangeNotifier {
  StockController({required TicketRepository repository}) : _repository = repository;

  final TicketRepository _repository;
  static final RegExp _codePattern = RegExp(r'^[A-Za-z0-9]{6,8}$');

  List<Pack> packs = const [];
  int? selectedPackId;
  String rawCodes = '';
  StockReview review = const StockReview(
    validCodes: [],
    invalidCodes: [],
    duplicateCodes: [],
  );
  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;
  String? saveSummary;
  List<String> savedDuplicates = const [];

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      packs = await _repository.getPacksWithStock();
      selectedPackId ??= packs.firstOrNull?.id;
    } catch (_) {
      errorMessage = 'Impossible de charger les forfaits locaux.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedPack(int? packId) {
    selectedPackId = packId;
    saveSummary = null;
    notifyListeners();
  }

  void setRawCodes(String value) {
    rawCodes = value;
    review = _review(value);
    saveSummary = null;
    savedDuplicates = const [];
    notifyListeners();
  }

  void appendRecognizedText(String value) {
    final existing = rawCodes
        .split(RegExp(r'[\s,;]+'))
        .where((token) => token.isNotEmpty)
        .toSet();
    final scannedCodes = value
        .split(RegExp(r'[\s,;]+'))
        .where((token) => _codePattern.hasMatch(token) && existing.add(token))
        .toList();
    if (scannedCodes.isEmpty) return;
    final appended = rawCodes.trim().isEmpty ? scannedCodes.join('\n') : '$rawCodes\n${scannedCodes.join('\n')}';
    setRawCodes(appended);
  }

  Future<void> save() async {
    if (isSaving || selectedPackId == null || review.validCodes.isEmpty) return;
    isSaving = true;
    errorMessage = null;
    saveSummary = null;
    notifyListeners();
    try {
      final result = await _repository.insertCodes(selectedPackId!, review.validCodes);
      final inserted = result['insérés'] ?? 0;
      final duplicates = result['doublons'] ?? 0;
      savedDuplicates = review.duplicateCodes;
      saveSummary = '$inserted ajoutés, $duplicates doublons ignorés';
      rawCodes = '';
      review = const StockReview(validCodes: [], invalidCodes: [], duplicateCodes: []);
    } catch (_) {
      errorMessage = 'Impossible d’enregistrer les codes.';
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  StockReview _review(String value) {
    final tokens = value.split(RegExp(r'[\s,;]+')).where((token) => token.isNotEmpty);
    final validCodes = <String>[];
    final invalidCodes = <String>[];
    final duplicateCodes = <String>[];
    final seen = <String>{};

    for (final token in tokens) {
      if (!_codePattern.hasMatch(token)) {
        invalidCodes.add(token);
      } else if (!seen.add(token)) {
        duplicateCodes.add(token);
      } else {
        validCodes.add(token);
      }
    }
    return StockReview(
      validCodes: validCodes,
      invalidCodes: invalidCodes,
      duplicateCodes: duplicateCodes,
    );
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
