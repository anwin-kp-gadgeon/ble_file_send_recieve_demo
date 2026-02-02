import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanViewModel extends ChangeNotifier {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  List<ScanResult> get scanResults => _scanResults;
  bool get isScanning => _isScanning;
  BluetoothAdapterState get adapterState => _adapterState;

  ScanViewModel() {
    _initScanner();
  }

  void _initScanner() {
    // Listen to adapter state
    FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      if (state == BluetoothAdapterState.off) {
        _isScanning = false;
        _scanResults.clear();
      }
      notifyListeners();
    });

    // Listen to scan results
    FlutterBluePlus.scanResults.listen(
      (results) {
        _scanResults = results;
        notifyListeners();
      },
      onError: (e) {
        debugPrint("Scan Error: $e");
      },
    );

    FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
      notifyListeners();
    });
  }

  Future<void> startScan() async {
    if (_adapterState != BluetoothAdapterState.on) {
      debugPrint("Bluetooth is not on");
      return;
    }

    // Check permissions first
    bool permGranted = await requestPermissions();
    if (!permGranted) {
      debugPrint("Permissions not granted");
      return;
    }

    try {
      // Ensure any previous scan is stopped to reset state
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      _scanResults.clear();
      notifyListeners();

      // Wait a brief moment for the plugin to reset internal state
      await Future.delayed(const Duration(milliseconds: 200));

      // Start scanning with default options (low latency, 15s timeout)
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      debugPrint("Start Scan Error: $e");
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint("Stop Scan Error: $e");
    }
  }

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    bool allGranted = true;
    statuses.forEach((key, value) {
      if (!value.isGranted) {
        allGranted = false;
      }
    });
    return allGranted;
  }
}
