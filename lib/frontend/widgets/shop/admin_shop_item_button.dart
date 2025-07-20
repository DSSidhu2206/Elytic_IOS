// lib/frontend/widgets/shop/admin_shop_item_button.dart

import 'package:flutter/material.dart';
import 'admin_add_item_dialog.dart';

class AddAdminShopItemButton extends StatelessWidget {
  final String shopTab;
  final int currentUserTier;

  const AddAdminShopItemButton({
    Key? key,
    required this.shopTab,
    required this.currentUserTier,
  }) : super(key: key);

  String get _buttonLabel {
    switch (shopTab) {
      case "pets":
        return "Add Pet to Shop (Admin)";
      case "items":
        return "Add Item to Shop (Admin)";
      case "avatar_borders":
        return "Add Avatar Border to Shop (Admin)";
      default:
        return "Add Item to Shop (Admin)";
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.add_box),
      label: Text(_buttonLabel),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(double.infinity, 52),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: () => showAdminAddItemDialog(
        context,
        shopTab: shopTab,
        currentUserTier: currentUserTier,
      ),
    );
  }
}
