import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

class ManageAvailabilityScreen extends StatefulWidget {
  const ManageAvailabilityScreen({Key? key}) : super(key: key);

  @override
  State<ManageAvailabilityScreen> createState() => _ManageAvailabilityScreenState();
}

class _ManageAvailabilityScreenState extends State<ManageAvailabilityScreen> {
  final Map<String, bool> _workingDays = {
    'Monday': true,
    'Tuesday': true,
    'Wednesday': true,
    'Thursday': true,
    'Friday': true,
    'Saturday': true,
    'Sunday': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Availability'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Working Days',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select which days the salon is open for appointment bookings.',
              style: TextStyle(color: AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 16),

            Card(
              child: Column(
                children: _workingDays.keys.map((day) {
                  return SwitchListTile(
                    title: Text(day, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_workingDays[day]! ? 'Open 09:00 AM - 06:00 PM' : 'Closed'),
                    value: _workingDays[day]!,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        _workingDays[day] = val;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            CustomButton(
              text: 'Save Availability Schedule',
              icon: Icons.save_rounded,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Working hours updated successfully.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
