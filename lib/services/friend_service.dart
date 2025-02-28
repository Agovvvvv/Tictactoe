import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../exceptions/friend_service_exception.dart';
import 'dart:developer' as developer;

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper method to get user data
  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  // Get current user's friends
  Stream<List<Map<String, dynamic>>> getFriends() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .snapshots()
        .handleError((error) {
          developer.log('Error fetching friends: $error', error: error);
          return [];
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<List<Map<String, dynamic>>> searchUsers(String username) async {
  if (username.isEmpty) return [];

  final currentUserId = _auth.currentUser?.uid;
  if (currentUserId == null) return [];

  try {
    // Step 1: Search for users whose username starts with the search term
    final querySnapshot = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: username)
        .where('username', isLessThan: username + 'z')
        .get();

    // Step 2: Get the current user's friends list
    final friendsSnapshot = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .get();

    // Extract friend IDs from the friends list
    final friendIds = friendsSnapshot.docs.map((doc) => doc.id).toList();

    // Step 3: Filter out users who are already friends
    return querySnapshot.docs
        .where((doc) => doc.id != currentUserId) // Exclude current user
        .where((doc) => !friendIds.contains(doc.id)) // Exclude friends
        .map((doc) => {
              'id': doc.id,
              'username': doc.data()['username'],
            })
        .toList();
  } catch (e) {
    developer.log('Error searching users: $e', error: e);
    throw FriendServiceException('Failed to search users: ${e.toString()}');
  }
}

  // Send friend request
  Future<void> sendFriendRequest(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw FriendServiceException('Not authenticated');

    try {
      // Get current user's data
      final currentUserData = await _getUserData(currentUserId);
      if (currentUserData == null || currentUserData['username'] == null) {
        throw FriendServiceException('Current user data not found');
      }

      // Add to target user's friend requests
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('friendRequests')
          .doc(currentUserId)
          .set({
        'username': currentUserData['username'],
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending'
      });

      developer.log('Friend request sent to $targetUserId');
    } catch (e) {
      developer.log('Failed to send friend request: $e', error: e);
      throw FriendServiceException('Failed to send friend request: ${e.toString()}');
    }
  }

  // Get friend requests
  Stream<List<Map<String, dynamic>>> getFriendRequests() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('friendRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .handleError((error) {
          developer.log('Error fetching friend requests: $error', error: error);
          return [];
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'senderId': doc.id,  // Ensure senderId is always present
                  ...doc.data()
                })
            .toList());
  }

  // Accept friend request
  Future<void> acceptFriendRequest(String senderId) async {
    if (senderId.isEmpty) throw FriendServiceException('Invalid sender ID');

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw FriendServiceException('Not authenticated');

    try {
      // Get both users' data
      final senderData = await _getUserData(senderId);
      final currentUserData = await _getUserData(currentUserId);

      if (senderData == null || currentUserData == null ||
          senderData['username'] == null || currentUserData['username'] == null) {
        throw FriendServiceException('Invalid user data');
      }

      // Verify the friend request exists
      final requestDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .doc(senderId)
          .get();

      if (!requestDoc.exists) {
        throw FriendServiceException('Friend request not found');
      }

      final requestData = requestDoc.data();
      if (requestData == null || requestData['status'] != 'pending') {
        throw FriendServiceException('Invalid friend request status');
      }

      // Use a batch for atomic operations
      final batch = _firestore.batch();

      // Add the friend to current user's list
      final currentUserFriendRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(senderId);

      batch.set(currentUserFriendRef, {
        'username': senderData['username'],
        'addedAt': FieldValue.serverTimestamp(),
        'id': senderId,
      });

      // Update current user's friendIds array
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      batch.update(currentUserRef, {
        'friendIds': FieldValue.arrayUnion([senderId]),
      });

      // Add current user to sender's friends list
      final senderFriendRef = _firestore
          .collection('users')
          .doc(senderId)
          .collection('friends')
          .doc(currentUserId);

      batch.set(senderFriendRef, {
        'username': currentUserData['username'],
        'addedAt': FieldValue.serverTimestamp(),
        'id': currentUserId,
      });

      // Update sender's friendIds array
      final senderRef = _firestore.collection('users').doc(senderId);
      batch.update(senderRef, {
        'friendIds': FieldValue.arrayUnion([currentUserId]),
      });

      // Delete the friend request
      final requestRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .doc(senderId);

      batch.delete(requestRef);

      // Commit the batch
      await batch.commit();

      developer.log('Friend request accepted from $senderId');
    } catch (e) {
      developer.log('Failed to accept friend request: $e', error: e);
      throw FriendServiceException('Failed to accept friend request: ${e.toString()}');
    }
  }

  // Reject friend request
  Future<void> rejectFriendRequest(String senderId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw FriendServiceException('Not authenticated');

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friendRequests')
          .doc(senderId)
          .update({'status': 'rejected'});

      developer.log('Friend request rejected from $senderId');
    } catch (e) {
      developer.log('Failed to reject friend request: $e', error: e);
      throw FriendServiceException('Failed to reject friend request: ${e.toString()}');
    }
  }

  // Delete friend
  Future<void> deleteFriend(String friendId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw FriendServiceException('Not authenticated');

    try {
      // Use a batch to ensure atomic operations
      final batch = _firestore.batch();

      // Remove friend from current user's friends list
      final currentUserFriendRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(friendId);
      batch.delete(currentUserFriendRef);

      // Update current user's friendIds array
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      batch.update(currentUserRef, {
        'friendIds': FieldValue.arrayRemove([friendId]),
      });

      // Remove current user from friend's friends list
      final friendUserRef = _firestore
          .collection('users')
          .doc(friendId)
          .collection('friends')
          .doc(currentUserId);
      batch.delete(friendUserRef);

      // Update friend's friendIds array
      final friendRef = _firestore.collection('users').doc(friendId);
      batch.update(friendRef, {
        'friendIds': FieldValue.arrayRemove([currentUserId]),
      });

      // Commit the batch
      await batch.commit();

      developer.log('Friend $friendId deleted');
    } catch (e) {
      developer.log('Failed to delete friend: $e', error: e);
      throw FriendServiceException('Failed to delete friend: ${e.toString()}');
    }
  }
}