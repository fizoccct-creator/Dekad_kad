import 'dart:convert';
import 'dart:typed_data';

import '../../models/user_profile.dart';

/// GATT layout every Dekad phone exposes while "Be visible nearby" is on.
///
/// - [info]: read. A tiny [NearbyCard] (name, role, mode) for the list.
/// - [request]: write. The requester's full profile payload, sent in
///   [frames] because a single BLE write is limited by the MTU.
/// - [reply]: notify + read. The receiver notifies [replyAccepted] or
///   [replyDeclined]; after accepting, reading it returns the receiver's
///   profile payload (long reads are handled by the OS).
abstract final class NearbyUuids {
  static const service = 'a7d1e5c0-4b8f-4c2e-9d3a-6e1f0b2c8d40';
  static const info = 'a7d1e5c1-4b8f-4c2e-9d3a-6e1f0b2c8d40';
  static const request = 'a7d1e5c2-4b8f-4c2e-9d3a-6e1f0b2c8d40';
  static const reply = 'a7d1e5c3-4b8f-4c2e-9d3a-6e1f0b2c8d40';

  /// Platforms report UUIDs in different cases.
  static bool same(String a, String b) => a.toLowerCase() == b.toLowerCase();
}

const replyAccepted = 1;
const replyDeclined = 2;

/// What someone nearby sees before connecting.
class NearbyCard {
  const NearbyCard({
    required this.name,
    required this.role,
    required this.mode,
  });

  final String name;
  final String role;
  final ProfileMode mode;

  factory NearbyCard.fromProfile(ProfileData p, ProfileMode mode) => NearbyCard(
    name: p.name,
    role: [p.role, ?p.company].join(' · '),
    mode: mode,
  );

  Uint8List toBytes() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'v': 1,
        'n': _clip(name, 40),
        'r': _clip(role, 60),
        'm': mode.name,
      }),
    ),
  );

  /// Returns null for anything that isn't a Dekad card.
  static NearbyCard? fromBytes(List<int> bytes) {
    try {
      final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (j['v'] != 1) return null;
      return NearbyCard(
        name: j['n'] as String,
        role: j['r'] as String? ?? '',
        mode: j['m'] == 'personal'
            ? ProfileMode.personal
            : ProfileMode.professional,
      );
    } catch (_) {
      return null;
    }
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}…';
}

// Frame header bits.
const _first = 0x01;
const _last = 0x02;

/// Splits [data] into frames of at most [maxFrame] bytes (header included).
List<Uint8List> frames(List<int> data, int maxFrame) {
  assert(maxFrame >= 2);
  final chunk = maxFrame - 1;
  final out = <Uint8List>[];
  for (var i = 0; i == 0 || i < data.length; i += chunk) {
    final end = (i + chunk).clamp(0, data.length);
    final header = (i == 0 ? _first : 0) | (end >= data.length ? _last : 0);
    out.add(Uint8List.fromList([header, ...data.sublist(i, end)]));
  }
  return out;
}

/// Rebuilds data sent with [frames]. A new first frame restarts the buffer.
class FrameAssembler {
  List<int>? _buffer;

  /// Returns the full message once the last frame arrives, otherwise null.
  List<int>? add(List<int> frame) {
    if (frame.isEmpty) return null;
    final header = frame[0];
    if (header & _first != 0) _buffer = [];
    final buffer = _buffer;
    if (buffer == null) return null; // middle frame without a start
    buffer.addAll(frame.skip(1));
    if (header & _last == 0) return null;
    _buffer = null;
    return buffer;
  }
}

/// Rough distance label from signal strength.
String distanceLabel(int rssi) {
  if (rssi >= -60) return 'Very close';
  if (rssi >= -78) return 'Nearby';
  return 'Further away';
}
