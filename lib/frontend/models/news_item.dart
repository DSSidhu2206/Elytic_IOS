// lib/models/news_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class NewsItem {
  final int version;
  final String title, content;

  NewsItem({
    required this.version,
    required this.title,
    required this.content,
  });

  factory NewsItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return NewsItem(
      version: data['version'] as int,
      title: data['title'] as String,
      content: data['content'] as String,
    );
  }
}
