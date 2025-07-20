// lib/backend/utils/shop_discounts.dart

class ShopDiscounts {
  // Example: returns discount percentage for a given cosmetic
  static double getCosmeticDiscount(String cosmeticId) {
    // TODO: implement your discount logic, maybe fetch from Firestore or local config
    // Example: return 0.15 for 15% discount
    return 0.0;
  }

  // Example: returns discounted price for a given base price
  static double getDiscountedPrice(double basePrice, double discount) {
    return (basePrice * (1 - discount)).toStringAsFixed(2) as double;
  }

// Can also add methods for subscription/coin pack promos, etc.
}
