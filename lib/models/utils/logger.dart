import 'package:logger/logger.dart';

/// Logger class for logging messages
var logger = Logger(
  filter: null,
  printer: PrettyPrinter(
    colors: true,
  ),
);