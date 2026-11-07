import 'nearby_protocol.dart';

/// Why Nearby could not start.
enum NearbyUnavailable { unsupported, unauthorized, bluetoothOff }

class NearbyException implements Exception {
  NearbyException(this.reason, [this.detail]);

  final NearbyUnavailable reason;
  final String? detail;

  @override
  String toString() =>
      'NearbyException($reason${detail == null ? '' : ': $detail'})';
}

/// A phone advertising the Dekad service.
class NearbyDevice {
  const NearbyDevice(this.id, this.rssi);

  final String id;
  final int rssi;
}

/// Someone nearby asked to connect. [payload] is their profile in the same
/// format as the QR code (see ExchangeService).
class NearbyRequest {
  const NearbyRequest({required this.deviceId, required this.payload});

  final String deviceId;
  final String payload;
}

enum NearbyReply { accepted, declined, noAnswer }

class NearbyConnectResult {
  const NearbyConnectResult(this.reply, [this.payload]);

  final NearbyReply reply;

  /// The other person's profile payload when [reply] is accepted.
  final String? payload;
}

/// Bluetooth transport for Nearby. The UI talks to NearbyController, which
/// uses this; tests use a fake.
abstract class NearbyService {
  /// Phones running Dekad with Nearby on, as they're seen.
  Stream<NearbyDevice> get discoveries;

  /// Incoming connection requests.
  Stream<NearbyRequest> get requests;

  /// Starts advertising and scanning. [card] and [payload] are called on
  /// demand, so they always reflect the active profile.
  /// Throws [NearbyException] if Bluetooth can't be used.
  Future<void> start({
    required NearbyCard Function() card,
    required String Function() payload,
  });

  Future<void> stop();

  /// Reads the small card a device shows in the list.
  Future<NearbyCard?> readCard(String deviceId);

  /// Sends our [payload] and waits for the other person to answer.
  Future<NearbyConnectResult> connect(String deviceId, String payload);

  /// Answers a [NearbyRequest]. When accepting, [payload] is what they get.
  Future<void> respond(
    NearbyRequest request, {
    required bool accept,
    String? payload,
  });
}
