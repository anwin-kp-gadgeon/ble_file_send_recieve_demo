import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LogService {
  static final LogService _instance = LogService._internal();

  factory LogService() {
    return _instance;
  }

  LogService._internal();

  File? _logFile;
  final String _logFileName = 'app_crash_logs.txt';

  Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/$_logFileName');
      if (!await _logFile!.exists()) {
        await _logFile!.create();
      }
      // Don't log initialization every time to avoid spam, or do it if needed
    } catch (e) {
      debugPrint('Failed to initialize LogService: $e');
    }
  }

  Future<void> log(String message) async {
    try {
      if (_logFile == null) await init();
      final timestamp = DateTime.now().toIso8601String();
      final logMessage = '[$timestamp] $message\n';
      // Write to file immediately (append). Blocking might be bad for performance if frequent,
      // but for crash logs it ensures data is saved before app dies.
      await _logFile!.writeAsString(
        logMessage,
        mode: FileMode.append,
        flush: true,
      );
      debugPrint(message);
    } catch (e) {
      debugPrint('Failed to write log: $e');
    }
  }

  Future<void> logError(Object error, StackTrace? stackTrace) async {
    final message = 'ERROR: $error\nSTACK TRACE:\n$stackTrace';
    await log(message);
  }

  Future<void> shareLogs() async {
    try {
      if (_logFile == null) await init();

      if (_logFile != null && await _logFile!.exists()) {
        // ignore: deprecated_member_use
        await Share.shareXFiles([
          XFile(_logFile!.path),
        ], text: 'App Crash Logs');
      } else {
        debugPrint("No log file to share");
      }
    } catch (e) {
      debugPrint('Failed to share logs: $e');
      // If we can't share, try to log that we couldn't share
      log('Failed to share logs: $e');
    }
  }

  Future<void> clearLogs() async {
    try {
      if (_logFile == null) await init();

      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
        await log('Logs cleared');
      }
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }
}
