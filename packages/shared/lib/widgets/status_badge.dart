import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'approved':
        bg = AppColors.statusApproved.withOpacity(0.15);
        fg = AppColors.statusApproved;
        label = 'Approved';
        icon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        bg = AppColors.statusRejected.withOpacity(0.15);
        fg = AppColors.statusRejected;
        label = 'Rejected';
        icon = Icons.cancel_rounded;
        break;
      case 'cancelled':
        bg = AppColors.statusCancelled.withOpacity(0.15);
        fg = AppColors.statusCancelled;
        label = 'Cancelled';
        icon = Icons.block_rounded;
        break;
      case 'pending':
      default:
        bg = AppColors.statusPending.withOpacity(0.15);
        fg = AppColors.statusPending;
        label = 'Pending Approval';
        icon = Icons.hourglass_top_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
