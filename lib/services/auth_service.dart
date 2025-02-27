import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_account.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user account if logged in
  UserAccount? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    return UserAccount(
      id: user.uid,
      username: user.displayName ?? 'Player',
      email: user.email ?? '',
    );
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    print('Firebase Auth Error Code: ${e.code}'); // For debugging
    
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-email':
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'auth/invalid-email':
      case 'auth/user-not-found':
      case 'auth/wrong-password':
        return 'Email or password are not valid';
      case 'user-disabled':
      case 'auth/user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
      case 'auth/too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'operation-not-allowed':
      case 'auth/operation-not-allowed':
        return 'Login is not available at this time';
      case 'email-already-in-use':
      case 'auth/email-already-in-use':
        return 'This email is already registered';
      case 'weak-password':
      case 'auth/weak-password':
        return 'Please use a stronger password';
      case 'network-request-failed':
      case 'auth/network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'An error occurred: ${e.message ?? e.code}. Please try again';
    }
  }

  // Sign in with email and password
  Future<UserAccount> signInWithEmailAndPassword(String email, String password) async {
    try {
      // Sanitize email input
      final sanitizedEmail = _sanitizeInput(email).toLowerCase();
      
      final result = await _auth.signInWithEmailAndPassword(
        email: sanitizedEmail,
        password: password, // Don't sanitize password
      );
      final user = result.user;
      if (user == null) throw FirebaseAuthException(code: 'unknown', message: 'Sign in failed');

      return UserAccount(
        id: user.uid,
        username: user.displayName ?? 'Player',
        email: user.email ?? '',
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e));
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  String _sanitizeInput(String input) {
    // Remove any HTML tags
    input = input.replaceAll(RegExp(r"<[^>]*>"), "");
    // Remove any script tags and their contents
    input = input.replaceAll(RegExp(r"<script[^>]*>([\s\S]*?)</script>"), "");
    // Remove any potential SQL injection patterns - handle each character separately
    input = input.replaceAll("'", "")
                 .replaceAll("\"", "")
                 .replaceAll(";", "")
                 .replaceAll("--", "");
    // Trim whitespace
    input = input.trim();
    return input;
  }

  // Register with email and password
  Future<UserAccount> registerWithEmailAndPassword(String email, String password, String username) async {
    try {
      // Sanitize inputs
      final sanitizedEmail = _sanitizeInput(email).toLowerCase();
      final sanitizedUsername = _sanitizeInput(username);

      // Additional validation
      if (sanitizedUsername.isEmpty || sanitizedEmail.isEmpty) {
        throw Exception("Invalid input data");
      }
      final result = await _auth.createUserWithEmailAndPassword(
        email: sanitizedEmail,
        password: password,  // Don't sanitize password as it would affect its security
      );
      final user = result.user;
      if (user == null) throw FirebaseAuthException(code: 'unknown', message: 'Registration failed');

      // Update display name with sanitized username
      await user.updateDisplayName(sanitizedUsername);

      return UserAccount(
        id: user.uid,
        username: sanitizedUsername,
        email: sanitizedEmail,
      );
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    final sanitizedEmail = _sanitizeInput(email).toLowerCase();
    await _auth.sendPasswordResetEmail(email: sanitizedEmail);
  }

  // Update username
  Future<void> updateUsername(String newUsername) async {
    final sanitizedUsername = _sanitizeInput(newUsername);
    if (sanitizedUsername.isEmpty) {
      throw Exception('Username cannot be empty');
    }
    
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await user.updateDisplayName(sanitizedUsername);
  }

  // Update email
  Future<void> updateEmail(String newEmail) async {
    final sanitizedEmail = _sanitizeInput(newEmail).toLowerCase();
    if (sanitizedEmail.isEmpty) {
      throw Exception('Email cannot be empty');
    }
    
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await user.updateEmail(sanitizedEmail);
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await user.updatePassword(newPassword);
  }

  // Stream of auth state changes
  Stream<UserAccount?> get authStateChanges {
    return _auth.authStateChanges().map((user) {
      if (user == null) return null;
      return UserAccount(
        id: user.uid,
        username: user.displayName ?? 'Player',
        email: user.email ?? '',
      );
    });
  }
}
