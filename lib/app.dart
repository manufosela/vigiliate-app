import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'bridge.dart';
import 'google_auth.dart';
import 'notifications.dart';

const _appUrl = 'https://vigiliate.web.app';

class VigilateApp extends StatelessWidget {
  const VigilateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vigiliate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4944A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF171417))
      ..addJavaScriptChannel(
        'VigiliateBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _injectBridge(),
        ),
      )
      ..loadRequest(Uri.parse(_appUrl));
  }

  Future<void> _handleBridgeMessage(String message) async {
    final msg = BridgeMessage.tryParse(message);
    if (msg == null) return;

    switch (msg.type) {
      case BridgeMessageType.googleSignIn:
        final tokens = await GoogleAuthService.signIn();
        final payload = tokens == null ? 'null' : jsonEncode(tokens);
        await _controller
            .runJavaScript('window.__vigiliate_onNativeAuth($payload);');
      case BridgeMessageType.googleSignOut:
        await GoogleAuthService.signOut();
      case BridgeMessageType.queryNotificationPermission:
        await _emitPermissionStatus();
      default:
        await NotificationService.handleBridgeMessage(msg);
    }
  }

  Future<void> _emitPermissionStatus() async {
    final payload = jsonEncode({
      'notifications': NotificationService.notificationsGranted,
    });
    await _controller
        .runJavaScript('window.__vigiliate_onPermissionStatus($payload);');
  }

  Future<void> _injectBridge() async {
    final initialState = jsonEncode({
      'notificationsGranted': NotificationService.notificationsGranted,
    });
    await _controller.runJavaScript('''
      window.__vigiliate_native = true;
      window.__vigiliate_native_state = $initialState;
      window.dispatchEvent(new CustomEvent('vigiliate-bridge-ready', {
        detail: window.__vigiliate_native_state
      }));
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
          return;
        }
        // On the landing page there is nowhere to go back to inside the
        // WebView — honour the system gesture and close the app instead
        // of silently swallowing the event (which is what the scaffold did).
        await SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF171417),
        body: SafeArea(
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}
