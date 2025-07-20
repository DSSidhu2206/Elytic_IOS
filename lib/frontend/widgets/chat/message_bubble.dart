import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'message_list.dart';
import 'package:elytic/frontend/screens/profile/user_profile_screen.dart';
import 'package:elytic/frontend/widgets/common/username_text.dart';
import '../chat/chat_bubbles/pirate_chat_bubble.dart';
import '../chat/chat_bubbles/cloud_chat_bubble.dart';
import '../chat/chat_bubbles/galaxy_chat_bubble.dart';
import '../chat/chat_bubbles/winter_wreath_chat_bubble.dart';
import '../chat/chat_bubbles/money_chat_bubble.dart';
import '../chat/chat_bubbles/neon_chat_bubble_blue.dart';
import '../chat/chat_bubbles/neon_chat_bubble_red.dart';
import '../chat/chat_bubbles/neon_chat_bubble_pink.dart';
import '../chat/chat_bubbles/neon_chat_bubble_green.dart';
import '../chat/chat_bubbles/neon_chat_bubble_yellow.dart';
import '../chat/chat_bubbles/neon_chat_bubble_purple.dart';
import '../chat/chat_bubbles/bookmark_chat_bubble.dart';
import '../chat/chat_bubbles/fruit_chat_bubble.dart';
import '../chat/chat_bubbles/comic_chat_bubble.dart';
import 'package:just_audio/just_audio.dart';
import 'package:elytic/frontend/widgets/common/avatar_with_border.dart';
import 'package:elytic/backend/services/user_service.dart';
import 'package:elytic/backend/services/chat_service.dart';

Widget chatBubbleWidgetForId({
  required String? bubbleId,
  required String text,
}) {
  switch (bubbleId) {
    case 'CB1002': return PirateChatBubble(text: text);
    case 'CB1003': return GalaxyChatBubble(text: text);
    case 'CB1004': return WinterWreathChatBubble(text: text);
    case 'CB1005': return CloudChatBubble(text: text);
    case 'CB1006': return MoneyChatBubble(text: text);
    case 'CB1007': return NeonChatBubbleBlue(text: text);
    case 'CB1008': return NeonChatBubbleRed(text: text);
    case 'CB1009': return NeonChatBubblePink(text: text);
    case 'CB1010': return NeonChatBubbleGreen(text: text);
    case 'CB1011': return NeonChatBubbleYellow(text: text);
    case 'CB1012': return NeonChatBubblePurple(text: text);
    case 'CB1013': return BookmarkBubble(text: text);
    case 'CB1014': return FruitChatBubble(text: text);
    case 'CB1015': return ComicChatBubble(text: text);
    default:
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
        ),
      );
  }
}

class VoiceNotePlayer extends StatefulWidget {
  final String audioStoragePathOrUrl;

  const VoiceNotePlayer({Key? key, required this.audioStoragePathOrUrl}) : super(key: key);

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _downloadUrl;
  bool _loadingUrl = true;
  bool _audioLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadDownloadUrl();
  }

  Future<void> _loadDownloadUrl() async {
    try {
      final url = widget.audioStoragePathOrUrl.startsWith('http')
          ? widget.audioStoragePathOrUrl
          : await UserService.fetchVoiceNoteUrl(widget.audioStoragePathOrUrl);
      if (!mounted) return;
      setState(() {
        _downloadUrl = url.isNotEmpty ? url : null;
        _loadingUrl = false;
        _hasError = url.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingUrl = false;
        _hasError = true;
      });
    }
  }

  Future<void> _initAudioPlayer() async {
    if (_audioPlayer != null || _downloadUrl == null) return;

    setState(() {
      _audioLoading = true;
      _hasError = false;
    });

    _audioPlayer = AudioPlayer();
    _audioPlayer!.durationStream.listen((d) {
      if (d != null && mounted) setState(() => _duration = d);
    });
    _audioPlayer!.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer!.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });

    try {
      await _audioPlayer!.setUrl(_downloadUrl!);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _audioLoading = false);
    }
  }

  @override
  void dispose() {
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _onPlayPausePressed() async {
    if (_hasError) return;
    if (_audioPlayer == null) {
      await _initAudioPlayer();
      if (_hasError) return;
    }
    if (_isPlaying) {
      await _audioPlayer!.pause();
    } else {
      await _audioPlayer!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUrl) return _buildLoadingBubble();
    if (_hasError || _downloadUrl == null) return _buildErrorBubble();
    return _buildPlayer();
  }

  Widget _buildLoadingBubble() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFE0F2FE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const SizedBox(
      height: 40,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    ),
  );

  Widget _buildErrorBubble() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFDE0E0),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text('Audio not available'),
  );

  Widget _buildPlayer() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFE0F2FE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_audioLoading)
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle : Icons.play_circle,
              size: 30,
              color: Colors.blueAccent,
            ),
            onPressed: _onPlayPausePressed,
          ),
        Expanded(
          child: Slider(
            min: 0,
            max: _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
            value: _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds.toDouble()),
            onChanged: (value) async {
              if (_audioPlayer != null) {
                await _audioPlayer!.seek(Duration(milliseconds: value.toInt()));
              }
            },
          ),
        ),
        Text(
          '${_position.inMinutes.remainder(60).toString().padLeft(2, '0')}:${_position.inSeconds.remainder(60).toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    ),
  );
}

/// A chat bubble that displays text, audio, or stickers
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String currentUserId;
  final int currentUserTier;
  final Color bubbleColor;
  final TextStyle? textStyle;
  final BorderRadius borderRadius;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.currentUserId,
    required this.currentUserTier,
    this.bubbleColor = const Color(0xFFEFEFEF),
    this.textStyle,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final stickerId = message.stickerId;
    final stickerUrl = message.stickerUrl;
    final stickerPackId = message.stickerPackId;

    if (stickerId != null && stickerUrl != null && stickerUrl.isNotEmpty) {
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(
                    userId: message.userId,
                    currentUserId: currentUserId,
                    currentUserTier: currentUserTier,
                  ),
                ),
              );
            },
            child: AvatarWithBorder(
              avatarPath: message.userAvatarUrl,
              borderUrl: message.userAvatarBorderUrl,
              size: 30,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            fit: FlexFit.loose,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UsernameText(
                  username: message.username,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                if (stickerId != null && stickerUrl != null && stickerUrl.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(color: bubbleColor, borderRadius: borderRadius),
                    child: CachedNetworkImage(
                      imageUrl: stickerUrl,
                      placeholder: (_, __) => const SizedBox(
                        width: 5,
                        height: 5,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => const Icon(Icons.error),
                      width: 80,
                      fit: BoxFit.contain,
                    ),
                  )
                else if (message.audioUrl != null && message.audioUrl!.isNotEmpty)
                  VoiceNotePlayer(audioStoragePathOrUrl: message.audioUrl!)
                else
                  chatBubbleWidgetForId(
                    bubbleId: message.selectedChatBubbleId,
                    text: message.text,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}
