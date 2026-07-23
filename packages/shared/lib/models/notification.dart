class AppNotification {
  final String id;
  final String appointmentId;
  final String recipientType; // 'customer' or 'owner'
  final String message;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.appointmentId,
    required this.recipientType,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      appointmentId: json['appointment_id'] ?? '',
      recipientType: json['recipient_type'] ?? 'customer',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
