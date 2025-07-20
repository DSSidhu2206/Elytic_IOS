// lib/frontend/helpers/color_controller.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ColorController extends ChangeNotifier {
  Color _primaryColor = Colors.deepPurple;

  Color get primaryColor => _primaryColor;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ColorController() {
    _firestore.collection('config').doc('app_theme').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        final colorValue = data['color'];
        if (colorValue != null) {
          Color? newColor;

          if (colorValue is int) {
            newColor = Color(colorValue);
          } else if (colorValue is String) {
            // Remove 0x prefix if present and parse as hex integer
            final parsedInt = int.tryParse(colorValue.replaceFirst('0x', ''), radix: 16);
            if (parsedInt != null) {
              newColor = Color(parsedInt);
            }
          }

          if (newColor != null && newColor != _primaryColor) {
            _primaryColor = newColor;
            notifyListeners();
          }
        }
      }
    });
  }
}
