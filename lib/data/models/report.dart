class SalesReport {
  const SalesReport({
    required this.salesCount,
    required this.totalAmount,
    required this.cancelledCount,
    required this.byPack,
  });

  final int salesCount;
  final int totalAmount;
  final int cancelledCount;
  final List<PackSales> byPack;
}

class PackSales {
  const PackSales({
    required this.packName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  final String packName;
  final int quantity;
  final int unitPrice;
  final int total;
}

class PackStock {
  const PackStock({
    required this.packId,
    required this.packName,
    required this.price,
    required this.availableStock,
  });

  final int packId;
  final String packName;
  final int price;
  final int availableStock;
}
