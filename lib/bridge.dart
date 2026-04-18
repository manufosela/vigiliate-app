import 'dart:convert';

/// A message received from the PWA over the `VigiliateBridge` JavaScript channel.
///
/// The bridge contract is JSON strings with at least a `type` string discriminator.
/// Parsing is isolated here so it can be unit-tested without a WebView.
class BridgeMessage {
  const BridgeMessage({required this.type, required this.data});

  /// The `type` discriminator from the JSON payload (e.g. `google-sign-in`).
  final String type;

  /// Remaining top-level fields from the JSON payload (may be empty).
  final Map<String, dynamic> data;

  /// Parse a raw JSON string. Returns `null` if the string is not valid JSON,
  /// not a JSON object, or has no `type` string field.
  static BridgeMessage? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final type = decoded['type'];
      if (type is! String || type.isEmpty) return null;
      final data = Map<String, dynamic>.from(decoded)..remove('type');
      return BridgeMessage(type: type, data: data);
    } on FormatException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Extract a list of medication slots from a `schedule-alarms` message.
  /// Returns an empty list if the shape is wrong.
  List<Map<String, dynamic>> extractSlots() {
    final slots = data['slots'];
    if (slots is! List) return const [];
    return slots
        .whereType<Map<Object?, Object?>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }
}

/// Known bridge message types. Keeping them here prevents typos in callers.
abstract class BridgeMessageType {
  static const String googleSignIn = 'google-sign-in';
  static const String googleSignOut = 'google-sign-out';
  static const String scheduleAlarms = 'schedule-alarms';
  static const String cancelAlarms = 'cancel-alarms';
}
