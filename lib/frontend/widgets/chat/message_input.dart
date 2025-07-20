import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/message_validation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'sticker_input.dart';                      // ← new import
import 'package:elytic/backend/services/user_service.dart';
import 'package:elytic/backend/services/referral_service.dart'; // <-- Added

class MessageInput extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final int currentUserTier;

  const MessageInput({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.currentUserTier,
  });

  @override
  _MessageInputState createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();
  bool _isSending = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder()..openRecorder();
    _player   = FlutterSoundPlayer()  ..openPlayer();
  }

  @override
  void dispose() {
    _controller.dispose();
    _recorder?.closeRecorder();
    _player?.closePlayer();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final rawText = _controller.text.trim();
    if (rawText.isEmpty) return;

    try {
      MessageValidator.validate(
        userId: widget.currentUserId,
        userTier: widget.currentUserTier,
        rawText: rawText,
      );
    } on MessageValidationException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    setState(() => _isSending = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != widget.currentUserId) {
      setState(() => _isSending = false);
      return;
    }

    final userDocSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .get();
    final displayInfo = UserDisplayInfo.fromMap(
      widget.currentUserId,
      userDocSnapshot.data(),
    );

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'type': 'text',
      'text': rawText,
      'senderId': widget.currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'username': displayInfo.username,
      'userAvatarUrl': displayInfo.avatarUrl,
      'userAvatarBorderUrl': displayInfo.currentBorderUrl,
      'userTier': displayInfo.tier,
      'selectedChatBubbleId': displayInfo.currentBubbleId,
    });

    await ReferralService().markReferralCompletedIfNeeded(); // <-- Added here

    _controller.clear();
    setState(() => _isSending = false);
  }

  Future<void> _sendVoiceNote() async {
    final path = _recordedFilePath;
    if (path == null) return;

    setState(() => _isSending = true);
    try {
      final file = File(path);
      final ref = FirebaseStorage.instance
          .ref()
          .child(
        'user_uploads/${widget.currentUserId}/audio/voice_notes/'
            '${widget.roomId}/${DateTime.now().millisecondsSinceEpoch}_${widget.currentUserId}.aac',
      );
      await ref.putFile(file);
      final voiceUrl = await ref.getDownloadURL();

      final userDocSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();
      final displayInfo = UserDisplayInfo.fromMap(
        widget.currentUserId,
        userDocSnapshot.data(),
      );

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'type': 'voice',
        'voiceUrl': voiceUrl,
        'senderId': widget.currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'username': displayInfo.username,
        'userAvatarUrl': displayInfo.avatarUrl,
        'userAvatarBorderUrl': displayInfo.currentBorderUrl,
        'userTier': displayInfo.tier,
        'selectedChatBubbleId': displayInfo.currentBubbleId,
      });

      await ReferralService().markReferralCompletedIfNeeded(); // <-- Added here

      setState(() => _recordedFilePath = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send voice note: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission required!')),
      );
      return;
    }

    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder!.startRecorder(toFile: path, codec: Codec.aacADTS);
    setState(() {
      _isRecording = true;
      _recordedFilePath = path;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder!.stopRecorder();
    setState(() {
      _isRecording = false;
      if (path != null) _recordedFilePath = path;
    });
  }

  void _discardVoiceNote() {
    if (_recordedFilePath != null) {
      final file = File(_recordedFilePath!);
      if (file.existsSync()) file.deleteSync();
    }
    setState(() {
      _recordedFilePath = null;
      _isPlaying = false;
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player?.stopPlayer();
      setState(() => _isPlaying = false);
    } else {
      if (_recordedFilePath == null) return;
      await _player?.startPlayer(
        fromURI: _recordedFilePath!,
        codec: Codec.aacADTS,
        whenFinished: () {
          if (mounted) setState(() => _isPlaying = false);
        },
      );
      setState(() => _isPlaying = true);
    }
  }

  void _openStickerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StickerInputSheet(
        roomId: widget.roomId,
        currentUserId: widget.currentUserId,
        currentUserTier: widget.currentUserTier,
      ),
    );
  }

  void _showTierDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade Required'),
        content: Text('Only Basic Plus and Royalty users have the ability to use $feature.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/subscriptions');
            },
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.black : null,
          image: !isDark
              ? const DecorationImage(
            image:
            AssetImage('assets/icons/custom_appbar_background.png'),
            fit: BoxFit.cover,
          )
              : null,
        ),
        child: Row(
          children: [
            // Voice/message record button or disabled
            if (widget.currentUserTier >= 1) ...[
              IconButton(
                color: Colors.white,
                icon: Icon(
                  _isRecording
                      ? Icons.stop
                      : (_recordedFilePath != null
                      ? (_isPlaying
                      ? Icons.stop_circle
                      : Icons.play_circle_filled)
                      : Icons.mic),
                ),
                onPressed: _isSending
                    ? null
                    : _isRecording
                    ? _stopRecording
                    : (_recordedFilePath != null
                    ? _togglePlayback
                    : _startRecording),
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.mic_off, color: Colors.white),
                onPressed: () => _showTierDialog('Voice messages'),
              ),
            ],

            // Voice note actions if recorded
            if (_recordedFilePath != null && !_isRecording) ...[
              IconButton(
                icon: _isSending
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _isSending ? null : _sendVoiceNote,
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _isSending ? null : _discardVoiceNote,
              ),
            ] else ...[
              // Sticker picker or disabled icon
              if (widget.currentUserTier >= 2)
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white),
                  onPressed: _isSending ? null : _openStickerPicker,
                )
              else
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white),
                  onPressed: () => _showTierDialog('Stickers'),
                ),

              // Text input and send
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration.collapsed(
                      hintText: 'Type a message'),
                  onSubmitted: (_) => _sendMessage(),
                  enabled: !_isRecording && !_isSending,
                ),
              ),
              IconButton(
                icon: _isSending
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
