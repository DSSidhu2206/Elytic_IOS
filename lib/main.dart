import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:overlay_support/overlay_support.dart';
import 'frontend/app/elytic_root.dart';

// Export navigatorKey and scaffoldMessengerKey so elytic_root.dart can import and assign them
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.debug, // Change to deviceCheck/appAttest if/when you go iOS production
  );

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (details.stack != null) {
    }
  };

  runApp(
    OverlaySupport.global(
      child: const ElyticRoot(),
    ),
  );
}
