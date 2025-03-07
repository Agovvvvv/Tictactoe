import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:developer' as developer;

class PresenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _heartbeatTimer;
  StreamSubscription? _authStateSubscription;

  // Singleton pattern
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  void initialize() {
    _authStateSubscription = _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _startTrackingPresence();
      } else {
        _stopTrackingPresence();
      }
    });
  }

  Future<void> _startTrackingPresence() async {
    if (_auth.currentUser == null) return;

    final userId = _auth.currentUser!.uid;
    final presenceRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('presence')
        .doc('status');

    // Update presence on start
    await _updatePresence(presenceRef);

    // Start heartbeat timer
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updatePresence(presenceRef);
    });
  }

  Future<void> _updatePresence(DocumentReference presenceRef) async {
    try {
      await presenceRef.set({
        'lastOnline': FieldValue.serverTimestamp(),
        'isOnline': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (e) {
      developer.log('Error updating presence: $e', error: e);
    }
  }

  void _stopTrackingPresence() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_auth.currentUser != null) {
      final userId = _auth.currentUser!.uid;
      final presenceRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('presence')
          .doc('status');

      // Update status to offline
      presenceRef.set({
        'lastOnline': FieldValue.serverTimestamp(),
        'isOnline': false,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true)).catchError((e) {
        developer.log('Error updating offline status: $e', error: e);
      });
    }
  }

  void dispose() {
    _stopTrackingPresence();
    _authStateSubscription?.cancel();
    _authStateSubscription = null;
  }
}
