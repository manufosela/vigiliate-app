import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
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

  void _handleBridgeMessage(String message) async {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'google-sign-in') {
        final tokens = await GoogleAuthService.signIn();
        if (tokens != null) {
          final tokensJson = jsonEncode(tokens);
          _controller.runJavaScript(
            'window.__vigiliate_onNativeAuth($tokensJson);',
          );
        } else {
          _controller.runJavaScript(
            'window.__vigiliate_onNativeAuth(null);',
          );
        }
      } else if (type == 'google-sign-out') {
        await GoogleAuthService.signOut();
      } else {
        NotificationService.handleMessage(message);
      }
    } catch (_) {}
  }

  void _injectBridge() {
    _controller.runJavaScript('''
      window.__vigiliate_native = true;
      window.dispatchEvent(new CustomEvent('vigiliate-bridge-ready'));
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          _controller.goBack();
        }
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
