// lib/frontend/widgets/moderation/moderation_actions_popup.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elytic/backend/services/moderation_service.dart';
import 'package:elytic/backend/services/user_service.dart'; // <-- PATCH
import 'package:intl/intl.dart';

class ModerationActionsPopup extends StatefulWidget {
  final String modUserId;
  final String modUsername;
  final int modTier;

  final UserDisplayInfo targetUser; // <-- PATCH: Use the full display info object

  final VoidCallback onClose;

  const ModerationActionsPopup({
    super.key,
    required this.modUserId,
    required this.modUsername,
    required this.modTier,
    required this.targetUser,
    required this.onClose,
  });

  @override
  State<ModerationActionsPopup> createState() => _ModerationActionsPopupState();
}

class _ModerationActionsPopupState extends State<ModerationActionsPopup> {
  bool _isLoading = false;
  Map<String, dynamic>? _muteData;
  bool _muteLoaded = false;

  bool get isAdmin => widget.modTier == 6;
  bool get canModerate => widget.modTier >= 4 && widget.targetUser.tier < 4; // <-- PATCH

  @override
  void initState() {
    super.initState();
    _fetchMuteData();
  }

  Future<void> _fetchMuteData() async {
    setState(() => _muteLoaded = false);
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.targetUser.userId)
        .get();
    if (doc.exists) {
      final data = doc.data();
      DateTime? muteUntil;
      if (data?['muteUntil'] != null) {
        final mu = data!['muteUntil'];
        muteUntil = (mu is Timestamp) ? mu.toDate() : (mu is DateTime ? mu : null);
      }
      setState(() {
        _muteData = {
          'muteUntil': muteUntil,
          'muteReason': data?['muteReason'],
          'mutedBy': data?['mutedBy'],
        };
        _muteLoaded = true;
      });
    } else {
      setState(() {
        _muteData = null;
        _muteLoaded = true;
      });
    }
  }

  Future<void> _showConfirmation(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    // Refresh mute data after confirmation
    await _fetchMuteData();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _onMute(int durationMinutes) async {
    setState(() => _isLoading = true);
    final reason = await _getReason();
    if (reason == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      await ModerationService.muteUser(
        targetUserId: widget.targetUser.userId,
        targetUsername: widget.targetUser.username,
        targetTier: widget.targetUser.tier,
        modUserId: widget.modUserId,
        modUsername: widget.modUsername,
        modTier: widget.modTier,
        durationMinutes: durationMinutes,
        reason: reason,
      );
      if (mounted) {
        await _showConfirmation("User muted successfully.");
      }
    } catch (e) {
      if (mounted) {
        _showError("Failed to mute user: $e");
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _onUnmute() async {
    setState(() => _isLoading = true);
    try {
      await ModerationService.unmuteUser(
        targetUserId: widget.targetUser.userId,
        modUserId: widget.modUserId,
        modUsername: widget.modUsername,
        modTier: widget.modTier,
      );
      if (mounted) {
        await _showConfirmation("User has been unmuted.");
      }
    } catch (e) {
      if (mounted) {
        _showError("Failed to unmute user: $e");
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _onRemoveProfilePicture() async {
    final reason = await _getReason();
    if (reason == null) return;
    setState(() => _isLoading = true);
    try {
      await ModerationService.removeProfilePicture(
        targetUserId: widget.targetUser.userId,
        targetUsername: widget.targetUser.username,
        targetAvatarUrl: widget.targetUser.avatarUrl,
        modUserId: widget.modUserId,
        modUsername: widget.modUsername,
        modTier: widget.modTier,
        reason: reason,
      );
      if (mounted) {
        await _showConfirmation("Profile picture removed.");
      }
    } catch (e) {
      if (mounted) {
        _showError("Failed to remove avatar: $e");
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _onRemoveBio() async {
    final reason = await _getReason();
    if (reason == null) return;
    setState(() => _isLoading = true);
    try {
      await ModerationService.removeBio(
        targetUserId: widget.targetUser.userId,
        targetUsername: widget.targetUser.username,
        oldBio: widget.targetUser.bio,
        modUserId: widget.modUserId,
        modUsername: widget.modUsername,
        modTier: widget.modTier,
        reason: reason,
      );
      if (mounted) {
        await _showConfirmation("Bio removed.");
      }
    } catch (e) {
      if (mounted) {
        _showError("Failed to remove bio: $e");
      }
    }
    setState(() => _isLoading = false);
  }

  Widget _buildMuteSection() {
    if (!_muteLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final muteUntil = _muteData?['muteUntil'] as DateTime?;
    final muteReason = _muteData?['muteReason'] as String?;
    final isMuted =
        muteUntil != null && DateTime.now().isBefore(muteUntil);

    if (isMuted) {
      return Card(
        color: Colors.red[100],
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.volume_off, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Currently muted",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 18,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Ends: ${DateFormat('EEE, MMM d • h:mm a').format(muteUntil)}",
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              if (muteReason != null && muteReason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "Reason: $muteReason",
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black87, fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.volume_up),
                label: const Text("Unmute"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: _isLoading ? null : _onUnmute,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.green[50],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: const [
            Icon(Icons.volume_up, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                "Not currently muted",
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green, fontSize: 16),
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!canModerate && !isAdmin) {
      return const Center(child: Text("You are not authorized to moderate this user."));
    }

    // Mute options in minutes
    final muteOptions = widget.modTier >= 5
        ? [15, 60, 480, 1440, 7200] // 15m, 1h, 8h, 24h, 5d for senior mods
        : [15, 60, 480, 1440]; // up to 24h for junior mods

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Moderation Actions',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 18),
              _buildMuteSection(),
              if (!(_muteData?['muteUntil'] is DateTime &&
                  DateTime.now().isBefore(_muteData!['muteUntil'])))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mute ${widget.targetUser.username}:",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        for (var m in muteOptions)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.volume_off),
                            label: Text(m >= 60 ? "${(m / 60).round()}h" : "${m}m"),
                            onPressed: _isLoading ? null : () => _onMute(m),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "You must provide a reason for muting. Users may appeal once.",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              const Divider(height: 32, thickness: 1.2),
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.orange),
                title: Text("Remove ${widget.targetUser.username}'s Profile Picture"),
                onTap: _onRemoveProfilePicture,
              ),
              ListTile(
                leading: const Icon(Icons.text_decrease, color: Colors.deepPurple),
                title: Text("Remove ${widget.targetUser.username}'s Bio"),
                onTap: _onRemoveBio,
              ),
              const Divider(height: 32, thickness: 1.2),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text("Request Permanent Ban"),
                onTap: () {
                  ModerationService.requestPermanentBan(
                    context,
                    modUserId: widget.modUserId,
                    modUsername: widget.modUsername,
                    modTier: widget.modTier,
                    targetUserId: widget.targetUser.userId,
                    targetUsername: widget.targetUser.username,
                    targetTier: widget.targetUser.tier,
                  );
                },
              ),
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
                label: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _getReason() async {
    String? reason;
    await showDialog<String>(
      context: context,
      builder: (_) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Enter Reason'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 300,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Type reason here (min 10 chars)...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().length < 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reason must be at least 10 characters.')),
                  );
                  return;
                }
                Navigator.pop(context, controller.text.trim());
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    ).then((value) => reason = value);
    return reason?.isNotEmpty == true ? reason : null;
  }
}
