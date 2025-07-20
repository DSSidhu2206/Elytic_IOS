import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:elytic/backend/services/friend_service.dart' show UserFriend, FriendService;
import 'package:elytic/backend/services/search_usernames.dart' as user_search;
import 'package:elytic/constants/product_ids.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CoinsPage extends StatefulWidget {
  const CoinsPage({super.key});

  @override
  State<CoinsPage> createState() => _CoinsPageState();
}

class _CoinsPageState extends State<CoinsPage> {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  Map<String, ProductDetails> _productDetailsMap = {};
  bool _loading = true;

  List<UserFriend> _friends = [];
  bool _friendsLoading = true;

  final Map<String, String> _pendingGiftReceiverIds = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadFriends();
    _initPurchaseListener();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final ids = ProductIds.coinBundles.map((e) => e['id'] as String).toSet();
    final resp = await _iap.queryProductDetails(ids);
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

  void _initPurchaseListener() {
    _subscription = _iap.purchaseStream.listen((purchases) async {
      for (var purchase in purchases) {
        try {
          if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.pending) {
            final receiverId = _pendingGiftReceiverIds[purchase.productID] ?? FirebaseAuth.instance.currentUser?.uid ?? "";
            await _verifyAndCompletePurchase(purchase, receiverId);
            _pendingGiftReceiverIds.remove(purchase.productID);
          } else if (purchase.status == PurchaseStatus.error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Purchase error: ${purchase.error?.message ?? "Unknown error"}')),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Purchase handling error: $e')),
            );
          }
        }
      }
    }, onError: (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase stream error: $error')),
        );
      }
    });
  }

  Future<void> _verifyAndCompletePurchase(PurchaseDetails purchase, String receiverId) async {
    if (purchase.pendingCompletePurchase) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in')),
          );
        }
        return;
      }

      try {

        await FirebaseAuth.instance.currentUser?.getIdToken(true); // PATCH: force ID token refresh

        final callable = FirebaseFunctions.instance.httpsCallable('verifyPlayPurchaseAndGrant');
        final response = await callable.call(<String, dynamic>{
          'productId': purchase.productID,
          'purchaseToken': purchase.verificationData.serverVerificationData,
          'isSubscription': false,
          'receiverId': receiverId,
        });

        if (response.data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Purchase successful! ${response.data['coinsAdded'] ?? ''} coins added.')),
            );
          }
          await _iap.completePurchase(purchase);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Purchase verification failed')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Purchase verification error: $e')),
          );
        }
      }
    }
  }

  void _showGiftDialog(BuildContext context, int coins, String productId) {
    final TextEditingController searchController = TextEditingController();
    UserFriend? selectedFriend;
    List<UserFriend> searchResults = [];
    bool isSearching = false;

    bool isValidRecipient() {
      if (selectedFriend != null) return true;
      if (searchController.text.trim().isEmpty) return false;
      return searchResults.any((f) =>
      f.username.toLowerCase() == searchController.text.trim().toLowerCase());
    }

    Future<void> performSearch(String query, StateSetter setDialogState) async {
      if (query.trim().isEmpty) {
        setDialogState(() {
          searchResults = [];
          isSearching = false;
          selectedFriend = null;
        });
        return;
      }
      setDialogState(() {
        isSearching = true;
      });
      try {
        final results = await user_search.searchUsernames(query.trim());
        setDialogState(() {
          searchResults = results
              .map((m) => UserFriend(
            userId: m['id'] as String,
            username: m['username'] as String? ?? '',
            avatarUrl: m['avatarUrl'] as String? ?? '',
          ))
              .toList();
          isSearching = false;
        });
      } catch (e) {
        setDialogState(() {
          searchResults = [];
          isSearching = false;
        });
      }
    }

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final productDetails = _productDetailsMap[productId];

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text("Gift $coins Coins"),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 400, // Adjust max height to prevent overflow
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_friendsLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(),
                          ),
                        if (!_friendsLoading)
                          Wrap(
                            spacing: 8,
                            children: _friends
                                .map(
                                  (f) => GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedFriend = f;
                                    searchController.text = f.username;
                                    searchResults = [];
                                  });
                                },
                                child: Chip(
                                  avatar: f.avatarUrl != null && f.avatarUrl!.isNotEmpty
                                      ? CircleAvatar(
                                    backgroundImage: NetworkImage(f.avatarUrl!),
                                    radius: 14,
                                  )
                                      : const CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.grey,
                                    child: Icon(Icons.person, size: 16, color: Colors.white),
                                  ),
                                  label: Text(f.username),
                                  backgroundColor: Colors.grey[200],
                                ),
                              ),
                            )
                                .toList(),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            labelText: "Enter username or user ID",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            setDialogState(() {
                              selectedFriend = null;
                            });
                            performSearch(v, setDialogState);
                          },
                        ),
                        if (isSearching)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: CircularProgressIndicator(),
                          ),
                        if (!isSearching && searchResults.isNotEmpty)
                          SizedBox(
                            height: 150,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: searchResults.length,
                              itemBuilder: (context, index) {
                                final user = searchResults[index];
                                return ListTile(
                                  leading: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                      ? CircleAvatar(
                                    backgroundImage: NetworkImage(user.avatarUrl!),
                                  )
                                      : const CircleAvatar(
                                    backgroundColor: Colors.grey,
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                  title: Text(user.username),
                                  onTap: () {
                                    setDialogState(() {
                                      selectedFriend = user;
                                      searchController.text = user.username;
                                      searchResults = [];
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: (productDetails == null || !isValidRecipient())
                      ? null
                      : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context, rootNavigator: true);

                    // PATCH: Ensure user is authenticated and token is refreshed before purchase
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser == null) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text("You must be logged in to purchase.")),
                      );
                      return;
                    }
                    await currentUser.getIdToken(true);

                    final bool available = await _iap.isAvailable();
                    if (!available) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text("In-app purchases are not available right now.")),
                      );
                      return;
                    }
                    final receiverId = selectedFriend?.userId ?? searchController.text.trim();

                    final purchaseParam = PurchaseParam(productDetails: productDetails);
                    _pendingGiftReceiverIds[productDetails.id] = receiverId;
                    await _iap.buyConsumable(
                      purchaseParam: purchaseParam,
                      autoConsume: false,
                    );
                    if (navigator.canPop()) {
                      navigator.pop();
                    }
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          "Gift purchase initiated for $receiverId!",
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: productDetails != null ? Text("Gift (${productDetails.price})") : const Text("Gift"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: ProductIds.coinBundles.length,
      itemBuilder: (_, i) {
        final b = ProductIds.coinBundles[i];
        final int coins = b["coins"] as int;
        final int bonus = b["bonus"] as int;
        final String productId = b["id"] as String;

        final productDetails = _productDetailsMap[productId];

        final bool hasBonus = bonus > 0;
        final bool isBestValue = i == ProductIds.coinBundles.length - 1;

        // For bonus percent info:
        final int effectiveCoins = coins + bonus;
        final ProductDetails? baseProductDetails = _productDetailsMap[ProductIds.coinBundles[0]["id"]];
        final double? baseRawPrice = baseProductDetails?.rawPrice;
        final double? thisRawPrice = productDetails?.rawPrice;

        final int? baseCoins = ProductIds.coinBundles[0]["coins"] is int ? ProductIds.coinBundles[0]["coins"] as int : null;
        final double? baseCoinsPerPrice = (baseCoins != null && baseRawPrice != null && baseRawPrice > 0) ? baseCoins / baseRawPrice : null;
        final double? coinsPerPrice = (thisRawPrice != null && thisRawPrice > 0) ? effectiveCoins / thisRawPrice : null;
        final double percentExtra = (hasBonus && coinsPerPrice != null && baseCoinsPerPrice != null) ? ((coinsPerPrice / baseCoinsPerPrice) - 1) * 100 : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 20),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "$coins Coins",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (isBestValue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Best Value",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      productDetails != null ? productDetails.price : "--",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                if (hasBonus)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, left: 2.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "+$bonus bonus",
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                if (hasBonus && percentExtra > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0, left: 2.0),
                    child: Text(
                      "${percentExtra.toStringAsFixed(1)}% more coins vs smallest bundle",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Divider(height: 24, thickness: 1, color: Colors.grey[300]),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          onPressed: productDetails == null
                              ? null
                              : () async {
                            final messenger = ScaffoldMessenger.of(context);

                            // PATCH: Ensure user is authenticated and token is refreshed before purchase
                            final currentUser = FirebaseAuth.instance.currentUser;
                            if (currentUser == null) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text("You must be logged in to purchase.")),
                              );
                              return;
                            }
                            await currentUser.getIdToken(true);

                            final bool available = await _iap.isAvailable();
                            if (!available) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text("In-app purchases are not available right now.")),
                              );
                              return;
                            }
                            final purchaseParam = PurchaseParam(productDetails: productDetails);
                            await _iap.buyConsumable(
                              purchaseParam: purchaseParam,
                              autoConsume: true,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Buy"),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          onPressed: () => _showGiftDialog(context, coins, productId),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black,
                            elevation: 0,
                          ),
                          child: const Text("Gift"),
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
  }
}
