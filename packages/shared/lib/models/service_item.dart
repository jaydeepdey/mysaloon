class ServiceItem {
  final String id;
  final String name;
  final String description;
  final int durationMinutes;
  final double price;
  final bool isActive;

  ServiceItem({
    required this.id,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.price,
    this.isActive = true,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 30,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'duration_minutes': durationMinutes,
      'price': price,
      'is_active': isActive,
    };
  }
}
