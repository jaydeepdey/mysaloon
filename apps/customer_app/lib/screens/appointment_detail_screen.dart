import 'package:flutter/material.dart';
import 'package:shared/shared.dart';
import 'package:intl/intl.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final Appointment appointment;

  const AppointmentDetailScreen({Key? key, required this.appointment}) : super(key: key);

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  bool _isCancelling = false;

  void _cancelAppointment() async {
    setState(() => _isCancelling = true);
    await SupabaseService.instance.updateAppointmentStatus(widget.appointment.id, 'cancelled');
    if (!mounted) return;
    setState(() => _isCancelling = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appointment cancelled successfully.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appt = widget.appointment;
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    appt.serviceName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                StatusBadge(status: appt.status),
              ],
            ),
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.calendar_month_rounded,
                      "Date",
                      dateFormat.format(appt.requestedStartTime),
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      Icons.access_time_filled_rounded,
                      "Time Window",
                      "${timeFormat.format(appt.requestedStartTime)} - ${timeFormat.format(appt.requestedEndTime)}",
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      Icons.person_rounded,
                      "Specialist",
                      appt.staffName,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      Icons.storefront_rounded,
                      "Salon Location",
                      "Luxe Aura Salon & Spa, Suite 100",
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (appt.status == 'pending' || appt.status == 'approved') ...[
              CustomButton(
                text: 'Cancel Appointment',
                isSecondary: true,
                isLoading: _isCancelling,
                icon: Icons.close_rounded,
                onPressed: _cancelAppointment,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }
}
