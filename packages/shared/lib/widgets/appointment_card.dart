import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import 'status_badge.dart';
import '../theme/app_colors.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback? onTap;
  final Widget? trailingAction;

  const AppointmentCard({
    Key? key,
    required this.appointment,
    this.onTap,
    this.trailingAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final dateStr = dateFormat.format(appointment.requestedStartTime);
    final timeStr = "${timeFormat.format(appointment.requestedStartTime)} - ${timeFormat.format(appointment.requestedEndTime)}";

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
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
                  Expanded(
                    child: Text(
                      appointment.serviceName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusBadge(status: appointment.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    "With ${appointment.staffName}",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.lightTextSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    "$dateStr ($timeStr)",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
              if (appointment.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  "Notes: ${appointment.notes}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
              if (trailingAction != null) ...[
                const Divider(height: 20),
                trailingAction!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
