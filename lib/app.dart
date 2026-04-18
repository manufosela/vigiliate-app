import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'bridge.dart';
import 'google_auth.dart';
import 'notifications.dart';

const _appUrl = 'https://vigiliate.web.app';
const _backgroundColor = Color(0xFF171417);
const _brandSeed = Color(0xFFD4944A);

enum _WebLoadState { loading, ready, error }

class VigilateApp extends StatelessWidget {
  const VigilateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vigiliate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brandSeed,
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
  _WebLoadState _loadState = _WebLoadState.loading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_backgroundColor)
      ..addJavaScriptChannel(
        'VigiliateBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _setState(_WebLoadState.loading),
          onPageFinished: (_) async {
            await _injectBridge();
            _setState(_WebLoadState.ready);
          },
          onWebResourceError: (error) {
            // Ignore errors for sub-resources (images, analytics…) — only the
            // main-frame failure means we cannot show the app at all.
            if (error.isForMainFrame != false) {
              _setState(
                _WebLoadState.error,
                message: _describeError(error),
              );
            }
          },
          onHttpError: (error) {
            final code = error.response?.statusCode;
            if (code != null && code >= 500) {
              _setState(
                _WebLoadState.error,
                message: 'Error del servidor ($code). Inténtalo de nuevo.',
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_appUrl));
  }

  void _setState(_WebLoadState state, {String? message}) {
    if (!mounted) return;
    setState(() {
      _loadState = state;
      _errorMessage = message;
    });
  }

  Future<void> _retry() async {
    _setState(_WebLoadState.loading);
    await _controller.loadRequest(Uri.parse(_appUrl));
  }

  String _describeError(WebResourceError error) {
    switch (error.errorType) {
      case WebResourceErrorType.hostLookup:
      case WebResourceErrorType.connect:
      case WebResourceErrorType.timeout:
      case WebResourceErrorType.io:
        return 'No hay conexión con vigiliate.web.app. '
            'Revisa tu red e inténtalo de nuevo.';
      case WebResourceErrorType.unknown:
      case null:
        return error.description.isEmpty
            ? 'No se pudo cargar la aplicación.'
            : error.description;
      default:
        return error.description.isEmpty
            ? 'No se pudo cargar la aplicación.'
            : error.description;
    }
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
    // Re-check exact alarms: the user may have toggled them in Settings
    // after we last asked, and unlike notifications there is no callback.
    await NotificationService.refreshExactAlarmsPermission();
    final payload = jsonEncode({
      'notifications': NotificationService.notificationsGranted,
      'exactAlarms': NotificationService.exactAlarmsGranted,
    });
    await _controller
        .runJavaScript('window.__vigiliate_onPermissionStatus($payload);');
  }

  Future<void> _injectBridge() async {
    final initialState = jsonEncode({
      'notificationsGranted': NotificationService.notificationsGranted,
      'exactAlarmsGranted': NotificationService.exactAlarmsGranted,
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
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              Offstage(
                offstage: _loadState == _WebLoadState.error,
                child: WebViewWidget(controller: _controller),
              ),
              if (_loadState == _WebLoadState.loading)
                const _LoadingOverlay(),
              if (_loadState == _WebLoadState.error)
                _ErrorOverlay(message: _errorMessage, onRetry: _retry),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando Vigiliate…'),
          ],
        ),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, required this.onRetry});

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                message ?? 'No se pudo cargar Vigiliate.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
