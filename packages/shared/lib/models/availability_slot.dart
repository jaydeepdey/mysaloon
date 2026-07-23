class AvailabilitySlot {
  final String id;
  final String staffId;
  final String staffName;
  final String date;
  final String startTime;
  final String endTime;
  final bool isBooked;

  AvailabilitySlot({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.isBooked = false,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      id: json['id'] ?? '',
      staffId: json['staff_id'] ?? '',
      staffName: json['staff_name'] ?? json['staff']?['name'] ?? 'Salon Specialist',
      date: json['date'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      isBooked: json['is_booked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_id': staffId,
      'staff_name': staffName,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'is_booked': isBooked,
    };
  }
}
