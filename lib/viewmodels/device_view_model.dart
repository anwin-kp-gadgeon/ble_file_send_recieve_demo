import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_strings.dart';
import '../constants/ble_constants.dart';
import '../utils/ble_utils.dart';
import 'settings_view_model.dart';

enum DeviceState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  reconnecting,
}

enum DeviceEvent {
  unexpectedDisconnect,
  reconnecting,
  reconnectSuccess,
  reconnectFailed,
  connectionFailed,
}

class DeviceViewModel extends ChangeNotifier {
  SettingsViewModel? _settings;

  DeviceViewModel({SettingsViewModel? settings}) : _settings = settings;

  void updateSettings(SettingsViewModel settings) {
    _settings = settings;
  }

  BluetoothDevice? _device;
  DeviceState _connectionState = DeviceState.disconnected;
  BluetoothBondState _bondState = BluetoothBondState.none;

  // Internal flags
  bool _isUserDisconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  Timer? _reconnectTimer;
  Timer? _logSilenceTimer; // Auto-save logs on silence
  final StreamController<DeviceEvent> _eventController =
      StreamController<DeviceEvent>.broadcast();

  // Specific Characteristics found after service discovery
  BluetoothCharacteristic? _firmwareInputChar; // For writing (Upload)
  BluetoothCharacteristic? _logOutputChar; // For receiving (Download)

  // Upload State
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = "";

  // Download State
  bool _isDownloading = false;
  int _downloadedBytes = 0;
  final List<int> _downloadBuffer = [];
  String _downloadStatus = "";
  StreamSubscription? _logSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _bondStateSubscription;

  // Getters
  BluetoothDevice? get device => _device;
  DeviceState get connectionState => _connectionState;
  BluetoothBondState get bondState => _bondState;
  Stream<DeviceEvent> get events => _eventController.stream;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String get uploadStatus => _uploadStatus;
  bool get isDownloading => _isDownloading;
  int get downloadedBytes => _downloadedBytes;
  String get downloadStatus => _downloadStatus;

  // Connect to device
  Future<void> connect(BluetoothDevice device) async {
    // Reset state before new connection
    _resetState();

    _device = device;
    _connectionState = DeviceState.connecting;
    notifyListeners();

    try {
      await device.connect(autoConnect: false, license: License.free);
      _connectionState = DeviceState.connected;
      notifyListeners();

      // Listen to connection state changes
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _firmwareInputChar = null;
          _logOutputChar = null;

          if (!_isUserDisconnecting) {
            _handleUnexpectedDisconnect();
          } else {
            _connectionState = DeviceState.disconnected;
            notifyListeners();
          }
        } else if (state == BluetoothConnectionState.connected) {
          if (_connectionState == DeviceState.reconnecting) {
            _connectionState = DeviceState.connected;
            _reconnectAttempts = 0;
            _eventController.add(DeviceEvent.reconnectSuccess);
            notifyListeners();
            // Re-discover services as handles might have changed
            _discoverServices().then((_) async {
              if (Platform.isAndroid) {
                try {
                  await device.requestMtu(512);
                } catch (e) {
                  debugPrint("MTU Re-request failed: $e");
                }
              }
            });
          }
        }
      });

      // Listen to bond state changes
      _bondStateSubscription = device.bondState.listen((state) {
        _bondState = state;
        notifyListeners();
      });

      // Discover Services
      await _discoverServices();

      // Request Higher MTU for Speed (Android only, iOS ignores)
      if (Platform.isAndroid) {
        try {
          await device.requestMtu(512);
        } catch (e) {
          debugPrint("MTU Request Failed: $e");
        }
      }
    } catch (e) {
      debugPrint("Connection Error: $e");
      _connectionState = DeviceState.disconnected;
      _eventController.add(DeviceEvent.connectionFailed);
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _isUserDisconnecting = true;
    _reconnectTimer?.cancel();
    // Cancel subscriptions to prevent leaks
    await _connectionSubscription?.cancel();
    await _bondStateSubscription?.cancel();
    _connectionSubscription = null;
    _bondStateSubscription = null;

    try {
      if (_device != null) {
        await _device!.disconnect();
      }
    } catch (e) {
      debugPrint("Disconnect Error: $e");
    } finally {
      // Ensure we always update state
      _connectionState = DeviceState.disconnected;
      notifyListeners();
    }
  }

  void _resetState() {
    _isUserDisconnecting = false;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _logSilenceTimer?.cancel();

    _firmwareInputChar = null;
    _logOutputChar = null;

    _isUploading = false;
    _uploadProgress = 0.0;
    _uploadStatus = "";

    _isDownloading = false;
    _downloadedBytes = 0;
    _downloadBuffer.clear();
    _downloadStatus = "";
  }

  Future<void> pair() async {
    if (_device != null) {
      try {
        await _device!.createBond();
      } catch (e) {
        debugPrint("Pairing failed: $e");
      }
    }
  }

  Future<void> _handleUnexpectedDisconnect() async {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      _connectionState = DeviceState.reconnecting;
      _eventController.add(DeviceEvent.reconnecting);
      notifyListeners();

      debugPrint(
        "Attempting reconnect $_reconnectAttempts / $_maxReconnectAttempts",
      );

      _reconnectTimer = Timer(const Duration(seconds: 2), () async {
        if (_isUserDisconnecting || _device == null) return;
        try {
          await _device!.connect(autoConnect: false, license: License.free);
          // If successful, the stream listener handles the rest
        } catch (e) {
          debugPrint("Reconnect attempt failed: $e");
          // If connect fails immediately, try next attempt recursively
          _handleUnexpectedDisconnect();
        }
      });
    } else {
      _connectionState = DeviceState.disconnected;
      _eventController.add(DeviceEvent.reconnectFailed);
      notifyListeners();
    }
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;

    _uploadStatus = AppStrings.discoveringServices;
    notifyListeners();

    try {
      List<BluetoothService> services = await _device!.discoverServices();

      // Find our target service and characteristics
      for (var service in services) {
        // Check if this is our target service (optional)
        String targetServiceUuid =
            _settings?.serviceUuid ?? BleConstants.serviceUuid;
        if (service.uuid.toString().toUpperCase() !=
            targetServiceUuid.toUpperCase()) {
          // You can uncomment this to filter strictly by service
          // continue;
        }

        String targetFirmwareCharUuid =
            _settings?.firmwareInputCharUuid ??
            BleConstants.firmwareInputCharUuid;
        String targetLogCharUuid =
            _settings?.logOutputCharUuid ?? BleConstants.logOutputCharUuid;

        for (var c in service.characteristics) {
          if (c.uuid.toString().toUpperCase() ==
              targetFirmwareCharUuid.toUpperCase()) {
            _firmwareInputChar = c;
          }
          if (c.uuid.toString().toUpperCase() ==
              targetLogCharUuid.toUpperCase()) {
            _logOutputChar = c;
          }
        }
      }

      _uploadStatus = AppStrings.servicesReady;
      notifyListeners();
    } catch (e) {
      debugPrint("Service Discovery Error: $e");
    }
  }

  // --- Logic moved from UI ---
  Future<void> pickAndUploadFirmware() async {
    // Pick file
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      await uploadFirmware(file);
    } else {
      // User canceled
      debugPrint("User canceled file picker");
    }
  }

  // UPLOAD FIRMWARE
  Future<void> uploadFirmware(File file) async {
    if (_firmwareInputChar == null) {
      _uploadStatus = AppStrings.targetCharNotFound;
      notifyListeners();
      return;
    }

    _isUploading = true;
    _uploadProgress = 0.0;
    _uploadStatus = AppStrings.readingFile;
    notifyListeners();

    try {
      List<int> fileBytes = await file.readAsBytes();
      int totalLength = fileBytes.length;

      // 1. Start Upload Command (0x10)
      debugPrint("Sending Start Command (0x10)...");
      _uploadStatus = AppStrings.initiatingUpload;
      notifyListeners();
      await _firmwareInputChar!.write([0x10], withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 500));

      // 2. Prepare Chunks
      // Python script uses 490 bytes. We try to match that, but respect actual MTU.
      // BleUtils.chunkData payload = mtu - 3. So target MTU = 490 + 3 = 493.
      int currentMtu = _device?.mtuNow ?? 23;
      int targetMtu = min(currentMtu, 493);
      List<List<int>> chunks = BleUtils.chunkData(fileBytes, targetMtu);

      _uploadStatus =
          "${AppStrings.uploadingChunks}${chunks.length}${AppStrings.chunksSuffix}";
      notifyListeners();

      int sentBytes = 0;
      Stopwatch stopwatch = Stopwatch()..start();

      for (int i = 0; i < chunks.length; i++) {
        if (!_isUploading) break; // User cancelled

        // -- Connection Recovery Logic --
        if (_connectionState != DeviceState.connected) {
          String prevStatus = _uploadStatus;
          _uploadStatus = AppStrings.pausedWaitingConnection;
          notifyListeners();

          while (_connectionState != DeviceState.connected && _isUploading) {
            await Future.delayed(const Duration(milliseconds: 500));
            if (_connectionState == DeviceState.disconnected) {
              throw Exception(AppStrings.connectionLostUpload);
            }
          }

          if (!_isUploading) break;

          _uploadStatus = AppStrings.restoringSession;
          notifyListeners();
          while ((_firmwareInputChar == null) && _isUploading) {
            await Future.delayed(const Duration(milliseconds: 200));
            if (_connectionState != DeviceState.connected) break;
          }

          _uploadStatus = prevStatus;
          notifyListeners();
        }

        if (!_isUploading) break;

        // -- Write Chunk --
        try {
          // Python script uses response=True. This provides automatic flow control.
          await _firmwareInputChar!.write(chunks[i], withoutResponse: false);
        } catch (e) {
          debugPrint("Write failed, retrying chunk $i: $e");
          if (_connectionState == DeviceState.connected) {
            await Future.delayed(const Duration(milliseconds: 100));
            try {
              await _firmwareInputChar!.write(
                chunks[i],
                withoutResponse: false,
              );
            } catch (e2) {
              rethrow;
            }
          } else {
            i--;
            continue;
          }
        }

        sentBytes += chunks[i].length;
        _uploadProgress = sentBytes / totalLength;

        // Note: Manual 50ms throttling removed because writeWithResponse
        // provides natural backpressure/ACK.

        if (i % 5 == 0) {
          notifyListeners();
        }
      }
      stopwatch.stop();

      // 3. End Upload (Magic Sequence)
      if (_isUploading) {
        debugPrint("Sending Stop Sequence (0xFF, 0xCC, 0x00, 0xFF)...");
        await _firmwareInputChar!.write([
          0xFF,
          0xCC,
          0x00,
          0xFF,
        ], withoutResponse: false);
      }

      _uploadStatus =
          "${AppStrings.uploadComplete}${stopwatch.elapsed.inSeconds}${AppStrings.secondsSuffix}";
    } catch (e) {
      _uploadStatus = "${AppStrings.errorPrefix}$e";
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  // DOWNLOAD LOGS
  Future<void> startLogDownload() async {
    if (_logOutputChar == null) {
      _downloadStatus = AppStrings.logCharNotFound;
      notifyListeners();
      return;
    }

    if (!_logOutputChar!.properties.notify) {
      _downloadStatus = AppStrings.notifyNotSupported;
      notifyListeners();
      return;
    }

    _isDownloading = true;
    _downloadedBytes = 0;
    _downloadBuffer.clear();
    _downloadStatus = AppStrings.waitingForData;
    notifyListeners();

    try {
      // Listen BEFORE enabling notifications to ensure no packets are missed
      _logSubscription = _logOutputChar!.lastValueStream.listen((data) {
        // Reset silence timer on every packet
        _logSilenceTimer?.cancel();
        _logSilenceTimer = Timer(const Duration(seconds: 2), () {
          // If no data for 2 seconds, assume end of stream
          if (_isDownloading) stopLogDownload();
        });

        if (data.isNotEmpty) {
          _downloadBuffer.addAll(data);
          _downloadedBytes += data.length;
          _downloadStatus =
              "${AppStrings.receivedPrefix}${(_downloadedBytes / 1024).toStringAsFixed(1)}${AppStrings.kbSuffix}";
          notifyListeners();

          // POC: Stop after 300KB automatically
          if (_downloadedBytes >= 300 * 1024) {
            // We can't await here easily inside the stream listener
            // so we call the cleanup method
            stopLogDownload();
          }
        }
      });

      await _logOutputChar!.setNotifyValue(true);
    } catch (e) {
      _downloadStatus = "${AppStrings.downloadErrorPrefix}$e";
      _isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> stopLogDownload() async {
    _isDownloading = false;
    _logSilenceTimer?.cancel();

    // Cancel subscription
    if (_logSubscription != null) {
      await _logSubscription!.cancel();
      _logSubscription = null;
    }

    if (_logOutputChar != null) {
      // attempt to disable notify
      try {
        await _logOutputChar!.setNotifyValue(false);
      } catch (e) {
        /* ignore */
      }
    }

    // Save to file
    _downloadStatus = AppStrings.savingFile;
    notifyListeners();

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/downloaded_log_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsBytes(_downloadBuffer);

      _downloadStatus = "${AppStrings.savedToPrefix}${file.path}";
    } catch (e) {
      _downloadStatus = "${AppStrings.saveErrorPrefix}$e";
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _eventController.close();
    disconnect();
    super.dispose();
  }
}
