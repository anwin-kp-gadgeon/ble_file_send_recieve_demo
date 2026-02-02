class BleConstants {
  // ESP32 Firmware / Custom Service (Inferred from FF01 char)
  static const String serviceUuid = "0000FF00-0000-1000-8000-00805F9B34FB";

  // Characteristic for Firmware Upload (Write / WriteWithoutResponse)
  static const String firmwareInputCharUuid =
      "0000FF01-0000-1000-8000-00805F9B34FB";

  // Characteristic for Log Download (Notify) - Assumed pattern or keep old?
  // Keeping compatible pattern FF02 for now, though user only provided FF01.
  static const String logOutputCharUuid =
      "0000FF02-0000-1000-8000-00805F9B34FB";
}
