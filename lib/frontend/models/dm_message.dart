import 'package:cloud_firestore/cloud_firestore.dart';

class DMMessage {
  final String id;
  final String text;
  final String senderId;
  final String receiverId;
  final DateTime sentAt;
  final String status; // 'sent' or 'read'

  DMMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.receiverId,
    required this.sentAt,
    this.status = 'sent',
  });

  Map<String, dynamic> toMap() => {
    'text': text,
    'senderId': senderId,
    'receiverId': receiverId,
    'sentAt': sentAt,
    'status': status,
  };

  static DMMessage fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DMMessage(
      id: doc.id,
      text: d['text'],
      senderId: d['senderId'],
      receiverId: d['receiverId'],
      sentAt: (d['sentAt'] as Timestamp).toDate(),
      status: d['status'] ?? 'sent',
    );
  }
}
