class Pack {
  const Pack({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    this.availableStock = 0,
  });

  final int? id;
  final String name;
  final int price;
  final String duration;
  final int availableStock;

  Pack copyWith({
    int? id,
    String? name,
    int? price,
    String? duration,
    int? availableStock,
  }) {
    return Pack(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      duration: duration ?? this.duration,
      availableStock: availableStock ?? this.availableStock,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'duration': duration,
    };
  }

  factory Pack.fromMap(Map<String, Object?> map) {
    return Pack(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: map['price'] as int,
      duration: map['duration'] as String,
      availableStock: (map['available_stock'] as int?) ?? 0,
    );
  }
}
