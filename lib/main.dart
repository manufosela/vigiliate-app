import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'notifications.dart';

Future<void> main() async {
  // `runZonedGuarded` catches asynchronous errors that escape the widget
  // tree (e.g. Future.error outside any await) so they end up in
  // Crashlytics instead of vanishing into the ether.
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp();

    // Forward Flutter framework errors to Crashlytics. In debug they also
    // surface in red overlays as usual; in release they go straight to
    // Crashlytics only (no report in debug to avoid noise).
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    // Platform-dispatcher catches errors from the Dart engine outside of
    // the widget tree (isolates, low-level callbacks).
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Do not collect crash reports while running locally — it would
    // pollute the dashboard with our own stack traces.
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);

    await NotificationService.init();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF171417),
        systemNavigationBarColor: Color(0xFF171417),
      ),
    );

    runApp(const VigilateApp());
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}
