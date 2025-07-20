import 'package:flutter/material.dart';

class NotificationTypeIcon extends StatelessWidget {
  final String type;
  final bool isRead;

  const NotificationTypeIcon({super.key, required this.type, required this.isRead});

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case 'tierUpgrade':
        return const Icon(Icons.upgrade, color: Colors.amber, size: 32);
      case 'event':
        return const Icon(Icons.event, color: Colors.deepPurple, size: 32);
      case 'shopPurchase':
        return const Icon(Icons.shopping_bag, color: Colors.green, size: 32);
      case 'bioRemoved':
        return const Icon(Icons.remove_circle, color: Colors.orange, size: 32);
      default:
        return Icon(Icons.notifications, color: isRead ? Colors.grey : Colors.blue, size: 32);
    }
  }
}
