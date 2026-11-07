import 'package:dekad/data/sample_profile.dart';
import 'package:dekad/models/card_room.dart';
import 'package:dekad/models/connection.dart';
import 'package:dekad/models/user_profile.dart';
import 'package:dekad/services/exchange_service.dart';
import 'package:dekad/services/nearby/nearby_service.dart';
import 'package:dekad/state/app_state.dart';
import 'package:dekad/state/nearby_controller.dart';
import 'package:dekad/widgets/card_3d.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_nearby_service.dart';

Connection _c(
  int i, {
  String method = 'qr',
  String location = '',
  String notes = '',
}) => Connection(
  connectionId: 'c$i',
  userId: '',
  displayName: 'Person $i',
  role: 'Role',
  timestamp: DateTime(2026, 1, 1).add(Duration(minutes: i)),
  method: method,
  location: location,
  notes: notes,
  tags: const [],
);

void main() {
  test('nothing but the free moves and skin without badges', () {
    final s = DekadStats.from(const [], 0);
    expect(SendMove.values.where((m) => moveUnlocked(m, s)), [SendMove.toss]);
    expect(CardSkin.values.where((k) => skinUnlocked(k, s)), [
      CardSkin.classic,
    ]);
    expect(nextUnlock(s)?.name, 'First hello');
  });

  test('connections earn badges that unlock moves and skins', () {
    final s = DekadStats.from([
      for (var i = 0; i < 5; i++) _c(i, location: 'Place ${i % 3}'),
      _c(9, method: 'nearby'),
    ], 0);
    expect(s.connections, 6);
    expect(s.events, 3);
    expect(moveUnlocked(SendMove.flip, s), isTrue); // Wave rider
    expect(moveUnlocked(SendMove.spin, s), isTrue); // Connector
    expect(moveUnlocked(SendMove.comet, s), isFalse); // needs 10
    expect(skinUnlocked(CardSkin.aurora, s), isTrue);
    expect(skinUnlocked(CardSkin.holo, s), isTrue); // 3 places
    expect(skinUnlocked(CardSkin.gold, s), isFalse);
    expect(nextUnlock(s)?.name, 'Networker');
  });

  test('every locked move and skin has a badge that unlocks it', () {
    for (final m in SendMove.values.skip(1)) {
      expect(badgeForMove(m), isNotNull, reason: m.name);
    }
    for (final k in CardSkin.values.skip(1)) {
      expect(badgeForSkin(k), isNotNull, reason: k.name);
    }
  });

  test('app state ignores locked picks and falls back to free ones', () {
    final state = AppState(profile: sampleProfile);
    addTearDown(state.dispose);
    state.sendMove = SendMove.supernova;
    state.cardSkin = CardSkin.gold;
    expect(state.cardStyle.move, SendMove.toss);
    expect(state.cardStyle.skin, CardSkin.classic);

    state.addConnection(_c(1));
    state.cardSkin = CardSkin.midnight;
    expect(state.cardStyle.skin, CardSkin.midnight);
  });

  test('card style rides along in the payload and defaults safely', () {
    const style = CardStyle(skin: CardSkin.holo, move: SendMove.comet);
    final payload = ExchangeService.buildPayload(
      sampleProfile.professional,
      ProfileMode.professional,
      style: style,
    );
    final back = ExchangeService.parseStyle(payload);
    expect(back.skin, CardSkin.holo);
    expect(back.move, SendMove.comet);
    expect(ExchangeService.parsePayload(payload)?.name, 'Alex Johnson');

    final plain = ExchangeService.buildPayload(
      sampleProfile.professional,
      ProfileMode.professional,
    );
    expect(plain, isNot(contains('"card"')));
    expect(ExchangeService.parseStyle(plain).move, SendMove.toss);
    expect(
      CardStyle.fromJson({'skin': 'rainbow', 'move': 'warp'}).skin,
      CardSkin.classic,
    );
  });

  test('every move starts in hand and ends off screen or gone', () {
    for (final m in SendMove.values) {
      final start = moveFrame(m, 0);
      expect(start.dx, 0, reason: m.name);
      expect(start.dy, 0, reason: m.name);
      expect(start.scale, 1, reason: m.name);
      final end = moveFrame(m, 1);
      final gone = end.dy.abs() > 1 || end.scale < 0.05 || end.opacity < 0.05;
      expect(gone, isTrue, reason: m.name);
    }
  });

  test('Nearby sends your card style and reads theirs', () async {
    final state = AppState(profile: sampleProfile, connections: [_c(1)]);
    final service = FakeNearbyService();
    final c = NearbyController(state: state, service: service);
    addTearDown(c.dispose);
    addTearDown(state.dispose);
    state.cardSkin = CardSkin.midnight;
    await c.start();

    final incoming = <IncomingNearbyRequest>[];
    c.incoming.listen(incoming.add);
    service.requestsController.add(
      NearbyRequest(
        deviceId: 'd1',
        payload: ExchangeService.buildPayload(
          sampleProfile.personal,
          ProfileMode.personal,
          style: const CardStyle(skin: CardSkin.gold, move: SendMove.supernova),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(incoming.single.style.move, SendMove.supernova);

    await c.respond(incoming.single, accept: true);
    final reply = service.responses.single.payload!;
    expect(ExchangeService.parseStyle(reply).skin, CardSkin.midnight);
  });
}
