// lib/frontend/widgets/shop/shop_detail_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:elytic/frontend/utils/rarity_color.dart';
import 'package:elytic/frontend/helpers/avatar_helper.dart'; // PATCH: Import avatar_helper
import 'buy_gift_button.dart';

class ShopDetailDialog extends StatelessWidget {
  final Map<String, dynamic> itemData;
  final String type; // 'pet', 'item', 'cosmetic', etc.

  const ShopDetailDialog({
    Key? key,
    required this.itemData,
    required this.type,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String name = itemData['name'] ?? "Unknown";
    final String rarity = itemData['rarity'] ?? "Common";
    final String iconUrl = itemData['iconUrl'] ?? "";
    final String description = itemData['description'] ?? '';
    final int coinPrice = itemData['coinPrice'] as int? ?? 0;

    // PATCH: Always use avatar_helper for image loading
    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image(
        image: getAvatarImageProvider(iconUrl),
        height: 168,
        width: 168,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          height: 168,
          width: 168,
          color: Colors.grey[300],
          child: const Icon(Icons.shopping_bag, size: 100),
        ),
      ),
    );

    final Color rarityBg = rarityColor(rarity);
    final bool isDefaultRarity = rarityBg == Colors.grey;
    final Color dialogBgColor = isDefaultRarity ? Colors.white : rarityBg;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: dialogBgColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            imageWidget,
            const SizedBox(height: 18),
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            Text(
              rarity,
              style: TextStyle(
                fontSize: 14,
                color: isDefaultRarity ? rarityColor(rarity) : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDefaultRarity ? Colors.black : Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 18),
            if (type == 'pet')
              PetBuyButton(itemData: itemData)
            else
              BuyGiftButton(petData: itemData),
          ],
        ),
      ),
    );
  }
}

// PATCH: Button with loading indicator for pets only
class PetBuyButton extends StatefulWidget {
  final Map<String, dynamic> itemData;
  const PetBuyButton({Key? key, required this.itemData}) : super(key: key);

  @override
  State<PetBuyButton> createState() => _PetBuyButtonState();
}

class _PetBuyButtonState extends State<PetBuyButton> {
  bool _isLoading = false;

  Future<void> _buyPet(BuildContext context) async {
    setState(() => _isLoading = true);
    final petId = widget.itemData['id'] as String;
    final coinPrice = widget.itemData['coinPrice'] as int? ?? 0;
    final callable = FirebaseFunctions.instance.httpsCallable('buyCosmetic');
    try {
      await callable(<String, dynamic>{'type': 'pet', 'id': petId});
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pet purchased successfully!')),
      );
    } on FirebaseFunctionsException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Purchase failed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coinPrice = widget.itemData['coinPrice'] as int? ?? 0;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _buyPet(context),
        child: _isLoading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Text('Buy for $coinPrice coins'),
      ),
    );
  }
}
