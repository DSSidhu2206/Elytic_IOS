// lib/frontend/widgets/shop/admin_shop_image_upload.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class AdminShopImageUpload extends StatefulWidget {
  final String label;
  final void Function(Uint8List? bytes, String? fileName) onPicked;

  const AdminShopImageUpload({
    Key? key,
    required this.label,
    required this.onPicked,
  }) : super(key: key);

  @override
  State<AdminShopImageUpload> createState() => _AdminShopImageUploadState();
}

class _AdminShopImageUploadState extends State<AdminShopImageUpload> {
  Uint8List? _bytes;
  String? _fileName;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;

    setState(() {
      _bytes = file.bytes;
      _fileName = file.name;
    });
    widget.onPicked(_bytes, _fileName);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
              _fileName == null ? 'No ${widget.label} selected' : '${widget.label} selected!'),
        ),
        IconButton(
          icon: const Icon(Icons.upload_file),
          onPressed: _pickFile,
          tooltip: 'Pick ${widget.label} image',
        ),
      ],
    );
  }
}
