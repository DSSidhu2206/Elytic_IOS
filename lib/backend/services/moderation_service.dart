// lib/backend/services/moderation_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ModerationService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> muteUser({
    required String targetUserId,
    required String targetUsername,
    required int targetTier,
    required String modUserId,
    required String modUsername,
    required int modTier,
    required int durationMinutes,
    required String reason,
  }) async {
    final now = DateTime.now();
    final muteUntil = now.add(Duration(minutes: durationMinutes));
    final ticketId = '${targetUserId}_${now.millisecondsSinceEpoch}';

    // Save mute ticket
    await _firestore
        .collection('Moderation')
        .doc('MuteTickets')
        .collection('Tickets')
        .doc(ticketId)
        .set({
      'targetUserId': targetUserId,
      'targetUsername': targetUsername,
      'targetTier': targetTier,
      'mutedAt': now,
      'muteDurationMinutes': durationMinutes,
      'mutedUntil': muteUntil,
      'mutedById': modUserId,
      'mutedByUsername': modUsername,
      'mutedByTier': modTier,
      'muteReason': reason,
      'status': 'active',
    });

    // Save mute state to user doc (for UI enforcement and lookups)
    await _firestore.collection('users').doc(targetUserId).update({
      'muteUntil': Timestamp.fromDate(muteUntil),
      'muteReason': reason,
      'mutedBy': modUsername,
      'currentMuteTicketId': ticketId,
      'muteAppealId': FieldValue.delete(), // Clear any previous appeals
    });
  }

  static Future<void> unmuteUser({
    required String targetUserId,
    required String modUserId,
    required String modUsername,
    required int modTier,
  }) async {
    // Find the ticketId for the active mute from user doc
    final userDoc = await _firestore.collection('users').doc(targetUserId).get();
    final ticketId = userDoc.data()?['currentMuteTicketId'];
    if (ticketId != null) {
      await _firestore
          .collection('Moderation')
          .doc('MuteTickets')
          .collection('Tickets')
          .doc(ticketId)
          .set({
        'unmutedById': modUserId,
        'unmutedByUsername': modUsername,
        'unmutedByTier': modTier,
        'unmutedAt': DateTime.now(),
        'status': 'inactive',
      }, SetOptions(merge: true));
    }
    // Remove mute fields from user doc
    await _firestore.collection('users').doc(targetUserId).update({
      'muteUntil': FieldValue.delete(),
      'muteReason': FieldValue.delete(),
      'mutedBy': FieldValue.delete(),
      'muteAppealId': FieldValue.delete(),
      'currentMuteTicketId': FieldValue.delete(),
    });
  }

  static Future<void> appealMute({
    required String targetUserId,
    required String appealReason,
  }) async {
    final userDoc = await _firestore.collection('users').doc(targetUserId).get();
    final ticketId = userDoc.data()?['currentMuteTicketId'];
    if (ticketId != null) {
      await _firestore
          .collection('Moderation')
          .doc('MuteTickets')
          .collection('Tickets')
          .doc(ticketId)
          .set({
        'muteAppeal': {
          'appealReason': appealReason,
          'appealedAt': DateTime.now(),
          'status': 'pending',
          'moderatedBy': null,
        }
      }, SetOptions(merge: true));
      await _firestore.collection('users').doc(targetUserId).update({
        'muteAppealId': ticketId,
      });
    }
  }

  static Future<void> removeProfilePicture({
    required String targetUserId,
    required String targetUsername,
    required String targetAvatarUrl,
    required String modUserId,
    required String modUsername,
    required int modTier,
    required String reason,
  }) async {
    await _firestore.collection('Moderation').doc('ProfileRemovals').collection('Logs').add({
      'targetUserId': targetUserId,
      'targetUsername': targetUsername,
      'oldAvatarUrl': targetAvatarUrl,
      'modUserId': modUserId,
      'modUsername': modUsername,
      'modTier': modTier,
      'reason': reason,
      'removedAt': DateTime.now(),
    });
    await _firestore.collection('users').doc(targetUserId).update({
      'avatarUrl': 'assets/avatars/avatar_1.png',
    });
  }

  static Future<void> removeBio({
    required String targetUserId,
    required String targetUsername,
    required String oldBio,
    required String modUserId,
    required String modUsername,
    required int modTier,
    required String reason,
  }) async {
    if (oldBio == 'Due to severe violations of user agreement this users bio has been removed') return;
    await _firestore.collection('Moderation').doc('BioRemovals').collection('Logs').add({
      'targetUserId': targetUserId,
      'targetUsername': targetUsername,
      'oldBio': oldBio,
      'modUserId': modUserId,
      'modUsername': modUsername,
      'modTier': modTier,
      'reason': reason,
      'removedAt': DateTime.now(),
    });
    await _firestore.collection('users').doc(targetUserId).update({
      'bio': 'Due to severe violations of user agreement this users bio has been removed',
    });
  }

  static Future<void> requestPermanentBan(
      BuildContext context, {
        required String targetUserId,
        required String targetUsername,
        required int targetTier,
        required String modUserId,
        required String modUsername,
        required int modTier,
      }) async {
    final reason = await _showBanReasonDialog(context);
    if (reason == null) return;

    await _firestore.collection('Moderation').doc('PermanentBanRequests').collection('Requests').add({
      'targetUserId': targetUserId,
      'targetUsername': targetUsername,
      'targetTier': targetTier,
      'modUserId': modUserId,
      'modUsername': modUsername,
      'modTier': modTier,
      'reason': reason,
      'requestedAt': DateTime.now(),
    });
  }

  static Future<String?> _showBanReasonDialog(BuildContext context) async {
    final controller = TextEditingController();
    String? result;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permanent Ban Reason'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter a reason or select a category.'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLength: 500,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'Enter detailed reason...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Submit')),
        ],
      ),
    ).then((value) => result = value);

    return result?.isNotEmpty == true ? result : null;
  }
}
