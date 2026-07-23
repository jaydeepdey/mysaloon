import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_item.dart';
import '../models/appointment.dart';
import '../models/notification.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  SupabaseClient? _client;

  Future<void> initialize({required String url, required String anonKey}) async {
    if (url.isEmpty || anonKey.isEmpty || url.contains('your-supabase')) {
      return;
    }
    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
      _client = Supabase.instance.client;
    } catch (e) {
      print("Supabase initialization error: $e");
    }
  }

  SupabaseClient? get client => _client;

  // Mock / Default Services fallback if Supabase is unconfigured
  final List<ServiceItem> _mockServices = [
    ServiceItem(
      id: '11111111-1111-1111-1111-111111111111',
      name: 'Signature Haircut & Styling',
      description: 'Precision haircut including shampoo, scalp massage, and professional blow-dry styling.',
      durationMinutes: 45,
      price: 65.00,
    ),
    ServiceItem(
      id: '22222222-2222-2222-2222-222222222222',
      name: 'Full Hair Coloring & Gloss',
      description: 'Full head color treatment using premium organic dyes, followed by a shine gloss.',
      durationMinutes: 90,
      price: 120.00,
    ),
    ServiceItem(
      id: '33333333-3333-3333-3333-333333333333',
      name: 'Hydrating Facial Spa',
      description: 'Deep cleansing facial with botanical enzymes and hydrating hyaluronic mask.',
      durationMinutes: 60,
      price: 85.00,
    ),
    ServiceItem(
      id: '44444444-4444-4444-4444-444444444444',
      name: 'Gel Manicure & Hand Care',
      description: 'Nail shaping, cuticle treatment, gel polish application, and hand massage.',
      durationMinutes: 45,
      price: 45.00,
    ),
  ];

  final List<Appointment> _mockAppointments = [
    Appointment(
      id: 'appt-demo-1',
      customerId: 'cust-demo-1',
      customerName: 'Sophia Martinez',
      serviceId: '11111111-1111-1111-1111-111111111111',
      serviceName: 'Signature Haircut & Styling',
      staffId: 'a1111111-1111-1111-1111-111111111111',
      staffName: 'Elena Rostova',
      requestedStartTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
      requestedEndTime: DateTime.now().add(const Duration(days: 1, hours: 2, minutes: 45)),
      status: 'pending',
      notes: 'Customer requested Saturday afternoon styling',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  // Fetch Services
  Future<List<ServiceItem>> getServices() async {
    if (_client != null) {
      try {
        final res = await _client!.from('services').select().eq('is_active', true);
        return (res as List).map((json) => ServiceItem.fromJson(json)).toList();
      } catch (e) {
        print("Failed fetching services from Supabase: $e");
      }
    }
    return _mockServices;
  }

  // Fetch Customer Appointments
  Future<List<Appointment>> getCustomerAppointments(String customerId) async {
    if (_client != null) {
      try {
        final res = await _client!
            .from('appointments')
            .select('*, service:services(name), staff:staff(name)')
            .eq('customer_id', customerId)
            .order('requested_start_time', ascending: true);
        return (res as List).map((json) => Appointment.fromJson(json)).toList();
      } catch (e) {
        print("Failed fetching customer appointments: $e");
      }
    }
    return _mockAppointments;
  }

  // Fetch Owner Appointments
  Future<List<Appointment>> getAllAppointments() async {
    if (_client != null) {
      try {
        final res = await _client!
            .from('appointments')
            .select('*, customer:customers(name), service:services(name), staff:staff(name)')
            .order('requested_start_time', ascending: true);
        return (res as List).map((json) => Appointment.fromJson(json)).toList();
      } catch (e) {
        print("Failed fetching owner appointments: $e");
      }
    }
    return _mockAppointments;
  }

  // Update Appointment Status
  Future<void> updateAppointmentStatus(String appointmentId, String status, {String? reason}) async {
    if (_client != null) {
      try {
        await _client!.from('appointments').update({
          'status': status,
          'notes': reason != null ? 'Reason: $reason' : '',
        }).eq('id', appointmentId);
        return;
      } catch (e) {
        print("Failed updating appointment status in Supabase: $e");
      }
    }
    
    // Mock local update
    final index = _mockAppointments.indexWhere((a) => a.id == appointmentId);
    if (index != -1) {
      final old = _mockAppointments[index];
      _mockAppointments[index] = Appointment(
        id: old.id,
        customerId: old.customerId,
        customerName: old.customerName,
        serviceId: old.serviceId,
        serviceName: old.serviceName,
        staffId: old.staffId,
        staffName: old.staffName,
        requestedStartTime: old.requestedStartTime,
        requestedEndTime: old.requestedEndTime,
        status: status,
        notes: reason ?? old.notes,
        createdAt: old.createdAt,
      );
    }
  }

  // Realtime Stream of Appointments
  Stream<List<Map<String, dynamic>>>? streamAppointments() {
    if (_client != null) {
      return _client!.from('appointments').stream(primaryKey: ['id']);
    }
    return null;
  }
}
