import 'package:flutter/material.dart';
import 'package:elytic/frontend/utils/rarity_color.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:elytic/backend/services/friend_service.dart' show UserFriend, FriendService;
import 'package:elytic/constants/product_ids.dart';
import 'dart:async';

import 'subscriptions_self_purchase.dart';
import 'subscriptions_gift_purchase.dart';

class SubscriptionsPage extends StatefulWidget {
  final bool? showBackButton;
  const SubscriptionsPage({super.key, this.showBackButton});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  Map<String, ProductDetails> _productDetailsMap = {};
  bool _loading = true;
  List<UserFriend> _friends = [];
  bool _friendsLoading = true;
  User? _currentUser;
  int? _expandedPlanIndex; // Track which plan is expanded

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadProducts();
    _loadFriends();
  }

  Future<void> _loadCurrentUser() async {
    setState(() {
      _currentUser = FirebaseAuth.instance.currentUser;
    });
  }

  Future<void> _loadProducts() async {
    final ids = ProductIds.allProductIds;
    final resp = await InAppPurchase.instance.queryProductDetails(ids);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _productDetailsMap = {for (var pd in resp.productDetails) pd.id: pd};
    });
  }

  Future<void> _loadFriends() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _friends = [];
        _friendsLoading = false;
      });
      return;
    }
    try {
      final List<UserFriend> fetched = await FriendService.getFriendsList(user.uid);
      if (!mounted) return;
      setState(() {
        _friends = fetched;
        _friendsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _friends = [];
        _friendsLoading = false;
      });
    }
  }

  // Helper to get all durations for a plan
  List<Map<String, dynamic>> _getDurationsForPlan(Map<String, dynamic> plan) {
    final planName = plan['plan'];
    final rarity = plan['rarity'];
    // Find all subscription entries with same plan name (e.g., "Basic") and rarity
    return ProductIds.subscriptions
        .where((s) => s['plan'] == planName && s['rarity'] == rarity)
        .toList();
  }

  void _showPerksDialog(BuildContext context, Map<String, dynamic> sub, Color accent) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: accent, width: 2),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            constraints: const BoxConstraints(maxWidth: 350),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded, color: accent, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    "${sub["name"]}",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: accent,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: accent.withAlpha(18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    child: Column(
                      children: [
                        ...List.generate(
                          SubscriptionSelfPurchase.getPerks(sub["plan"]).length,
                              (i) => Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Icon(Icons.check_circle_rounded, size: 20, color: accent),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  SubscriptionSelfPurchase.getPerks(sub["plan"])[i],
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_productDetailsMap[sub['id']] != null)
                    Text(
                      "Price: ${_productDetailsMap[sub['id']]?.price}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _productDetailsMap[sub['id']] != null
                          ? () {
                        SubscriptionSelfPurchase.showSelfPurchaseDialog(
                          context: context,
                          sub: sub,
                          accent: accent,
                          productDetailsMap: _productDetailsMap,
                          currentUser: _currentUser,
                        );
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        textStyle: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      icon: const Icon(Icons.shopping_cart_rounded, color: Colors.white),
                      label: const Text("Buy"),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => SubscriptionGiftPurchase.showGiftDialog(
                        context: context,
                        sub: sub,
                        accent: accent,
                        friends: _friends,
                        friendsLoading: _friendsLoading,
                        productDetailsMap: _productDetailsMap,
                        currentUser: _currentUser,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent, width: 1.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      icon: Icon(Icons.card_giftcard, color: accent),
                      label: Text("Gift", style: TextStyle(color: accent)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool shouldShowBackButton = widget.showBackButton ?? false;

    // Only show one card per plan group (1 card for Basic, 1 for Plus, 1 for Royalty)
    // Find unique plans
    final List<Map<String, dynamic>> mainPlans = [];
    final seen = <String>{};
    for (final s in ProductIds.subscriptions) {
      final key = '${s['plan']}_${s['rarity']}';
      if (!seen.contains(key)) {
        seen.add(key);
        mainPlans.add(s);
      }
    }

    final Widget listView = ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: mainPlans.length,
      itemBuilder: (_, i) {
        final s = mainPlans[i];
        final Color accent = rarityColor(s["rarity"]);

        final isExpanded = _expandedPlanIndex == i;
        final durations = _getDurationsForPlan(s);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Main Plan Card (no price)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _expandedPlanIndex = isExpanded ? null : i;
                });
              },
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 5,
                shadowColor: accent,
                color: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: accent,
                    width: 2,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded,
                          color: Colors.white, size: 40),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          '${s["plan"]} Subscription',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Durations (only visible if expanded)
            if (isExpanded)
              Column(
                children: durations.map((durationSub) {
                  final durationId = durationSub['id'] as String;
                  final productDetails = _productDetailsMap[durationId];
                  final durationLabel = durationSub['duration'] ?? "Unknown";
                  return Padding(
                    padding: const EdgeInsets.only(left: 28, bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: productDetails != null
                          ? () {
                        _showPerksDialog(context, durationSub, accent);
                      }
                          : null,
                      child: Card(
                        elevation: 3,
                        color: accent.withAlpha(230),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: accent,
                            width: 1.3,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          child: Row(
                            children: [
                              const Icon(Icons.timer, color: Colors.white, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  durationLabel.toString().toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                productDetails?.price ?? "--",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
          ],
        );
      },
    );

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (shouldShowBackButton) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Subscriptions'),
          leading: const BackButton(),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 2,
        ),
        body: listView,
      );
    } else {
      return Material(
        child: listView,
      );
    }
  }
}
