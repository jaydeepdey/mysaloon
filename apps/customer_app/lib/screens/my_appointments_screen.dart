import 'package:flutter/material.dart';
import 'package:shared/shared.dart';
import 'appointment_detail_screen.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({Key? key}) : super(key: key);

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  List<Appointment> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    final appts = await SupabaseService.instance.getCustomerAppointments('cust-demo-1');
    if (!mounted) return;
    setState(() {
      _appointments = appts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAppointments,
        child: _isLoading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 3,
                itemBuilder: (context, index) => const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: LoadingSkeleton(height: 110, borderRadius: 16),
                ),
              )
            : _appointments.isEmpty
                ? const EmptyStateView(
                    title: 'No Appointments Yet',
                    description: "You don't have any upcoming salon appointments scheduled.",
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _appointments.length,
                    itemBuilder: (context, index) {
                      final appt = _appointments[index];
                      return AppointmentCard(
                        appointment: appt,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AppointmentDetailScreen(appointment: appt),
                            ),
                          ).then((_) => _loadAppointments());
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
