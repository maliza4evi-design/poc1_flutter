import 'package:logging/logging.dart';

final Logger _logger = Logger('PoC1A');

void setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final time = record.time.toIso8601String();
    final level = record.level.name;
    final message = record.message;
    final error = record.error != null ? '\nError: ${record.error}' : '';
    final stack = record.stackTrace != null ? '\nStack: ${record.stackTrace}' : '';
    print('[$time] [$level] $message$error$stack');
  });
}

void logInfo(String message) => _logger.info(message);
void logWarning(String message) => _logger.warning(message);
void logSevere(String message, [Object? error, StackTrace? stackTrace]) => 
    _logger.severe(message, error, stackTrace);
void logFine(String message) => _logger.fine(message);