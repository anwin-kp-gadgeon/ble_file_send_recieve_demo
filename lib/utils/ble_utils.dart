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
}
