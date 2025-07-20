// lib/frontend/screens/shop/mystery_boxes_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:elytic/frontend/widgets/common/loading_overlay.dart';
import '../../utils/rarity_color.dart'; // Import your rarity_color.dart

class MysteryBoxesTab extends StatefulWidget {
  const MysteryBoxesTab({Key? key}) : super(key: key);

  @override
  State<MysteryBoxesTab> createState() => _MysteryBoxesTabState();
}

class _MysteryBoxesTabState extends State<MysteryBoxesTab> {
  bool _isLoading = false;

  String? _getUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  String _getBoxIconAsset(String rarity) {
    switch (rarity) {
      case 'Legendary':
        return 'assets/icons/legendary_mystery_box.png';
      case 'Epic':
        return 'assets/icons/epic_mystery_box.png';
      case 'Rare':
      default:
        return 'assets/icons/rare_mystery_box.png';
    }
  }

  Future<List<Map<String, dynamic>>> _fetchBoxesFromRotation() async {
    final rotationDoc = await FirebaseFirestore.instance
        .collection('shop_rotations')
        .doc('mystery_boxes')
        .get();
    final rotationList =
    (rotationDoc.data()?['currentRotation'] ?? []) as List?;
    if (rotationList == null || rotationList.isEmpty) return [];

    final List<String> ids = rotationList.map((e) => e.toString()).toList();
    List<Map<String, dynamic>> allBoxes = [];

    for (var i = 0; i < ids.length; i += 10) {
      final batch =
      ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap = await FirebaseFirestore.instance
          .collection('mystery_box_data')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      allBoxes.addAll(snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }));
    }

    allBoxes.sort((a, b) => ids
        .indexOf(a['id'].toString())
        .compareTo(ids.indexOf(b['id'].toString())));
    return allBoxes;
  }

  Future<int> _getUserCoins(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final count = snap.data()?['coins'];
      if (count is int) return count;
      if (count is double) return count.toInt();
      return 0;
    } catch (e) {
      return 0;
    }
  }

  void _showNotEnoughCoinsPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Not enough coins'),
        content: const Text('You don’t have enough coins to buy/gift this box.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed('/shop/coins');
            },
            child: const Text('Buy now!'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBuyGiftDialog(
      BuildContext context,
      String userId,
      String boxId,
      String name,
      String rarity,
      int price,
      String? description,
      ) async {
    final userCoins = await _getUserCoins(userId);

    int quantity = 1;
    final maxQuantity = userCoins ~/ price;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool localLoading = false;
        String? errorMsg;
        final cardColor = rarityColor(rarity);

        Future<void> handleBuy() async {
          if (localLoading) return;
          if (maxQuantity <= 0) {
            _showNotEnoughCoinsPopup(context);
            return;
          }
          setState(() => _isLoading = true);
          try {
            final HttpsCallable callable =
            FirebaseFunctions.instance.httpsCallable('buyCosmetic');
            await callable.call(<String, dynamic>{
              'type': 'mystery_box',
              'id': boxId,
              'quantity': quantity,
            });
            setState(() => _isLoading = false);
            Navigator.of(dialogCtx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Purchase successful!'),
                backgroundColor: Colors.green,
              ),
            );
            setState(() {});
          } catch (e) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Purchase failed. Try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }

        Future<void> handleGift() async {
          Navigator.of(dialogCtx).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Gifting is not implemented yet!'),
                backgroundColor: Colors.orange),
          );
        }

        return StatefulBuilder(builder: (statefulCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: cardColor,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cost: $price coins',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (description != null && description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      description,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (maxQuantity > 0)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: (quantity == 1 || localLoading)
                              ? null
                              : () => setDialogState(() => quantity = 1),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          child: const Text('Min'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                          onPressed: quantity > 1 && !localLoading
                              ? () => setDialogState(() => quantity--)
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '$quantity',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                          onPressed: quantity < maxQuantity && !localLoading
                              ? () => setDialogState(() => quantity++)
                              : null,
                        ),
                        TextButton(
                          onPressed: (quantity == maxQuantity || localLoading)
                              ? null
                              : () => setDialogState(() => quantity = maxQuantity),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          child: const Text('Max'),
                        ),
                      ],
                    ),
                  ),
                if (maxQuantity > 0)
                  Text(
                    'Total: ${quantity * price} coins\nYou have: $userCoins coins',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                if (maxQuantity <= 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Not enough coins.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(errorMsg!, style: const TextStyle(color: Colors.white)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: localLoading ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: localLoading || maxQuantity <= 0 ? null : handleGift,
                child: const Text('Gift', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: localLoading || maxQuantity <= 0 ? null : handleBuy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.13),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Buy'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _getUserId();

    return Stack(
      children: [
        userId == null
            ? const Center(child: Text('Sign in to view mystery boxes.'))
            : FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchBoxesFromRotation(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final boxes = snapshot.data ?? [];
            if (boxes.isEmpty) {
              return const Center(child: Text('No mystery boxes available right now.'));
            }
            int crossAxisCount = 2;
            final width = MediaQuery.of(context).size.width;
            if (width >= 1100) {
              crossAxisCount = 4;
            } else if (width >= 700) {
              crossAxisCount = 3;
            }

            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 24,
              mainAxisSpacing: 30,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
              children: [
                for (final box in boxes)
                  GestureDetector(
                    onTap: () => _showBuyGiftDialog(
                      context,
                      userId,
                      box['id'] ?? '',
                      box['name'] ?? '',
                      box['rarity'] ?? 'Rare',
                      // PATCH: Use real backend price from coinPrice
                      (box['coinPrice'] is int)
                          ? box['coinPrice'] as int
                          : (box['coinPrice'] is double)
                          ? (box['coinPrice'] as double).toInt()
                          : 10,
                      (box['description'] ?? '').toString(),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 22,
                          child: Text(
                            (box['name'] ?? '').toString(),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FractionallySizedBox(
                          widthFactor: 0.75,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Image.asset(
                              _getBoxIconAsset(box['rarity'] ?? 'Rare'),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        LoadingOverlay(
          isVisible: _isLoading,
          loadingText: "Processing your purchase...",
        ),
      ],
    );
  }
}
