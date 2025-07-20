// lib/frontend/widgets/common/custom_search_bar.dart

import 'package:flutter/material.dart';

class CustomSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const CustomSearchBar({
    Key? key,
    required this.controller,
    this.hintText = "Search...",
    this.onChanged,
    this.onClear,
  }) : super(key: key);

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: TextField(
        controller: widget.controller,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              widget.controller.clear();
              if (widget.onClear != null) widget.onClear!();
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[900]
              : Colors.grey[200],
        ),
        textInputAction: TextInputAction.search,
        onChanged: widget.onChanged,
      ),
    );
  }
}