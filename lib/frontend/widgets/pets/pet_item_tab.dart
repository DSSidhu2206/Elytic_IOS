import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elytic/frontend/utils/rarity_color.dart'; // Import your rarityColor function

class PetItemTab extends StatefulWidget {
  final String userId;
  const PetItemTab({Key? key, required this.userId}) : super(key: key);

  @override
  State<PetItemTab> createState() => _PetItemTabState();
}

class _PetItemTabState extends State<PetItemTab> with AutomaticKeepAliveClientMixin {
  List<_UserItem> _items = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchInventoryAndItemData();
  }

  Future<void> _fetchInventoryAndItemData() async {
    setState(() => _loading = true);

    try {
      final userItemsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('inventory')
          .doc('items')
          .collection('item_inventory')
          .get();

      if (userItemsSnapshot.docs.isEmpty) {
        setState(() {
          _items = [];
          _loading = false;
        });
        return;
      }

      final List<_UserItem> loadedItems = [];

      for (final doc in userItemsSnapshot.docs) {
        final data = doc.data();
        final String itemId = doc.id; // Use document ID as item ID
        final int count = (data['count'] is int) ? data['count'] : 1;

        final itemDataDoc = await FirebaseFirestore.instance
            .collection('item_data')
            .doc(itemId)
            .get();

        if (!itemDataDoc.exists) continue;
        final itemData = itemDataDoc.data()!;
        final String name = itemData['name']?.toString() ?? 'Item';
        final String rarity = itemData['rarity']?.toString() ?? 'Common';
        final String assetUrl = itemData['assetUrl']?.toString() ?? 'assets/items/item_1.png';
        final String description = itemData['description']?.toString() ?? '';

        loadedItems.add(_UserItem(
          itemId: itemId,
          name: name,
          rarity: rarity,
          assetUrl: assetUrl,
          description: description,
          quantity: count,
        ));
      }

      setState(() {
        _items = loadedItems;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _items = [];
        _loading = false;
      });
    }
  }

  void _showItemOptions(BuildContext context, _UserItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(item.name),
                subtitle: Text('Rarity: ${item.rarity}'),
                trailing: item.quantity > 1
                    ? Text('x${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold))
                    : null,
              ),
              if ((item.rarity == 'Legendary' ||
                  item.rarity == 'Mythical' ||
                  item.rarity == 'Limited') &&
                  item.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    item.description,
                    style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for keep alive!
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No items in your inventory.'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      itemCount: _items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final item = _items[index];

        return GestureDetector(
          onTap: () => _showItemOptions(context, item),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      item.assetUrl,
                      height: 60,
                      width: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, _, __) => Container(
                        height: 60,
                        width: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.question_mark, size: 30),
                      ),
                    ),
                  ),
                  if (item.quantity > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        'x${item.quantity}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                item.rarity,
                style: TextStyle(fontSize: 11, color: rarityColor(item.rarity)),
                overflow: TextOverflow.ellipsis,
              ),
              // Removed bottom quantity badge per your request
            ],
          ),
        );
      },
    );
  }
}

class _UserItem {
  final String itemId;
  final String name;
  final String rarity;
  final String assetUrl;
  final String description;
  final int quantity;

  _UserItem({
    required this.itemId,
    required this.name,
    required this.rarity,
    required this.assetUrl,
    required this.description,
    required this.quantity,
  });
}
