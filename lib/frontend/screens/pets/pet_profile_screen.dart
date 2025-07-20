// lib/frontend/screens/pet_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../utils/rarity_color.dart';
import '../../../backend/services/pet_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PetProfileScreen extends StatefulWidget {
  final String userId;
  final String petId;      // numeric or string ID matching Firestore doc
  final String petName;    // Not used after patch, all name from pet_data
  final String petAvatar;  // Not used after patch, all iconUrl from pet_data
  final String? nickname;
  final bool isCurrentUser;
  final String currentUserId;
  final int currentUserTier;
  final String currentUserUsername;

  const PetProfileScreen({
    Key? key,
    required this.userId,
    required this.petId,
    required this.petName,
    required this.petAvatar,
    this.nickname,
    required this.isCurrentUser,
    required this.currentUserId,
    required this.currentUserTier,
    required this.currentUserUsername,
  }) : super(key: key);

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  PetDisplayInfo? _petInfo;
  bool _isLoading = true;
  bool _isPetting = false;
  bool _petOnCooldown = false;
  int _cooldownSeconds = 0;
  bool _isGiving = false;
  List<Map<String, dynamic>> _inventoryItems = [];
  bool _loadingInventory = false;

  @override
  void initState() {
    super.initState();
    _fetchPetData();
    _fetchPetCooldown();
    _fetchInventory();
  }

  Future<void> _fetchPetData() async {
    setState(() => _isLoading = true);
    try {
      final petInfo = await PetService.fetchMainPet(widget.userId, forceRefresh: true);

      if (petInfo == null || petInfo.petId != widget.petId) {
        setState(() {
          _petInfo = null;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _petInfo = petInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _petInfo = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPetCooldown() async {
    setState(() {
      _petOnCooldown = false;
      _cooldownSeconds = 0;
    });

    try {
      final result = await FirebaseFunctions.instance.httpsCallable('getPetCooldown').call({
        'ownerUserId': widget.userId,
        'petId': widget.petId,
        'pettorUserId': widget.currentUserId,
      });
      final data = Map<String, dynamic>.from(result.data ?? {});
      final int cooldownHours = (data['cooldownHours'] is int)
          ? data['cooldownHours']
          : int.tryParse(data['cooldownHours'].toString()) ?? 0;

      if (cooldownHours > 0) {
        setState(() {
          _petOnCooldown = true;
          _cooldownSeconds = cooldownHours * 3600;
        });
      }
    } catch (_) {
      // silently fail cooldown fetch
    }
  }

  Future<void> _onPet(BuildContext ctx) async {
    setState(() => _isPetting = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('petPet').call({
        'ownerUserId': widget.userId,
        'petId': widget.petId,
        'pettorUserId': widget.currentUserId,
        'pettorUsername': widget.currentUserUsername,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You greeted the companion!")),
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please come back later!")),
        );
      } else if (e.code == 'not-found') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Companion not found.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to greet companion: ${e.message}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to greet companion: $e")),
      );
    } finally {
      setState(() => _isPetting = false);
    }
  }

  Future<void> _fetchInventory() async {
    setState(() {
      _loadingInventory = true;
      _inventoryItems = [];
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .collection('items')
          .get()
          .timeout(const Duration(seconds: 10));
      final ids = <String>[];
      final counts = <String, int>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final int count = data['count'] is int
            ? data['count']
            : int.tryParse(data['count'].toString()) ?? 0;
        if (count <= 0) continue;
        ids.add(doc.id);
        counts[doc.id] = count;
      }
      final futures = ids.map((id) => FirebaseFirestore.instance
          .collection('item_data')
          .doc(id)
          .get());
      final metaSnaps = await Future.wait(futures);

      final enriched = <Map<String, dynamic>>[];
      for (var metaSnap in metaSnaps) {
        final id = metaSnap.id;
        final meta = metaSnap.data() ?? {};
        enriched.add({
          'itemId':       id,
          'itemName':     meta['name']     ?? '',
          'itemRarity':   meta['rarity']   ?? '',
          'itemAssetUrl': meta['assetUrl'] ?? '',
          'count':        counts[id]       ?? 0,
        });
      }

      setState(() {
        _inventoryItems = enriched;
        _loadingInventory = false;
      });
    } catch (e) {
      setState(() {
        _inventoryItems = [];
        _loadingInventory = false;
      });
    }
  }

  void _onGiveItem(BuildContext context) {
    if (_isGiving) return;
    _showGiveItemDialog(context);
  }

  void _showGiveItemDialog(BuildContext context) {
    if (_loadingInventory) {
      showDialog(
        context: context,
        builder: (ctx) => const AlertDialog(
          title: Text('Give Item'),
          content: SizedBox(
            height: 64,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
      return;
    }
    if (_inventoryItems.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => const AlertDialog(
          title: Text('Give Item'),
          content: Text('You have no items to give.'),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Give Item'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _inventoryItems.length,
            itemBuilder: (context, idx) {
              final item = _inventoryItems[idx];
              Widget iconWidget;
              if (item['itemAssetUrl'] != null && item['itemAssetUrl'].toString().isNotEmpty) {
                if (item['itemAssetUrl'].toString().startsWith('assets/')) {
                  iconWidget = Image.asset(
                    item['itemAssetUrl'],
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const Icon(Icons.widgets),
                  );
                } else {
                  iconWidget = CachedNetworkImage(
                    imageUrl: item['itemAssetUrl'],
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    errorWidget: (c, e, s) => const Icon(Icons.widgets),
                    placeholder: (c, s) => const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  );
                }
              } else {
                iconWidget = const Icon(Icons.widgets, size: 40);
              }
              return ListTile(
                leading: iconWidget,
                title: Text(item['itemName'] ?? 'Item'),
                subtitle: item['itemRarity'] != null && item['itemRarity'].toString().isNotEmpty
                    ? Text(item['itemRarity'])
                    : null,
                trailing: Text('x${item['count']}'),
                onTap: () {
                  Navigator.pop(context);
                  _showGiftMessageDialog(context, item);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showGiftMessageDialog(BuildContext context, Map<String, dynamic> item) {
    final TextEditingController _msgController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gift Message (optional)'),
        content: TextField(
          controller: _msgController,
          maxLength: 60,
          decoration: const InputDecoration(
            hintText: "Add a message (optional)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isGiving
                ? null
                : () {
              Navigator.pop(ctx);
              _giveItemToPet(item, _msgController.text.trim());
            },
            child: const Text('Send Gift'),
          ),
        ],
      ),
    );
  }

  Future<void> _giveItemToPet(Map<String, dynamic> item, String message) async {
    setState(() => _isGiving = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('giveItemToPet')
          .call({
        'userId': widget.userId,
        'petId': widget.petId,
        'giverUserId': widget.currentUserId,
        'giverUsername': widget.currentUserUsername,
        'itemId': item['itemId'] ?? '',
        'message': message,
      });
      final data = Map<String, dynamic>.from(result.data ?? {});
      if (data['xp'] != null && data['level'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'You gave ${item['itemName'] ?? 'item'}! +${data['xpAmount'] ?? data['xp']} XP!'),
          backgroundColor: Colors.green,
        ));
        await _fetchPetData();
        await _fetchInventory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Item given, but no XP info.'),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Failed to give item: $e"),
        backgroundColor: Colors.red,
      ));
    }
    setState(() => _isGiving = false);
  }

  Future<void> _openEditPetScreen(BuildContext context) async {
    final result = await Navigator.of(context).pushNamed(
      '/editPetProfile',
      arguments: {
        'userId': widget.userId,
        'petId': widget.petId,
        'petName': _petInfo?.name ?? "",
        'petAvatar': _petInfo?.iconUrl ?? "",
        'nickname': _petInfo?.nickname ?? "",
      },
    );
    if (result != null) {
      await _fetchPetData();
    }
  }

  void _openPetGallery(BuildContext context) {
    Navigator.of(context).pushNamed('/pets');
  }

  String _formatCooldown(int seconds) {
    if (seconds <= 0) return "";
    if (seconds < 60) return "$seconds seconds";
    final mins = (seconds / 60).floor();
    final secs = seconds % 60;
    if (mins < 60) return "$mins min${mins > 1 ? 's' : ''}${secs > 0 ? ' $secs sec' : ''}";
    final hours = (mins / 60).floor();
    final minsLeft = mins % 60;
    return "$hours h${hours > 1 ? 's' : ''}${minsLeft > 0 ? ' $minsLeft min' : ''}";
  }

  Widget _buildCardBackground(BuildContext context) {
    final cardUrl = _petInfo?.cardUrl ?? '';
    if (cardUrl.isEmpty) return Container(color: Colors.grey[100]);
    if (cardUrl.startsWith('assets/')) {
      return Image.asset(
        cardUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return CachedNetworkImage(
      imageUrl: cardUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorWidget: (c, e, s) => Container(color: Colors.grey[100]),
      placeholder: (c, s) => Container(color: Colors.grey[100]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final petRarity = _petInfo?.rarity ?? 'common';
    final petRarityColor = rarityColor(petRarity);
    final petLevel = _petInfo?.level ?? 1;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _petInfo?.name ?? "Companion",
          style: TextStyle(
            color: petRarityColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.isCurrentUser)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: "Edit Companion",
              onPressed: () => _openEditPetScreen(context),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildCardBackground(context)),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black54,
                  ],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SizedBox(height: 600),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Level: ",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: petRarityColor,
                          ),
                        ),
                        Text(
                          "$petLevel",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: petRarityColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.touch_app_outlined),
                        label: Text(
                          _isPetting
                              ? "Poking..."
                              : _petOnCooldown
                              ? "On Cooldown"
                              : "Greet",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: petRarityColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        ),
                        onPressed: (!_isPetting && !_petOnCooldown)
                            ? () async {
                          await _onPet(context);
                          await _fetchPetCooldown();
                        }
                            : null,
                      ),
                      const SizedBox(width: 22),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.card_giftcard_outlined),
                        label: _isGiving
                            ? const Text(
                          "Gifting...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                            : const Text(
                          "Give Item",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: petRarityColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                          elevation: 2,
                        ),
                        onPressed: _isGiving ? null : () => _onGiveItem(context),
                      ),
                    ],
                  ),
                  if (_petOnCooldown)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        "You can pet again in ${_formatCooldown(_cooldownSeconds)}.",
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
