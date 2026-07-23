class Owner {
  final String id;
  final String salonName;
  final String phone;
  final String email;

  Owner({
    required this.id,
    required this.salonName,
    required this.phone,
    required this.email,
  });

  factory Owner.fromJson(Map<String, dynamic> json) {
    return Owner(
      id: json['id'] ?? '',
      salonName: json['salon_name'] ?? 'Luxe Aura Salon',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'salon_name': salonName,
      'phone': phone,
      'email': email,
    };
  }
}
