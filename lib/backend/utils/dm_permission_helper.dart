import 'package:cloud_firestore/cloud_firestore.dart';

class DMPermissionHelper {
  static final Map<String, String> _dmPreferenceCache = {};
  static final Set<String> _friendCache = {}; // PATCHED: cache for friend relationships

  /// Returns true if [fromUserId] is allowed to DM [toUserId].
  static Future<bool> canSendDM(String fromUserId, String toUserId) async {
    if (fromUserId == toUserId) return false;

    String dmPref;

    // Check DM preference from cache
    if (_dmPreferenceCache.containsKey(toUserId)) {
      dmPref = _dmPreferenceCache[toUserId]!;
    } else {
      final prefDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(toUserId)
          .collection('settings')
          .doc('preferences')
          .get();

      final prefs = prefDoc.data() ?? {};
      dmPref = prefs['dmPreference'] ?? 'open';
      _dmPreferenceCache[toUserId] = dmPref;
    }

    if (dmPref == 'open') return true;
    if (dmPref == 'closed') return false;

    // PATCHED: friends-only with caching
    final key = '$fromUserId:$toUserId';
    if (_friendCache.contains(key)) return true;

    final friendDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(toUserId)
        .collection('friends')
        .doc(fromUserId)
        .get();

    final isFriend = friendDoc.exists;
    if (isFriend) _friendCache.add(key);

    return isFriend;
  }

  /// Optional: clear cache (useful for logout, etc)
  static void clearCache() {
    _dmPreferenceCache.clear();
    _friendCache.clear(); // PATCHED: clear friend cache too
  }
}
