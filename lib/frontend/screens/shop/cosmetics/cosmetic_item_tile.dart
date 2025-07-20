// lib/frontend/screens/shop/cosmetics/cosmetic_item_tile.dart

import 'package:flutter/material.dart';
import 'cosmetics_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:elytic/frontend/widgets/profile/bubble_preview_widget.dart';
import 'package:elytic/frontend/utils/rarity_color.dart';
import 'package:cached_network_image/cached_network_image.dart';

Future<Map<String, dynamic>> getCurrentUserData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {};
  final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  return doc.data() ?? {};
}

class CosmeticItemTile extends StatefulWidget {
  final CosmeticItem item;
  final bool owned; // NEW: passed owned status from parent

  const CosmeticItemTile({
    Key? key,
    required this.item,
    this.owned = false, // default false if not passed
  }) : super(key: key);

  @override
  State<CosmeticItemTile> createState() => _CosmeticItemTileState();
}

class _CosmeticItemTileState extends State<CosmeticItemTile> {
  int tier = 0;
  int? _coinPrice;
  String? _imageUrlOverride;
  String? _rarityOverride;
  String? _nameOverride;
  bool _buying = false;
  bool _gifting = false;

  @override
  void initState() {
    super.initState();
    _loadUserTier();
    _fetchPrices();
  }

  Future<void> _loadUserTier() async {
    final data = await getCurrentUserData();
    setState(() {
      tier = data['tier'] ?? 0;
    });
  }

  Future<void> _fetchPrices() async {
    try {
      late DocumentSnapshot doc;
      if (widget.item.category == 'avatar_borders') {
        doc = await FirebaseFirestore.instance.collection('avatar_border_data').doc(widget.item.id).get();
      } else if (widget.item.category == 'chat_bubbles') {
        doc = await FirebaseFirestore.instance.collection('chat_bubble_data').doc(widget.item.id).get();
      } else if (widget.item.category == 'badges') {
        doc = await FirebaseFirestore.instance.collection('badge_data').doc(widget.item.id).get();
      } else {
        doc = await FirebaseFirestore.instance.collection('shopItems').doc(widget.item.id).get();
      }
      final data = doc.data() as Map<String, dynamic>? ?? {};
      setState(() {
        _coinPrice = (data['coinPrice'] is int)
            ? data['coinPrice']
            : int.tryParse(data['coinPrice']?.toString() ?? '') ?? null;
        _imageUrlOverride = data['image_url'] ?? null;
        _rarityOverride = data['rarity'] ?? "Common";
        _nameOverride = data['name'] ?? null;
      });
    } catch (_) {
      setState(() {
        _coinPrice = null;
        _imageUrlOverride = null;
        _rarityOverride = "Common";
        _nameOverride = null;
      });
    }
  }

  // ----------- BUY COSMETIC FLOW ---------------
  void _showBuyDialog(BuildContext context) {
    final String rarity = _rarityOverride ?? "Common";
    final Color textColor = rarityColor(rarity);
    final String name = _nameOverride ?? widget.item.name;
    final String coinPrice = _coinPrice?.toString() ?? widget.item.priceCoins.toString();

    Widget previewWidget;
    if (_imageUrlOverride != null && _imageUrlOverride!.isNotEmpty) {
      previewWidget = CachedNetworkImage(
        imageUrl: _imageUrlOverride!,
        height: 54,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => const Icon(Icons.image),
        placeholder: (_, __) => const SizedBox(height: 54, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      );
    } else if (widget.item.category == 'chat_bubbles' && widget.item.codeId != null) {
      previewWidget = SizedBox(
        height: 54,
        child: bubblePreviewWidget(widget.item.codeId!),
      );
    } else if (widget.item.imagePath.isNotEmpty) {
      if (widget.item.imagePath.startsWith('http')) {
        previewWidget = CachedNetworkImage(
          imageUrl: widget.item.imagePath,
          height: 54,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => const Icon(Icons.image),
          placeholder: (_, __) => const SizedBox(height: 54, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        );
      } else {
        previewWidget = Image.asset(
          widget.item.imagePath,
          height: 54,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.image),
        );
      }
    } else {
      previewWidget = const Icon(Icons.image, size: 44);
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: SizedBox(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  previewWidget,
                  const SizedBox(height: 12),
                  Text(
                    "Buy $name",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buying
                      ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: CircularProgressIndicator(),
                  )
                      : ElevatedButton.icon(
                    icon: Icon(Icons.monetization_on, color: textColor),
                    label: Text('Buy for $coinPrice Coins', style: TextStyle(color: textColor)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: textColor.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      foregroundColor: textColor,
                    ),
                    onPressed: () async {
                      setDialogState(() => _buying = true);
                      try {
                        final type = widget.item.category == 'avatar_borders'
                            ? 'avatar_border'
                            : widget.item.category == 'chat_bubbles'
                            ? 'chat_bubble'
                            : widget.item.category == 'mystery_boxes'
                            ? 'mystery_box'
                            : widget.item.category == 'pets'
                            ? 'pet'
                            : widget.item.category == 'badges'
                            ? 'badge'
                            : 'item';
                        await FirebaseFunctions.instance.httpsCallable('buyCosmetic').call({
                          'type': type,
                          'id': widget.item.id,
                          'quantity': 1,
                        });
                        setState(() {
                          // Ownership handled by parent, so just UI update here
                        });
                        setDialogState(() => _buying = false);
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Purchased $name for $coinPrice coins!')),
                        );
                      } on FirebaseFunctionsException catch (e) {
                        setDialogState(() => _buying = false);
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.message ?? 'Purchase failed!')),
                        );
                      } catch (e) {
                        setDialogState(() => _buying = false);
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Purchase failed: $e')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------- GIFT COSMETIC FLOW ---------------
  void _showGiftDialog(BuildContext context) async {
    final String rarity = _rarityOverride ?? "Common";
    final Color textColor = rarityColor(rarity);
    final String name = _nameOverride ?? widget.item.name;
    final String coinPrice = _coinPrice?.toString() ?? widget.item.priceCoins.toString();

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Gift $name",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  icon: Icon(Icons.monetization_on, color: textColor),
                  label: Text('Gift for $coinPrice Coins', style: TextStyle(color: textColor)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: textColor.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    foregroundColor: textColor,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    final selectedUser = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _UserSearchDialog(rarity: rarity),
    );
    if (selectedUser == null || selectedUser['id'] == null) return;

    setState(() => _gifting = true);
    try {
      final type = widget.item.category == 'avatar_borders'
          ? 'avatar_border'
          : widget.item.category == 'chat_bubbles'
          ? 'chat_bubble'
          : widget.item.category == 'mystery_boxes'
          ? 'mystery_box'
          : widget.item.category == 'pets'
          ? 'pet'
          : widget.item.category == 'badges'
          ? 'badge'
          : 'item';
      await FirebaseFunctions.instance.httpsCallable('giftToUser').call({
        'receiverId': selectedUser['id'],
        'gifts': [
          {
            'type': type,
            'id': widget.item.id,
          }
        ],
      });
      setState(() => _gifting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gifted $name to ${selectedUser['username'] ?? selectedUser['id']}!')),
      );
    } on FirebaseFunctionsException catch (e) {
      setState(() => _gifting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Gift failed!')),
      );
    } catch (e) {
      setState(() => _gifting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gift failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget previewWidget;
    if (_imageUrlOverride != null && _imageUrlOverride!.isNotEmpty) {
      previewWidget = CachedNetworkImage(
        imageUrl: _imageUrlOverride!,
        height: 50,
        width: 50,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => const Icon(Icons.image, size: 28),
        placeholder: (_, __) => const SizedBox(height: 50, width: 50, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      );
    } else if (widget.item.category == 'chat_bubbles' && widget.item.codeId != null) {
      previewWidget = SizedBox(
        height: 50,
        child: bubblePreviewWidget(widget.item.codeId!),
      );
    } else if (widget.item.imagePath.isNotEmpty) {
      if (widget.item.imagePath.startsWith('http')) {
        previewWidget = CachedNetworkImage(
          imageUrl: widget.item.imagePath,
          height: 50,
          width: 50,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => const Icon(Icons.image, size: 28),
          placeholder: (_, __) => const SizedBox(height: 50, width: 50, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        );
      } else {
        previewWidget = Image.asset(
          widget.item.imagePath,
          height: 50,
          width: 50,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 28),
        );
      }
    } else {
      previewWidget = const Icon(Icons.image, size: 48);
    }

    final String rarity = _rarityOverride ?? "Common";
    final Color textColor = rarityColor(rarity);

    // Use owned passed from parent directly, no internal listeners here
    final isOwned = widget.owned;

    return _buildCosmeticTile(context, previewWidget, isOwned, textColor);
  }

  Widget _buildCosmeticTile(BuildContext context, Widget previewWidget, bool isOwned, Color textColor) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            previewWidget,
            const SizedBox(height: 8),
            Text(
              _nameOverride ?? widget.item.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 24,
                  child: ElevatedButton(
                    onPressed: isOwned ? null : () => _showBuyDialog(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(30, 24),
                    ),
                    child: _buying
                        ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                      isOwned ? 'Owned' : 'Buy',
                      style: TextStyle(fontSize: 12, color: textColor),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 24,
                  child: OutlinedButton(
                    onPressed: _gifting ? null : () => _showGiftDialog(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(30, 24),
                    ),
                    child: _gifting
                        ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Gift', style: TextStyle(fontSize: 12, color: textColor)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- User Search Dialog using Firestore (friends by default, live search for anyone) ---

class _UserSearchDialog extends StatefulWidget {
  final String rarity;
  const _UserSearchDialog({Key? key, required this.rarity}) : super(key: key);

  @override
  State<_UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends State<_UserSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _loading = false;
  bool _searched = false;
  String _searchTerm = '';

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final term = _searchController.text.trim();
    if (term.isEmpty) {
      _loadFriends();
    } else {
      _runUserSearch(term);
    }
  }

  Future<void> _loadFriends() async {
    setState(() {
      _loading = true;
      _searched = false;
      _searchTerm = '';
    });

    final friendsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('friends')
        .get();

    final friendIds = friendsSnap.docs.map((doc) => doc.id).toList();
    if (friendIds.isEmpty) {
      setState(() {
        _searchResults = [];
        _loading = false;
        _searched = false;
      });
      return;
    }
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: friendIds)
        .get();

    setState(() {
      _searchResults = usersSnap.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .where((user) => user['id'] != _currentUserId)
          .toList();
      _loading = false;
      _searched = false;
    });
  }

  Future<void> _runUserSearch(String term) async {
    setState(() {
      _loading = true;
      _searched = true;
      _searchTerm = term.trim();
    });

    final q = term.trim().toLowerCase();
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('username_lowercase')
        .startAt([q])
        .endAt([q + '\uf8ff'])
        .limit(20)
        .get();

    setState(() {
      _searchResults = snap.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .where((user) => user['id'] != _currentUserId)
          .toList();
      _loading = false;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = rarityColor(widget.rarity);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 340,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select recipient', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search username...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  height: 180,
                  child: _searchResults.isEmpty
                      ? Center(
                    child: Text(
                      _searched && _searchTerm.isNotEmpty ? "No users found." : "No friends found.",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (ctx, i) {
                      final user = _searchResults[i];
                      Widget avatarWidget;
                      if (user['avatarUrl'] != null && (user['avatarUrl'] as String).isNotEmpty) {
                        if ((user['avatarUrl'] as String).startsWith('http')) {
                          avatarWidget = CircleAvatar(
                            backgroundImage: CachedNetworkImageProvider(user['avatarUrl']),
                          );
                        } else {
                          avatarWidget = CircleAvatar(
                            backgroundImage: AssetImage(user['avatarUrl']),
                          );
                        }
                      } else if (user['avatarPath'] != null && (user['avatarPath'] as String).isNotEmpty) {
                        avatarWidget = CircleAvatar(
                          backgroundImage: AssetImage(user['avatarPath']),
                        );
                      } else {
                        avatarWidget = const CircleAvatar(child: Icon(Icons.person));
                      }
                      return ListTile(
                        leading: avatarWidget,
                        title: Text(user['username'] ?? user['email'] ?? 'Unknown'),
                        onTap: () => Navigator.pop(context, user),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
