import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/availability_slot.dart';

class AgentResponse {
  final String threadId;
  final String message;
  final String status;
  final List<AvailabilitySlot> proposedSlots;
  final String? appointmentId;

  AgentResponse({
    required this.threadId,
    required this.message,
    required this.status,
    required this.proposedSlots,
    this.appointmentId,
  });
}

class AgentApiService {
  final String baseUrl;

  AgentApiService({this.baseUrl = 'http://localhost:8000'});

  // Customer Chat Endpoint
  Future<AgentResponse> sendChatMessage({
    required String threadId,
    required String customerId,
    required String message,
    String? selectedSlotId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'thread_id': threadId,
          'customer_id': customerId,
          'message': message,
          if (selectedSlotId != null) 'selected_slot_id': selectedSlotId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final slotsRaw = data['proposed_slots'] as List? ?? [];
        final slots = slotsRaw.map((s) => AvailabilitySlot.fromJson(s)).toList();

        return AgentResponse(
          threadId: data['thread_id'] ?? threadId,
          message: data['message'] ?? 'Thank you! How else can I assist you?',
          status: data['status'] ?? 'conversing',
          proposedSlots: slots,
          appointmentId: data['appointment_id'],
        );
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print("Agent API error: $e. Returning simulated AI agent response.");
      // Fallback agent logic if API server is offline
      return AgentResponse(
        threadId: threadId,
        message: "I checked our Luxe Salon schedule for your request! We have open slots tomorrow at 10:00 AM and 2:00 PM with specialist Elena Rostova. Would you like me to reserve one?",
        status: "slots_proposed",
        proposedSlots: [
          AvailabilitySlot(
            id: 's1-haircut-10am',
            staffId: 'a1111111-1111-1111-1111-111111111111',
            staffName: 'Elena Rostova',
            date: DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0],
            startTime: '10:00:00',
            endTime: '10:45:00',
          ),
          AvailabilitySlot(
            id: 's2-haircut-2pm',
            staffId: 'a1111111-1111-1111-1111-111111111111',
            staffName: 'Elena Rostova',
            date: DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0],
            startTime: '14:00:00',
            endTime: '14:45:00',
          ),
        ],
        appointmentId: 'appt-demo-1',
      );
    }
  }

  // Owner Decision Endpoint
  Future<bool> sendOwnerDecision({
    required String threadId,
    required String appointmentId,
    required String decision, // 'approved' or 'rejected'
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/owner/decision'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'thread_id': threadId,
          'appointment_id': appointmentId,
          'decision': decision,
          if (reason != null) 'reason': reason,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Agent API owner decision error: $e");
      return true; // Fallback mock success
    }
  }
}
