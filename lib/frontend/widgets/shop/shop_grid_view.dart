// lib/frontend/widgets/shop/shop_grid_view.dart

import 'package:flutter/material.dart';

class ShopGridView extends StatelessWidget {
  final int crossAxisCount;
  final IndexedWidgetBuilder itemBuilder;
  final int itemCount;
  final double topPadding;

  const ShopGridView({
    Key? key,
    required this.crossAxisCount,
    required this.itemBuilder,
    required this.itemCount,
    this.topPadding = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.only(top: topPadding),
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemBuilder: itemBuilder,
    );
  }
}
