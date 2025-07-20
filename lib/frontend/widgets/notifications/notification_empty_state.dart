import 'package:flutter/material.dart';

class NotificationEmptyState extends StatelessWidget {
  const NotificationEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            "No notifications yet!",
            style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
