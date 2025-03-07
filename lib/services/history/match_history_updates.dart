import 'dart:async';

/// Service for managing match history updates across the app
class MatchHistoryUpdates {
  static final StreamController<void> updates = StreamController<void>.broadcast();

  /// Notify listeners that match history has changed
  static void notifyUpdate() {
    updates.add(null);
  }

  /// Close the stream controller
  static void dispose() {
    updates.close();
  }
}
