import 'package:cloud_firestore/cloud_firestore.dart';

class DmBadgeHelper {
  static Future<int> getUnreadUnmutedDmCount({
    required String currentUserId,
    required List<String> mutedDms,
    required Map<String, dynamic> dmLastRead,
  }) async {
    int _toMillis(dynamic ts) {
      if (ts == null) return 0;
      if (ts is int) return ts;
      if (ts is Timestamp) return ts.millisecondsSinceEpoch;
      return 0;
    }

    final dmSnap = await FirebaseFirestore.instance
        .collection('dm_rooms')
        .where('participants', arrayContains: currentUserId)
        .get();

    int count = 0;
    for (final doc in dmSnap.docs) {
      final data = doc.data();
      final roomId = doc.id;
      final lastMessageTs = _toMillis(data['lastMessageTimestamp']);
      final lastReadTs = _toMillis(dmLastRead[roomId]);
      final isMuted = mutedDms.contains(roomId);
      final isUnread = lastMessageTs > lastReadTs;

      if (isUnread && !isMuted) count++;
    }
    return count;
  }
}
