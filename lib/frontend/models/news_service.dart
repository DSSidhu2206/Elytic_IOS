import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_item.dart';

class NewsService {
  static Future<List<NewsItem>> fetchNewsSince(int lastSeenVersion) async {
    final snap = await FirebaseFirestore.instance
        .collection('news')
        .where('version', isGreaterThan: lastSeenVersion)
        .orderBy('version')
        .get();
    return snap.docs.map((d) => NewsItem.fromDoc(d)).toList();
  }

  static Future<void> updateLastSeen(String uid, int newVersion) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'lastSeenNewsVersion': newVersion});
  }
}
