import 'package:flutter/material.dart';

/// Global key that gives access to a single, app-wide [ScaffoldMessenger].
///
/// Any service (e.g. in-app notifications) can obtain the messenger with
///
/// ```dart
/// final messenger = rootMessengerKey.currentState;
/// ```
///
/// and then call `showSnackBar`, `showMaterialBanner`, etc.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
GlobalKey<ScaffoldMessengerState>();
