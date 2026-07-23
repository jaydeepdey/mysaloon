class Customer {
  final String id;
  final String name;
  final String phone;
  final String email;
  final DateTime? createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
