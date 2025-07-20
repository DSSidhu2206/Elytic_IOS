// lib/frontend/widgets/shop/inventory/mystery_box_inventory_tab.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

class MysteryBoxesInventoryTab extends StatefulWidget {
  const MysteryBoxesInventoryTab({Key? key}) : super(key: key);

  @override
  State<MysteryBoxesInventoryTab> createState() => _MysteryBoxesInventoryTabState();
}

class _MysteryBoxesInventoryTabState extends State<MysteryBoxesInventoryTab> {
  String? _openingBoxId;
  Set<String> _openingAllBoxIds = {};

  Future<void> _openMysteryBox(String boxId, String boxName) async {
    setState(() => _openingBoxId = boxId);

    final functionCompleter = Completer<Map<String, dynamic>>();
    final animationCompleter = Completer<void>();

    // Start the Cloud Function call (in background)
    FirebaseFunctions.instance
        .httpsCallable('openMysteryBox')
        .call({'mystery_box_id': boxId}).then((result) {
      final data = result.data as Map<String, dynamic>?;
      if (data == null || data['rewards'] == null) {
        functionCompleter.completeError(Exception('No rewards returned.'));
      } else {
        functionCompleter.complete(data);
      }
    }).catchError((e) {
      functionCompleter.completeError(e);
    });

    // Show the animation dialog, await animationCompleter
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _MysteryBoxOpeningAnimationDialog(onComplete: () {
        if (!animationCompleter.isCompleted) animationCompleter.complete();
      }),
    );

    // Wait for both to complete
    try {
      final results = await Future.wait([
        animationCompleter.future,
        functionCompleter.future,
      ]);
      final data = results[1] as Map<String, dynamic>;
      if (!mounted) return;

      // Show rewards dialog after both complete
      final rewards = (data['rewards'] as List)
          .map<Map<String, dynamic>>((raw) {
        if (raw is Map<String, dynamic>) return raw;
        if (raw is Map) return Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v)));
        throw Exception('Reward is not a map: $raw');
      }).toList();

      final grouped = _groupRewards(rewards);

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('You opened $boxName!'),
            content: SizedBox(
              width: 320,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: grouped.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, i) {
                  final entry = grouped.entries.elementAt(i);
                  final reward = entry.value['reward'] as Map<String, dynamic>;
                  final count = entry.value['count'] as int;
                  final type = (reward['type'] ?? '').toString().replaceAll('_', ' ');
                  final meta = reward['meta'] is Map<String, dynamic>
                      ? reward['meta'] as Map<String, dynamic>
                      : reward['meta'] is Map
                      ? Map<String, dynamic>.from(
                    (reward['meta'] as Map).map((k, v) => MapEntry(k.toString(), v)),
                  )
                      : <String, dynamic>{};
                  final name = meta['name'] ?? type;
                  final icon = meta['iconUrl'] ?? meta['assetUrl'] ?? '';
                  Widget iconWidget;
                  if (icon.isNotEmpty) {
                    if (icon.toString().startsWith('http')) {
                      iconWidget = CachedNetworkImage(
                        imageUrl: icon,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget: (c, e, s) => const Icon(Icons.card_giftcard),
                        placeholder: (c, s) =>
                        const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                      );
                    } else {
                      iconWidget = Image.asset(icon, width: 44, height: 44, fit: BoxFit.cover);
                    }
                  } else {
                    iconWidget = const Icon(Icons.card_giftcard);
                  }
                  return ListTile(
                    leading: iconWidget,
                    title: Text("$name${count > 1 ? " x$count" : ""}"),
                    subtitle: Text(type.toString()),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open box: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open box: $e')),
      );
    } finally {
      setState(() => _openingBoxId = null);
    }
  }

  Future<void> _openAllMysteryBoxes(String boxId, String boxName, int count) async {
    if (count <= 0) return;
    setState(() => _openingAllBoxIds = {..._openingAllBoxIds, boxId});

    final functionCompleter = Completer<Map<String, dynamic>>();
    final animationCompleter = Completer<void>();

    // Call the cloud function (single multi-open call!)
    FirebaseFunctions.instance
        .httpsCallable('openAllMysteryBoxes')
        .call({'mystery_box_id': boxId, 'quantity': count}).then((result) {
      final data = result.data as Map<String, dynamic>?;
      if (data == null || data['rewards'] == null) {
        functionCompleter.completeError(Exception('No rewards returned.'));
      } else {
        functionCompleter.complete(data);
      }
    }).catchError((e) {
      functionCompleter.completeError(e);
    });

    // Show animation ONCE
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _MysteryBoxOpeningAnimationDialog(onComplete: () {
        if (!animationCompleter.isCompleted) animationCompleter.complete();
      }),
    );

    // Wait for both to complete
    try {
      final results = await Future.wait([
        animationCompleter.future,
        functionCompleter.future,
      ]);
      final data = results[1] as Map<String, dynamic>;
      if (!mounted) return;

      // Flatten all rewards from all boxes
      final List allRewardsRaw = (data['rewards'] as List?) ?? [];
      final List<Map<String, dynamic>> allRewards =
      allRewardsRaw
          .expand<Map<String, dynamic>>((boxReward) {
        if (boxReward is List) {
          return boxReward.map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r as Map));
        } else if (boxReward is Map) {
          return [Map<String, dynamic>.from(boxReward as Map)];
        } else {
          return [];
        }
      }).toList();

      final grouped = _groupRewards(allRewards);

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('You opened $count $boxName${count > 1 ? "s" : ""}!'),
            content: SizedBox(
              width: 320,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: grouped.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, i) {
                  final entry = grouped.entries.elementAt(i);
                  final reward = entry.value['reward'] as Map<String, dynamic>;
                  final count = entry.value['count'] as int;
                  final type = (reward['type'] ?? '').toString().replaceAll('_', ' ');
                  final meta = reward['meta'] is Map<String, dynamic>
                      ? reward['meta'] as Map<String, dynamic>
                      : reward['meta'] is Map
                      ? Map<String, dynamic>.from(
                    (reward['meta'] as Map).map((k, v) => MapEntry(k.toString(), v)),
                  )
                      : <String, dynamic>{};
                  final name = meta['name'] ?? type;
                  final icon = meta['iconUrl'] ?? meta['assetUrl'] ?? '';
                  Widget iconWidget;
                  if (icon.isNotEmpty) {
                    if (icon.toString().startsWith('http')) {
                      iconWidget = CachedNetworkImage(
                        imageUrl: icon,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget: (c, e, s) => const Icon(Icons.card_giftcard),
                        placeholder: (c, s) =>
                        const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                      );
                    } else {
                      iconWidget = Image.asset(icon, width: 44, height: 44, fit: BoxFit.cover);
                    }
                  } else {
                    iconWidget = const Icon(Icons.card_giftcard);
                  }
                  return ListTile(
                    leading: iconWidget,
                    title: Text("$name${count > 1 ? " x$count" : ""}"),
                    subtitle: Text(type.toString()),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open boxes: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open boxes: $e')),
      );
    } finally {
      setState(() => _openingAllBoxIds = {..._openingAllBoxIds}..remove(boxId));
    }
  }

  /// Groups identical rewards and counts them.
  /// The 'identity' of a reward is based on type+meta['name']+meta['iconUrl']/['assetUrl'] for user experience.
  Map<String, Map<String, dynamic>> _groupRewards(List<Map<String, dynamic>> rewards) {
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final reward in rewards) {
      final type = reward['type'] ?? '';
      final meta = reward['meta'] ?? {};
      final metaMap = meta is Map<String, dynamic>
          ? meta
          : meta is Map
          ? Map<String, dynamic>.from(meta)
          : <String, dynamic>{};
      final name = metaMap['name'] ?? '';
      final icon = metaMap['iconUrl'] ?? metaMap['assetUrl'] ?? '';
      // Unique key for grouping
      final key = '$type|$name|$icon';
      if (!grouped.containsKey(key)) {
        grouped[key] = {'reward': reward, 'count': 1};
      } else {
        grouped[key]!['count'] += 1;
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Not signed in'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('mystery_boxes')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('You have no mystery boxes.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final boxId = docs[i].id;
            final name = data['name'] as String? ?? 'Mystery Box';
            final count = data['count'] as int? ?? 1;
            final iconUrl = data['iconUrl'] as String?;
            final isLoading = _openingBoxId == boxId;
            final isOpeningAll = _openingAllBoxIds.contains(boxId);

            Widget iconWidget;
            if (iconUrl != null && iconUrl.isNotEmpty) {
              if (iconUrl.toString().startsWith('http')) {
                iconWidget = CachedNetworkImage(
                  imageUrl: iconUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget: (c, e, s) =>
                      Image.asset('assets/mystery_box.png', width: 48, height: 48),
                  placeholder: (c, s) =>
                  const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                );
              } else {
                iconWidget = Image.asset(iconUrl, width: 48, height: 48, fit: BoxFit.cover);
              }
            } else {
              iconWidget = Image.asset('assets/mystery_box.png', width: 48, height: 48);
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4),
                child: Row(
                  children: [
                    // Icon
                    iconWidget,
                    const SizedBox(width: 16),
                    // Name & Count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 3),
                          Text('Count: $count'),
                        ],
                      ),
                    ),
                    // Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: (count > 0 && !isLoading && !isOpeningAll)
                                ? () => _openMysteryBox(boxId, name)
                                : null,
                            child: isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Open'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: (count > 1 && !isLoading && !isOpeningAll)
                                ? () => _openAllMysteryBoxes(boxId, name, count)
                                : null,
                            child: isOpeningAll
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Open All'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Separate Widget to handle the animation and its controller properly.
class _MysteryBoxOpeningAnimationDialog extends StatefulWidget {
  final VoidCallback onComplete;

  const _MysteryBoxOpeningAnimationDialog({required this.onComplete});

  @override
  State<_MysteryBoxOpeningAnimationDialog> createState() => _MysteryBoxOpeningAnimationDialogState();
}

class _MysteryBoxOpeningAnimationDialogState extends State<_MysteryBoxOpeningAnimationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _hasCompleted = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.all(24),
      content: SizedBox(
        width: 220,
        height: 220,
        child: Lottie.asset(
          'assets/animations/mystery_box_opening_animation.json',
          controller: _controller,
          repeat: false,
          onLoaded: (composition) {
            _controller
              ..duration = composition.duration
              ..forward().whenComplete(() {
                if (!_hasCompleted) {
                  _hasCompleted = true;
                  widget.onComplete();
                  Navigator.of(context).pop();
                }
              });
          },
        ),
      ),
    );
  }
}
