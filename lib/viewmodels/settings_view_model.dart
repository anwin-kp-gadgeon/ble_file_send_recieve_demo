import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/ble_constants.dart';
import '../constants/app_strings.dart';

class SettingsViewModel extends ChangeNotifier {
  static const String _keyServiceUuid = 'service_uuid';
  static const String _keyFirmwareCharUuid = 'firmware_char_uuid';
  static const String _keyLogCharUuid = 'log_char_uuid';

  String _serviceUuid = BleConstants.serviceUuid;
  String _firmwareInputCharUuid = BleConstants.firmwareInputCharUuid;
  String _logOutputCharUuid = BleConstants.logOutputCharUuid;

  String get serviceUuid => _serviceUuid;
  String get firmwareInputCharUuid => _firmwareInputCharUuid;
  String get logOutputCharUuid => _logOutputCharUuid;

  bool _isLoading = false; // Start false to not block UI
  bool get isLoading => _isLoading;

  SettingsViewModel() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _isLoading = true;
    // Don't notify here to avoid triggering build/loading loop issues instantly
    // notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _serviceUuid =
          prefs.getString(_keyServiceUuid) ?? BleConstants.serviceUuid;
      _firmwareInputCharUuid =
          prefs.getString(_keyFirmwareCharUuid) ??
          BleConstants.firmwareInputCharUuid;
      _logOutputCharUuid =
          prefs.getString(_keyLogCharUuid) ?? BleConstants.logOutputCharUuid;
    } catch (e) {
      debugPrint("Error loading settings: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUuids({
    required String service,
    required String firmware,
    required String log,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    _serviceUuid = service.trim();
    _firmwareInputCharUuid = firmware.trim();
    _logOutputCharUuid = log.trim();

    await prefs.setString(_keyServiceUuid, _serviceUuid);
    await prefs.setString(_keyFirmwareCharUuid, _firmwareInputCharUuid);
    await prefs.setString(_keyLogCharUuid, _logOutputCharUuid);

    notifyListeners();
  }

  /// Validates a single UUID string. Returns null if valid, or error message.
  String? validateUuid(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.validationRequired;
    }
    if (value.length < 4) {
      return AppStrings.validationInvalidUuid;
    }
    return null;
  }

  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();

    _serviceUuid = BleConstants.serviceUuid;
    _firmwareInputCharUuid = BleConstants.firmwareInputCharUuid;
    _logOutputCharUuid = BleConstants.logOutputCharUuid;

    await prefs.remove(_keyServiceUuid);
    await prefs.remove(_keyFirmwareCharUuid);
    await prefs.remove(_keyLogCharUuid);

    notifyListeners();
  }
}
