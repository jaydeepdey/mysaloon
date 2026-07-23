class Appointment {
  final String id;
  final String customerId;
  final String customerName;
  final String serviceId;
  final String serviceName;
  final String staffId;
  final String staffName;
  final DateTime requestedStartTime;
  final DateTime requestedEndTime;
  final String status; // 'pending', 'approved', 'rejected', 'cancelled', 'completed'
  final String notes;
  final DateTime createdAt;

  Appointment({
    required this.id,
    required this.customerId,
    this.customerName = 'Customer',
    required this.serviceId,
    this.serviceName = 'Salon Service',
    required this.staffId,
    this.staffName = 'Specialist',
    required this.requestedStartTime,
    required this.requestedEndTime,
    required this.status,
    this.notes = '',
    required this.createdAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] ?? '',
      customerId: json['customer_id'] ?? '',
      customerName: json['customer']?['name'] ?? json['customer_name'] ?? 'Jane Doe',
      serviceId: json['service_id'] ?? '',
      serviceName: json['service']?['name'] ?? json['service_name'] ?? 'Signature Haircut',
      staffId: json['staff_id'] ?? '',
      staffName: json['staff']?['name'] ?? json['staff_name'] ?? 'Elena Rostova',
      requestedStartTime: DateTime.tryParse(json['requested_start_time'] ?? '') ?? DateTime.now(),
      requestedEndTime: DateTime.tryParse(json['requested_end_time'] ?? '') ?? DateTime.now().add(const Duration(minutes: 45)),
      status: json['status'] ?? 'pending',
      notes: json['notes'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'service_id': serviceId,
      'service_name': serviceName,
      'staff_id': staffId,
      'staff_name': staffName,
      'requested_start_time': requestedStartTime.toIso8601String(),
      'requested_end_time': requestedEndTime.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
