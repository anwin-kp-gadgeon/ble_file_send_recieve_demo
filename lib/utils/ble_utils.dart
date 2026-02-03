import 'dart:math';

class BleUtils {
  /// Splits a large byte array into smaller chunks based on the MTU size.
  /// [data] The full file data.
  /// [mtu] The negotiated MTU size (default typically 23, max 517).
  /// Note: The actual payload size for Write Without Response is MTU - 3.
  static List<List<int>> chunkData(List<int> data, int mtu) {
    int payloadSize = mtu - 3;
    if (payloadSize <= 0) payloadSize = 20; // Fallback safety

    List<List<int>> chunks = [];
    for (int i = 0; i < data.length; i += payloadSize) {
      int end = min(i + payloadSize, data.length);
      chunks.add(data.sublist(i, end));
    }
    return chunks;
  }

  static bool areUuidsEqual(String uuid1, String uuid2) {
    if (uuid1.isEmpty || uuid2.isEmpty) return false;

    String u1 = uuid1.toUpperCase();
    String u2 = uuid2.toUpperCase();

    if (u1 == u2) return true;

    // Check for 16-bit shortcut (e.g. "FF01" vs "0000FF01-0000-1000-8000-00805F9B34FB")
    if (u1.length == 4 && u2.length == 36) {
      return u2 == "0000$u1-0000-1000-8000-00805F9B34FB";
    }
    if (u2.length == 4 && u1.length == 36) {
      return u1 == "0000$u2-0000-1000-8000-00805F9B34FB";
    }

    return false;
  }
}
