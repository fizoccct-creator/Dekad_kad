import 'dart:async';
import 'dart:math' as math;

import '../../models/card_room.dart';
import '../../models/user_profile.dart';
import '../exchange_service.dart';
import 'nearby_protocol.dart';
import 'nearby_service.dart';

/// Pretend Nearby for trying the app without Bluetooth (browser, simulator,
/// one phone). Turn it on with `--dart-define=NEARBY_DEMO=true`.
///
/// Three people show up around you and accept when you connect, and a
/// fourth sends you a request a few seconds after you become visible.
class DemoNearbyService implements NearbyService {
  final _discoveries = StreamController<NearbyDevice>.broadcast();
  final _requests = StreamController<NearbyRequest>.broadcast();
  final _rnd = math.Random();
  Timer? _ping;
  Timer? _incoming;

  static const _people = {
    'demo-marcus': (
      ProfileData(
        name: 'Marcus Lee',
        bio: 'Building climate fintech for small businesses.',
        role: 'Founder',
        company: 'Brightloop',
      ),
      CardStyle(skin: CardSkin.gold, move: SendMove.supernova),
      -52,
    ),
    'demo-sofia': (
      ProfileData(
        name: 'Sofia Alves',
        bio: 'Seed investor in B2B software.',
        role: 'VC Associate',
        company: 'Atlas Ventures',
      ),
      CardStyle(skin: CardSkin.aurora, move: SendMove.spin),
      -66,
    ),
    'demo-dev': (
      ProfileData(
        name: 'Dev Kapoor',
        bio: 'Backend engineer, likes distributed systems.',
        role: 'Engineer',
        company: 'Lumen',
      ),
      CardStyle(skin: CardSkin.midnight, move: SendMove.flip),
      -82,
    ),
  };

  static const _requester = ProfileData(
    name: 'Priya Raman',
    bio: 'Leads design systems at Northwind.',
    role: 'Design Lead',
    company: 'Northwind',
  );

  @override
  Stream<NearbyDevice> get discoveries => _discoveries.stream;

  @override
  Stream<NearbyRequest> get requests => _requests.stream;

  @override
  Future<void> start({
    required NearbyCard Function() card,
    required String Function() payload,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    void ping() {
      for (final MapEntry(key: id, value: (_, _, rssi)) in _people.entries) {
        _discoveries.add(NearbyDevice(id, rssi + _rnd.nextInt(7) - 3));
      }
    }

    ping();
    _ping = Timer.periodic(const Duration(seconds: 3), (_) => ping());
    _incoming = Timer(const Duration(seconds: 8), () {
      _requests.add(
        NearbyRequest(
          deviceId: 'demo-priya',
          payload: ExchangeService.buildPayload(
            _requester,
            ProfileMode.professional,
            style: const CardStyle(skin: CardSkin.holo, move: SendMove.comet),
          ),
        ),
      );
    });
  }

  @override
  Future<void> stop() async {
    _ping?.cancel();
    _incoming?.cancel();
  }

  @override
  Future<NearbyCard?> readCard(String deviceId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final p = _people[deviceId];
    return p == null
        ? null
        : NearbyCard.fromProfile(p.$1, ProfileMode.professional);
  }

  @override
  Future<NearbyConnectResult> connect(String deviceId, String payload) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final p = _people[deviceId];
    if (p == null) return const NearbyConnectResult(NearbyReply.noAnswer);
    return NearbyConnectResult(
      NearbyReply.accepted,
      ExchangeService.buildPayload(p.$1, ProfileMode.professional, style: p.$2),
    );
  }

  @override
  Future<void> respond(
    NearbyRequest request, {
    required bool accept,
    String? payload,
  }) async {}
}
