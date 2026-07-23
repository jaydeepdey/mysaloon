import 'package:flutter/material.dart';
import 'package:shared/shared.dart';
import 'pending_requests_screen.dart';
import 'calendar_screen.dart';
import 'manage_services_screen.dart';
import 'manage_availability_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  List<Appointment> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final appts = await SupabaseService.instance.getAllAppointments();
    if (!mounted) return;
    setState(() {
      _appointments = appts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _appointments.where((a) => a.status == 'pending').length;
    final approvedCount = _appointments.where((a) => a.status == 'approved').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WELCOME BANNER
            Text(
              'Luxe Aura Overview',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // METRICS ROW
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Pending Requests',
                    count: '$pendingCount',
                    icon: Icons.pending_actions_rounded,
                    color: AppColors.statusPending,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PendingRequestsScreen()),
                      ).then((_) => _loadDashboardData());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Confirmed Bookings',
                    count: '$approvedCount',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.statusApproved,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const OwnerCalendarScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // MANAGEMENT SHORTCUTS
            Text(
              'Management & Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 14),

            _buildActionTile(
              context,
              title: 'Review Pending Requests',
              subtitle: '$pendingCount appointments awaiting approval',
              icon: Icons.approval_rounded,
              badgeCount: pendingCount,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PendingRequestsScreen()),
                ).then((_) => _loadDashboardData());
              },
            ),
            _buildActionTile(
              context,
              title: 'Calendar & Schedule View',
              subtitle: 'View day/week schedule of approved clients',
              icon: Icons.calendar_month_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OwnerCalendarScreen()),
                );
              },
            ),
            _buildActionTile(
              context,
              title: 'Manage Salon Services',
              subtitle: 'Add, edit or adjust service pricing & durations',
              icon: Icons.room_service_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageServicesScreen()),
                );
              },
            ),
            _buildActionTile(
              context,
              title: 'Manage Working Hours & Availability',
              subtitle: 'Block off dates or set staff shift schedules',
              icon: Icons.access_time_filled_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageAvailabilityScreen()),
                );
              },
            ),

            const SizedBox(height: 24),
            Text(
              "Today's Requests",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const LoadingSkeleton(height: 100, borderRadius: 16)
            else if (_appointments.isEmpty)
              const EmptyStateView(
                title: 'No Appointments Today',
                description: 'The salon calendar is currently open.',
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _appointments.length > 3 ? 3 : _appointments.length,
                itemBuilder: (context, index) {
                  final appt = _appointments[index];
                  return AppointmentCard(appointment: appt);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 28),
                  Text(
                    count,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: badgeCount > 0
            ? CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.statusPending,
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )
            : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ),
    );
  }
}
