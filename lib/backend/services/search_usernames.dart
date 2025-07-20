// lib/backend/services/search_usernames.dart

import 'package:cloud_firestore/cloud_firestore.dart';

Future<List<Map<String, dynamic>>> searchUsernames(String term, {int limit = 50}) async {
  final q = term.trim().toLowerCase();
  if (q.isEmpty) return [];

  final snap = await FirebaseFirestore.instance
      .collection('users')
      .orderBy('username_lowercase')
      .startAt([q])
      .endAt([q + '\uf8ff'])
      .limit(limit)
      .get();

  return snap.docs
      .map((doc) => {...doc.data(), 'id': doc.id})
      .toList();
}
