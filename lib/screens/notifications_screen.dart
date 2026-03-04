import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';

/// Notifications Screen - shows user notifications
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'แจ้งเตือน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.notifications, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'ไม่มีการแจ้งเตือน',
              style: TextStyle(fontSize: 18, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Text(
              'เมื่อมีกิจกรรมใหม่ คุณจะเห็นที่นี่',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
