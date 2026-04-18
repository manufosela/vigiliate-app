import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF171417),
      systemNavigationBarColor: Color(0xFF171417),
    ),
  );
  runApp(const VigilateApp());
}
