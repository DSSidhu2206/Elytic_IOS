// lib/constants/product_ids.dart

/// All product IDs and metadata for Google Play (and iOS) in-app purchases.
/// Usage:
///   - ProductIds.allProductIds for product details query
///   - ProductIds.getProductLabel(productId) for human-readable name

class ProductIds {
  // --- Coin Bundles ---
  static const List<Map<String, dynamic>> coinBundles = [
    {
      "id": "coin_1",
      "coins": 100,
      "bonus": 0,
      "label": "100 Coins"
    },
    {
      "id": "coin_2",
      "coins": 255,
      "bonus": 15,
      "label": "255 + 15 Bonus"
    },
    {
      "id": "coin_3",
      "coins": 610,
      "bonus": 50,
      "label": "610 + 50 Bonus"
    },
    {
      "id": "coin_4",
      "coins": 1450,
      "bonus": 200,
      "label": "1450 + 200 Bonus"
    },
    {
      "id": "coin_5",
      "coins": 2750,
      "bonus": 450,
      "label": "2750 + 450 Bonus"
    },
    {
      "id": "coin_6",
      "coins": 5050,
      "bonus": 820,
      "label": "5050 + 820 Bonus"
    },
  ];

  // --- Subscriptions: Now includes all durations as separate product IDs ---
  static const List<Map<String, dynamic>> subscriptions = [
    // Basic
    {
      "id": "basic_subscription",
      "name": "Basic (1 Month)",
      "plan": "Basic",
      "rarity": "common",
      "duration": "1 month",
    },
    {
      "id": "basic_3month",
      "name": "Basic (3 Months)",
      "plan": "Basic",
      "rarity": "common",
      "duration": "3 months",
    },
    {
      "id": "basic_6month",
      "name": "Basic (6 Months)",
      "plan": "Basic",
      "rarity": "common",
      "duration": "6 months",
    },
    {
      "id": "basic_12month",
      "name": "Basic (12 Months)",
      "plan": "Basic",
      "rarity": "common",
      "duration": "12 months",
    },
    // Plus
    {
      "id": "basic_plus_subscription",
      "name": "Basic Plus (1 Month)",
      "plan": "Plus",
      "rarity": "rare",
      "duration": "1 month",
    },
    {
      "id": "basic_plus_3month",
      "name": "Basic Plus (3 Months)",
      "plan": "Plus",
      "rarity": "rare",
      "duration": "3 months",
    },
    {
      "id": "basic_plus_6month",
      "name": "Basic Plus (6 Months)",
      "plan": "Plus",
      "rarity": "rare",
      "duration": "6 months",
    },
    {
      "id": "basic_plus_12month",
      "name": "Basic Plus (12 Months)",
      "plan": "Plus",
      "rarity": "rare",
      "duration": "12 months",
    },
    // Royalty
    {
      "id": "royalty_subscription",
      "name": "Royalty (1 Month)",
      "plan": "Royalty",
      "rarity": "legendary",
      "duration": "1 month",
    },
    {
      "id": "royalty_3month",
      "name": "Royalty (3 Months)",
      "plan": "Royalty",
      "rarity": "legendary",
      "duration": "3 months",
    },
    {
      "id": "royalty_6month",
      "name": "Royalty (6 Months)",
      "plan": "Royalty",
      "rarity": "legendary",
      "duration": "6 months",
    },
    {
      "id": "royalty_12month",
      "name": "Royalty (12 Months)",
      "plan": "Royalty",
      "rarity": "legendary",
      "duration": "12 months",
    },
  ];

  // --- Giftable Subscription Consumables (with durations) ---
  static const List<Map<String, dynamic>> giftConsumables = [
    // Basic
    {
      "id": "gift_basic_subscription",
      "name": "Gift Basic Subscription (1 Month)",
      "giftTier": "Basic",
      "rarity": "common",
      "duration": "1 month",
    },
    {
      "id": "gift_basic_3month",
      "name": "Gift Basic Subscription (3 Months)",
      "giftTier": "Basic",
      "rarity": "common",
      "duration": "3 months",
    },
    {
      "id": "gift_basic_6month",
      "name": "Gift Basic Subscription (6 Months)",
      "giftTier": "Basic",
      "rarity": "common",
      "duration": "6 months",
    },
    {
      "id": "gift_basic_12month",
      "name": "Gift Basic Subscription (12 Months)",
      "giftTier": "Basic",
      "rarity": "common",
      "duration": "12 months",
    },
    // Plus
    {
      "id": "gift_plus_subscription",
      "name": "Gift Plus Subscription (1 Month)",
      "giftTier": "Plus",
      "rarity": "rare",
      "duration": "1 month",
    },
    {
      "id": "gift_plus_3month",
      "name": "Gift Plus Subscription (3 Months)",
      "giftTier": "Plus",
      "rarity": "rare",
      "duration": "3 months",
    },
    {
      "id": "gift_plus_6month",
      "name": "Gift Plus Subscription (6 Months)",
      "giftTier": "Plus",
      "rarity": "rare",
      "duration": "6 months",
    },
    {
      "id": "gift_plus_12month",
      "name": "Gift Plus Subscription (12 Months)",
      "giftTier": "Plus",
      "rarity": "rare",
      "duration": "12 months",
    },
    // Royalty
    {
      "id": "gift_royalty_subscription",
      "name": "Gift Royalty Subscription (1 Month)",
      "giftTier": "Royalty",
      "rarity": "legendary",
      "duration": "1 month",
    },
    {
      "id": "gift_royalty_3month",
      "name": "Gift Royalty Subscription (3 Months)",
      "giftTier": "Royalty",
      "rarity": "legendary",
      "duration": "3 months",
    },
    {
      "id": "gift_royalty_6month",
      "name": "Gift Royalty Subscription (6 Months)",
      "giftTier": "Royalty",
      "rarity": "legendary",
      "duration": "6 months",
    },
    {
      "id": "gift_royalty_12month",
      "name": "Gift Royalty Subscription (12 Months)",
      "giftTier": "Royalty",
      "rarity": "legendary",
      "duration": "12 months",
    },
  ];

  // --- All Product IDs for easy product details query ---
  static Set<String> get allProductIds {
    final ids = <String>{};
    for (final b in coinBundles) {
      ids.add(b["id"]);
    }
    for (final s in subscriptions) {
      ids.add(s["id"]);
    }
    for (final g in giftConsumables) {
      ids.add(g["id"]);
    }
    return ids;
  }

  // --- Lookup for any productId's friendly label (for dialogs, receipts, etc) ---
  static String? getProductLabel(String productId) {
    for (final b in coinBundles) {
      if (b["id"] == productId) return b["label"];
    }
    for (final s in subscriptions) {
      if (s["id"] == productId) return s["name"];
    }
    for (final g in giftConsumables) {
      if (g["id"] == productId) return g["name"];
    }
    return null;
  }

  // Optionally, get plan name for extra UI display:
  static String? getSubscriptionPlan(String productId) {
    for (final s in subscriptions) {
      if (s["id"] == productId) return s["plan"];
    }
    for (final g in giftConsumables) {
      if (g["id"] == productId) return g["giftTier"];
    }
    return null;
  }
}
