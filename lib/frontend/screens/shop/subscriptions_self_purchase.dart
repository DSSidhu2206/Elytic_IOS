import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum PurchaseType { none, self, gift }

class SubscriptionSelfPurchase {
  // Perks (keep in sync with ProductIds/subs)
  static List<String> getPerks(String? plan) {
    switch (plan) {
      case "Basic":
        return [
          "Daily coin reward (5 coins)",
          "Access to sending voice messages",
          "Free 2 Rare mystery boxes daily",
          "VIP badge",
        ];
      case "Plus":
        return [
          "All Basic perks",
          "Access to VIP rooms",
          "Daily coin reward (10 coins)",
          "Free Epic mystery box daily",
          "Unlock Plus-only stickers (Coming in future updates...)",
          "Priority support",
        ];
      case "Royalty":
        return [
          "All Plus perks",
          "Daily coin reward (25 coins)",
          "Royalty badge and unique border access",
          "Free Legendary mystery box daily",
          "VIP only chat bubble themes",
        ];
      default:
        return [];
    }
  }

  static void showSelfPurchaseDialog({
    required BuildContext context,
    required Map<String, dynamic> sub,
    required Color accent,
    required Map<String, ProductDetails> productDetailsMap,
    required User? currentUser,
  }) {
    bool _isPurchasing = false;
    String? _purchaseError;

    showDialog(
      context: context,
      barrierDismissible: !_isPurchasing,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (statefulContext, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: accent, width: 2),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              constraints: const BoxConstraints(maxWidth: 350),
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
                  if (sub.containsKey("duration"))
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Text(
                        "${sub["duration"]}".toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: accent.withAlpha(170),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (productDetailsMap[sub['id']] != null)
                    Text(
                      "Price: ${productDetailsMap[sub['id']]?.price}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                    ),
                  const SizedBox(height: 24),
                  if (_purchaseError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        _purchaseError!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: !_isPurchasing && productDetailsMap[sub['id']] != null
                          ? () async {
                        setDialogState(() {
                          _isPurchasing = true;
                          _purchaseError = null;
                        });

                        final localNavigator =
                        Navigator.of(statefulContext, rootNavigator: true);
                        final localScaffold = ScaffoldMessenger.of(statefulContext);

                        final bool available =
                        await InAppPurchase.instance.isAvailable();
                        if (!available) {
                          setDialogState(() {
                            _isPurchasing = false;
                            _purchaseError = "Store unavailable.";
                          });
                          if (localNavigator.canPop()) localNavigator.pop();
                          localScaffold.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "In-app purchases are not available right now."),
                            ),
                          );
                          return;
                        }

                        final ProductDetails? productDetails = productDetailsMap[sub['id']];
                        if (productDetails == null) return;

                        // ✅ Safe user check and token refresh
                        User? user = FirebaseAuth.instance.currentUser ??
                            await FirebaseAuth.instance.authStateChanges()
                                .firstWhere((u) => u != null, orElse: () => null);
                        if (user == null) {
                          setDialogState(() {
                            _isPurchasing = false;
                            _purchaseError = "Authentication required.";
                          });
                          return;
                        }
                        await user.getIdToken(true);

                        final PurchaseParam purchaseParam = PurchaseParam(
                          productDetails: productDetails,
                          applicationUserName: user.uid,
                        );
                        await InAppPurchase.instance.buyNonConsumable(
                          purchaseParam: purchaseParam,
                        );
                        if (localNavigator.canPop()) localNavigator.pop();
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
                      icon: _isPurchasing
                          ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator())
                          : const Icon(Icons.shopping_cart_rounded, color: Colors.white),
                      label: _isPurchasing
                          ? const Text("Processing...")
                          : const Text("Buy"),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}
