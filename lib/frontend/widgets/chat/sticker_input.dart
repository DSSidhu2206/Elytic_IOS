// lib/frontend/widgets/chat/sticker_input.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elytic/backend/services/chat_service.dart';
import 'package:elytic/backend/services/user_service.dart';

class StickerData {
  final String id;
  final String url;
  final String? name;
  final String? packId;

  StickerData({
    required this.id,
    required this.url,
    this.name,
    this.packId,
  });

  factory StickerData.fromMap(Map<String, dynamic> map, {String? packId}) => StickerData(
    id: map['id'] as String,
    url: map['url'] as String,
    name: map['name'] as String?,
    packId: packId ?? map['packId'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'url': url,
    'name': name,
    'packId': packId,
  };
}

class StickerInputSheet extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final int currentUserTier;

  const StickerInputSheet({
    Key? key,
    required this.roomId,
    required this.currentUserId,
    required this.currentUserTier,
  }) : super(key: key);

  @override
  State<StickerInputSheet> createState() => _StickerInputSheetState();
}

class _StickerInputSheetState extends State<StickerInputSheet> {
  late Future<List<Map<String, dynamic>>> _packsFuture;
  List<StickerData> _recent = [];
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _packsFuture = ChatService.getStickerPackMetadata();
    _loadRecent();
    _loadLastSent();
  }

  // Load recent stickers from SharedPreferences as JSON
  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('recent_stickers_v2');
    if (str != null) {
      try {
        final List<dynamic> arr = json.decode(str);
        setState(() {
          _recent = arr.map((m) => StickerData.fromMap(m as Map<String, dynamic>)).toList();
        });
      } catch (_) {
        setState(() => _recent = []);
      }
    } else {
      setState(() => _recent = []);
    }
  }

  // Save most recent sticker (as JSON object, not id)
  Future<void> _saveRecent(StickerData sticker) async {
    final prefs = await SharedPreferences.getInstance();
    final List<StickerData> newList = [sticker, ..._recent.where((s) => s.id != sticker.id || s.packId != sticker.packId)];
    final List<Map<String, dynamic>> asMaps = newList.take(50).map((s) => s.toMap()).toList();
    await prefs.setString('recent_stickers_v2', json.encode(asMaps));
    setState(() => _recent = newList.take(50).toList());
  }

  // Load last sent timestamp from SharedPreferences for cooldown
  Future<void> _loadLastSent() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('last_sticker_sent') ?? 0;
    setState(() {
      _lastSent = DateTime.fromMillisecondsSinceEpoch(millis);
    });
  }

  // Flatten all sticker objects with their pack id
  List<StickerData> _allStickerObjs(List<Map<String, dynamic>> packs) {
    return [
      for (var pack in packs)
        for (var s in (pack['stickers'] as List))
          StickerData.fromMap(
            Map<String, dynamic>.from(s as Map), // Defensive: cast to Map
            packId: pack['id'] as String?,
          )
    ];
  }

  // Send sticker: pass full StickerData object
  Future<void> _sendSticker(StickerData sticker) async {
    final now = DateTime.now();
    final diff = now.difference(_lastSent).inSeconds;
    if (diff < 5) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cooldown'),
          content: Text('Please wait ${5 - diff}s before sending another sticker.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    _lastSent = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_sticker_sent', now.millisecondsSinceEpoch);

    final displayInfo = await UserService.fetchDisplayInfo(widget.currentUserId);

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'type': 'sticker',
      'stickerId': sticker.id,
      'stickerPackId': sticker.packId,         // PATCHED: save packId!
      'stickerUrl': sticker.url,
      'stickerName': sticker.name ?? '',
      'senderId': widget.currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'username': displayInfo.username,
      'userAvatarUrl': displayInfo.avatarUrl,
      'userAvatarBorderUrl': displayInfo.currentBorderUrl,
      'userTier': displayInfo.tier,
      'selectedChatBubbleId': displayInfo.currentBubbleId,
    });

    await _saveRecent(sticker);
    Navigator.of(context).pop();
  }

  Widget _buildGrid(List<StickerData> stickerObjs) {
    if (stickerObjs.isEmpty) return const Center(child: Text('No stickers.'));
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: stickerObjs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (ctx, i) {
        final sticker = stickerObjs[i];
        return GestureDetector(
          onTap: () => _sendSticker(sticker),
          child: CachedNetworkImage(
            imageUrl: sticker.url,
            placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported),
          ),
        );
      },
    );
  }

  Widget _buildPackGrid(Map<String, dynamic> pack) {
    final stickers = (pack['stickers'] as List)
        .map((s) => StickerData.fromMap(Map<String, dynamic>.from(s as Map), packId: pack['id'] as String?))
        .toList();
    return _buildGrid(stickers);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _packsFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                  height: 200, child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError || snap.data == null) {
              return const SizedBox(
                  height: 200, child: Center(child: Text('Failed to load stickers')));
            }
            final packs = snap.data!;
            return DefaultTabController(
              length: packs.length + 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    isScrollable: true,
                    tabs: [
                      const Tab(text: 'Recent'),
                      for (var p in packs) Tab(text: p['name'] ?? 'Pack'),
                    ],
                  ),
                  SizedBox(
                    height: 300,
                    child: TabBarView(
                      children: [
                        _buildGrid(_recent),
                        for (var pack in packs) _buildPackGrid(pack),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
