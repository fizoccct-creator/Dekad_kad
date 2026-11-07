import 'dart:convert';

import 'package:dekad/data/sample_profile.dart';
import 'package:dekad/models/user_profile.dart';
import 'package:dekad/services/exchange_service.dart';
import 'package:dekad/services/nearby/nearby_protocol.dart';
import 'package:dekad/services/nearby/nearby_service.dart';
import 'package:dekad/state/app_state.dart';
import 'package:dekad/state/nearby_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_nearby_service.dart';

const _marcus = ProfileData(
  name: 'Marcus Lee',
  bio: 'Climate fintech.',
  role: 'Founder',
  company: 'Brightloop',
);

void main() {
  group('frames', () {
    test('round-trip a long payload through small frames', () {
      final payload = ExchangeService.buildPayload(
        sampleProfile.professional,
        ProfileMode.professional,
      );
      final data = utf8.encode(payload);
      final parts = frames(data, 20);
      expect(parts.length, greaterThan(10));
      expect(parts.every((f) => f.length <= 20), isTrue);

      final a = FrameAssembler();
      List<int>? out;
      for (final f in parts) {
        out = a.add(f);
      }
      expect(utf8.decode(out!), payload);
    });

    test('single and empty messages', () {
      final a = FrameAssembler();
      expect(a.add(frames([1, 2, 3], 64).single), [1, 2, 3]);
      expect(a.add(frames([], 64).single), isEmpty);
    });

    test('a new first frame restarts a half-received message', () {
      final a = FrameAssembler();
      a.add(frames(List.filled(30, 7), 10).first);
      final fresh = frames([9, 9], 10);
      expect(a.add(fresh.single), [9, 9]);
    });

    test('ignores middle frames without a start', () {
      expect(FrameAssembler().add([0x00, 1, 2]), isNull);
    });
  });

  test('card encodes to a few bytes and decodes back', () {
    final card = NearbyCard.fromProfile(
      sampleProfile.professional,
      ProfileMode.professional,
    );
    final bytes = card.toBytes();
    expect(bytes.length, lessThan(160));
    final back = NearbyCard.fromBytes(bytes)!;
    expect(back.name, 'Alex Johnson');
    expect(back.role, 'Senior Product Manager · Tech Innovations Inc.');
    expect(back.mode, ProfileMode.professional);
    expect(NearbyCard.fromBytes(utf8.encode('nope')), isNull);
  });

  group('NearbyController', () {
    late AppState state;
    late FakeNearbyService service;
    late NearbyController c;

    setUp(() {
      state = AppState(profile: sampleProfile);
      service = FakeNearbyService();
      c = NearbyController(state: state, service: service);
    });

    tearDown(() {
      c.dispose();
      state.dispose();
    });

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('lists people once their card is read', () async {
      await c.start();
      expect(c.phase, NearbyPhase.on);
      service.cards['d1'] = const NearbyCard(
        name: 'Marcus Lee',
        role: 'Founder',
        mode: ProfileMode.professional,
      );
      service.discoveriesController.add(const NearbyDevice('d1', -55));
      service.discoveriesController.add(const NearbyDevice('d2', -70));
      await settle();
      expect(c.people.map((p) => p.card!.name), ['Marcus Lee']);
    });

    test('reports why Bluetooth is unavailable', () async {
      service.failWith = NearbyUnavailable.bluetoothOff;
      await c.start();
      expect(c.phase, NearbyPhase.unavailable);
      expect(c.unavailableReason, NearbyUnavailable.bluetoothOff);
    });

    test(
      'accepted connect sends the active profile only and saves them',
      () async {
        state.mode = ProfileMode.personal;
        await c.start();
        service.cards['d1'] = const NearbyCard(
          name: 'Marcus Lee',
          role: 'Founder',
          mode: ProfileMode.professional,
        );
        service.discoveriesController.add(const NearbyDevice('d1', -55));
        await settle();
        service.connectResult = NearbyConnectResult(
          NearbyReply.accepted,
          ExchangeService.buildPayload(_marcus, ProfileMode.professional),
        );

        final reply = await c.connect(c.people.single);

        expect(reply, NearbyReply.accepted);
        expect(
          ExchangeService.parsePayload(service.sentPayloads.single)?.name,
          'Alex J.',
        );
        expect(service.sentPayloads.single, isNot(contains('linkedin')));
        expect(c.people.single.status, PersonStatus.saved);
        final saved = state.connections.single;
        expect(saved.displayName, 'Marcus Lee');
        expect(saved.method, 'nearby');
      },
    );

    test('declined connect saves nothing', () async {
      await c.start();
      service.cards['d1'] = const NearbyCard(
        name: 'Marcus Lee',
        role: '',
        mode: ProfileMode.professional,
      );
      service.discoveriesController.add(const NearbyDevice('d1', -55));
      await settle();
      service.connectResult = const NearbyConnectResult(NearbyReply.declined);

      await c.connect(c.people.single);

      expect(c.people.single.status, PersonStatus.declined);
      expect(state.connections, isEmpty);
    });

    test(
      'incoming request: accept saves them and replies with our card',
      () async {
        await c.start();
        final got = <IncomingNearbyRequest>[];
        c.incoming.listen(got.add);
        final request = NearbyRequest(
          deviceId: 'd9',
          payload: ExchangeService.buildPayload(_marcus, ProfileMode.personal),
        );
        service.requestsController.add(request);
        await settle();

        expect(got.single.profile.name, 'Marcus Lee');
        expect(got.single.mode, ProfileMode.personal);

        await c.respond(got.single, accept: true);
        expect(state.connections.single.displayName, 'Marcus Lee');
        final r = service.responses.single;
        expect(r.accept, isTrue);
        expect(ExchangeService.parsePayload(r.payload!)?.name, 'Alex Johnson');
      },
    );

    test(
      'incoming request: decline saves nothing and sends no profile',
      () async {
        await c.start();
        final got = <IncomingNearbyRequest>[];
        c.incoming.listen(got.add);
        service.requestsController.add(
          NearbyRequest(
            deviceId: 'd9',
            payload: ExchangeService.buildPayload(
              _marcus,
              ProfileMode.personal,
            ),
          ),
        );
        await settle();
        await c.respond(got.single, accept: false);
        expect(state.connections, isEmpty);
        expect(service.responses.single.payload, isNull);
      },
    );

    test('garbage requests are declined without asking the user', () async {
      await c.start();
      final got = <IncomingNearbyRequest>[];
      c.incoming.listen(got.add);
      service.requestsController.add(
        const NearbyRequest(deviceId: 'd9', payload: 'not a profile'),
      );
      await settle();
      expect(got, isEmpty);
      expect(service.responses.single.accept, isFalse);
    });
  });
}
