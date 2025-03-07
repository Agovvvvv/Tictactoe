import 'logger.dart';

class ErrorHandler {
  static void handleError(String message, {Function(String)? onError}) {
    logger.e(message);
    onError?.call(message);
  }
}