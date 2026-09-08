import 'package:flutter/foundation.dart';

/// A saved motor reference belongs only to this app run and BLE connection.
class AlignmentSession {
  static final String _run = DateTime.now().microsecondsSinceEpoch.toString();
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static String get token => '$_run:${changes.value}';

  static void invalidate() => changes.value++;
}
