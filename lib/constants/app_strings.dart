class AppStrings {
  // General
  static const String appTitle = "BLE Sync";
  static const String unknownDevice = "Unknown Device";

  // Landing Screen
  static const String landingTitle = "BLE Sync";
  static const String landingSubtitle =
      "Seamlessly update firmware and sync logs with your BLE hardware.";
  static const String startScanning = "Start Scanning";

  // Scan Screen
  static const String scanTitle = "Nearby Devices";
  static const String noDevicesFound = "No devices found";
  static const String bluetoothOff = "Bluetooth is turned off";
  static const String turnOnBluetooth = "Please turn on Bluetooth to scan";
  static const String scanAgain = "Scan Again";
  static const String stopScanning = "Stop Scanning";

  // Device Control Screen
  static const String deviceControlTitle = "Device Control";
  static const String connectionStatus = "Connection Status";
  static const String uuidHint =
      "Ensure UUIDs in constants match your device hardware.";

  // Firmware Actions
  static const String firmwareSectionTitle = "Firmware Actions";
  static const String updateFirmwareTitle = "Update Firmware";
  static const String updateFirmwareSubtitle = "Upload binary file to device";
  static const String selectFile = "Select File";

  // Diagnostics/Logs Actions
  static const String diagnosticsSectionTitle = "Diagnostics";
  static const String downloadLogsTitle = "Download Logs";
  static const String downloadLogsSubtitle = "Retrieve system logs from device";
  static const String startDownload = "Start Download";
  static const String stopAndSave = "Stop & Save";

  // Messages & Dialogs
  static const String connectingMessage = "Connecting to device...";
  static const String disconnectingMessage = "Disconnecting...";
  static const String deviceDetailsTitle = "Device Details";
  static const String deviceNameLabel = "Name: ";
  static const String deviceIdLabel = "ID: ";
  static const String okAction = "OK";
  static const String connectAction = "Connect";
  static const String disconnect = "Disconnect";
  static const String cancelAction = "Cancel";
  static const String confirmAction = "Confirm";
  static const String connectConfirmationTitle = "Connect to Device?";
  static const String connectConfirmationMessage = "Do you want to connect to ";
  static const String disconnectConfirmationTitle = "Disconnect Device?";
  static const String disconnectConfirmationMessage =
      "Are you sure you want to disconnect from this device?";
  static const String unexpectedDisconnect =
      "Device disconnected unexpectedly.";
  static const String reconnecting = "Lost connection. Reconnecting...";
  static const String reconnectSuccess = "Reconnected successfully!";
  static const String reconnectFailed =
      "Unable to reconnect. Please check device.";
  static const String connectionFailed = "Failed to connect to device.";
  static const String goBack = "GO BACK";
  static const String hideBanner = "HIDE";
  static const String dismissBanner = "DISMISS";
  static const String configureUuidsTooltip = "Configure UUIDs";
  static const String dBmLabel = " dBm";

  // Fonts
  static const String monospaceFont = "monospace";

  // ViewModel Status Messages
  static const String discoveringServices = "Discovering Services...";
  static const String servicesReady = "Services Ready";
  static const String targetCharNotFound = "Target Characteristic not found";
  static const String readingFile = "Reading File...";
  static const String uploadingChunks = "Uploading ";
  static const String chunksSuffix = " chunks...";
  static const String uploadComplete = "Upload Complete! Time: ";
  static const String secondsSuffix = "s";
  static const String errorPrefix = "Error: ";
  static const String logCharNotFound = "Log Output Characteristic not found";
  static const String notifyNotSupported =
      "Characteristic does not support Notify";
  static const String waitingForData = "Waiting for data...";
  static const String receivedPrefix = "Received ";
  static const String kbSuffix = " KB";
  static const String downloadErrorPrefix = "Error starting download: ";
  static const String savingFile = "Saving file...";
  static const String savedToPrefix = "Saved to: ";
  static const String saveErrorPrefix = "Error saving: ";

  // Settings Screen
  static const String settingsTitle = "Connection Settings";
  static const String resetDefaultsTitle = "Reset to Defaults?";
  static const String resetDefaultsMessage =
      "This will revert all UUIDs to their original compiled values.";
  static const String restoredDefaults = "Restored default UUIDs";
  static const String configSaved = "Configuration Saved Successfully";
  static const String serviceConfigTitle = "Service Configuration";
  static const String serviceUuidLabel = "Service UUID";
  static const String serviceUuidHint = "6E400001-...";
  static const String characteristicsTitle = "Characteristics";
  static const String firmwareCharLabel = "Firmware Write (RX)";
  static const String firmwareCharHint = "6E400002-...";
  static const String logCharLabel = "Log Notify (TX)";
  static const String logCharHint = "6E400003-...";
  static const String saveConfigAction = "Save Configuration";
  static const String resetAction = "Reset";
  static const String settingsInfo =
      "Configure the UUIDs to match your specific ESP32 firmware. Changes will take effect on the next connection scan.";
  static const String validationRequired = "Required";
  static const String validationInvalidUuid = "Invalid UUID format";
  static const String validationFixErrors =
      "Please fix the validation errors above.";
  static const String errorSavingConfig = "Error saving configuration: ";
  static const String savingSettingsLog = "Saving settings...";

  // Device ViewModel Messages
  static const String initiatingUpload = "Initiating upload...";
  static const String pausedWaitingConnection =
      "Paused: Waiting for connection...";
  static const String connectionLostUpload = "Connection lost during upload";
  static const String restoringSession = "Restoring session...";

  // Symbols
  static const String percentSymbol = "%";
}
