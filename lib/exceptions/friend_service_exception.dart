// friend_service_exception.dart
class FriendServiceException implements Exception {
  final String message;
  FriendServiceException(this.message);

  @override
  String toString() => 'FriendServiceException: $message';
}