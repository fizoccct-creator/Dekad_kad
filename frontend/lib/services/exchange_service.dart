import 'dart:convert';

import 'package:nfc_manager/nfc_manager.dart';

import '../models/user_profile.dart';

/// Builds and reads the payloads people swap when they connect.
///
/// Only the profile for the active mode is shared, so switching to
/// "Professional" never leaks the personal profile (and vice versa).
class ExchangeService {
  static const _payloadType = 'dekad.profile';
  static const _payloadVersion = 1;

  static String buildPayload(ProfileData profile, ProfileMode mode) =>
      jsonEncode({
        'type': _payloadType,
        'v': _payloadVersion,
        'mode': mode.name,
        'profile': profile.toJson(),
      });

  /// Returns null if [payload] is not a Dekad profile.
  static ProfileData? parsePayload(String payload) {
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      if (json['type'] != _payloadType) return null;
      return ProfileData.fromJson(json['profile'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// The profile mode a payload was shared in (professional if unknown).
  static ProfileMode parseMode(String payload) {
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      return json['mode'] == ProfileMode.personal.name
          ? ProfileMode.personal
          : ProfileMode.professional;
    } catch (_) {
      return ProfileMode.professional;
    }
  }

  static Future<bool> isNfcAvailable() async =>
      await NfcManager.instance.checkAvailability() == NfcAvailability.enabled;

  /// TODO: start an NFC session and write/read [buildPayload] as an NDEF record.
  static Future<void> exchangeViaNfc(
    ProfileData profile,
    ProfileMode mode,
  ) async {
    if (!await isNfcAvailable()) {
      throw StateError('NFC is off or not supported on this device');
    }
    throw UnimplementedError('NFC exchange is not built yet');
  }
}
