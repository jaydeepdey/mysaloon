class Staff {
  final String id;
  final String name;
  final List<String> specialties;
  final bool isActive;

  Staff({
    required this.id,
    required this.name,
    required this.specialties,
    this.isActive = true,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      specialties: List<String>.from(json['specialties'] ?? []),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'specialties': specialties,
      'is_active': isActive,
    };
  }
}
