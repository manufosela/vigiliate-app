import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vigiliate_app/app.dart';

void main() {
  // Smoke test: VigilateApp itself is a stateless, trivial wrapper around a
  // WebViewScreen. Constructing and inspecting its MaterialApp without a full
  // pumpWidget avoids hitting the platform channels that would fail in a
  // host-only test environment.
  test('VigilateApp is a stateless widget and ships a dark MaterialApp', () {
    const app = VigilateApp();
    expect(app, isA<StatelessWidget>());

    final material = app.build(_NoContext()) as MaterialApp;
    expect(material.title, 'Vigiliate');
    expect(material.debugShowCheckedModeBanner, isFalse);
    expect(material.theme?.brightness, Brightness.dark);
    expect(material.home, isA<WebViewScreen>());
  });
}

/// A minimal BuildContext replacement for pure constructor-level assertions.
/// `VigilateApp.build` does not touch the context beyond passing it through to
/// `MaterialApp`, so a sentinel is enough.
class _NoContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
