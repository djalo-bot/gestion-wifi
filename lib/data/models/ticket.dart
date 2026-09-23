class Ticket {
  const Ticket({
    required this.id,
    required this.packId,
    required this.code,
    required this.status,
    required this.createdAt,
    this.soldAt,
    this.soldPrice,
    this.packName,
  });

  final int? id;
  final int packId;
  final String code;
  final String status;
  final String createdAt;
  final String? soldAt;
  final int? soldPrice;
  final String? packName;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'pack_id': packId,
      'code': code,
      'status': status,
      'created_at': createdAt,
      'sold_at': soldAt,
      'sold_price': soldPrice,
    };
  }

  factory Ticket.fromMap(Map<String, Object?> map) {
    return Ticket(
      id: map['id'] as int?,
      packId: map['pack_id'] as int,
      code: map['code'] as String,
      status: map['status'] as String,
      createdAt: map['created_at'] as String,
      soldAt: map['sold_at'] as String?,
      soldPrice: map['sold_price'] as int?,
      packName: map['pack_name'] as String?,
    );
  }
}
