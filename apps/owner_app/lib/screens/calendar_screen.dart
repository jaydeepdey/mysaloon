import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

class OwnerCalendarScreen extends StatefulWidget {
  const OwnerCalendarScreen({Key? key}) : super(key: key);

  @override
  State<OwnerCalendarScreen> createState() => _OwnerCalendarScreenState();
}

class _OwnerCalendarScreenState extends State<OwnerCalendarScreen> {
  List<Appointment> _approvedAppointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCalendarData();
  }

  Future<void> _loadCalendarData() async {
    setState(() => _isLoading = true);
    final all = await SupabaseService.instance.getAllAppointments();
    if (!mounted) return;
    setState(() {
      _approvedAppointments = all.where((a) => a.status == 'approved').toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmed Schedule'),
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: LoadingSkeleton(height: 120, borderRadius: 16),
              ),
            )
          : _approvedAppointments.isEmpty
              ? const EmptyStateView(
                  title: 'No Confirmed Bookings',
                  description: 'Approved client bookings will show up here on the master calendar.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _approvedAppointments.length,
                  itemBuilder: (context, index) {
                    final appt = _approvedAppointments[index];
                    return AppointmentCard(appointment: appt);
                  },
                ),
    );
  }
}
