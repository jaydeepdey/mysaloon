import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

class PendingRequestsScreen extends StatefulWidget {
  const PendingRequestsScreen({Key? key}) : super(key: key);

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  List<Appointment> _pendingAppointments = [];
  bool _isLoading = true;
  final AgentApiService _agentApi = AgentApiService();

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    setState(() => _isLoading = true);
    final all = await SupabaseService.instance.getAllAppointments();
    if (!mounted) return;
    setState(() {
      _pendingAppointments = all.where((a) => a.status == 'pending').toList();
      _isLoading = false;
    });
  }

  void _handleDecision(Appointment appt, String decision, {String? reason}) async {
    // 1. Update Supabase
    await SupabaseService.instance.updateAppointmentStatus(appt.id, decision, reason: reason);

    // 2. Notify Python LangGraph Agent service to resume paused checkpointer state
    await _agentApi.sendOwnerDecision(
      threadId: "thread-${appt.id}",
      appointmentId: appt.id,
      decision: decision,
      reason: reason,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Appointment successfully ${decision.toUpperCase()}!')),
    );
    _loadPendingRequests();
  }

  void _showRejectDialog(Appointment appt) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide an optional reason for the client:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g., Slot double booked or specialist unavailable',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusRejected),
            onPressed: () {
              Navigator.pop(context);
              _handleDecision(appt, 'rejected', reason: reasonController.text.trim());
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approval Requests'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPendingRequests,
        child: _isLoading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 2,
                itemBuilder: (context, index) => const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: LoadingSkeleton(height: 140, borderRadius: 16),
                ),
              )
            : _pendingAppointments.isEmpty
                ? const EmptyStateView(
                    title: 'All Caught Up!',
                    description: 'There are no pending appointment requests needing approval right now.',
                    icon: Icons.check_circle_outline_rounded,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingAppointments.length,
                    itemBuilder: (context, index) {
                      final appt = _pendingAppointments[index];
                      return AppointmentCard(
                        appointment: appt,
                        trailingAction: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.statusRejected,
                                  side: const BorderSide(color: AppColors.statusRejected),
                                ),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text('Reject'),
                                onPressed: () => _showRejectDialog(appt),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.statusApproved,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: const Text('Approve'),
                                onPressed: () => _handleDecision(appt, 'approved'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
