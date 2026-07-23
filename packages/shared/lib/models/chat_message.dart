import 'availability_slot.dart';

class ChatMessage {
  final String id;
  final String sender; // 'user' or 'agent'
  final String text;
  final DateTime timestamp;
  final List<AvailabilitySlot> proposedSlots;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.proposedSlots = const [],
  });
}
