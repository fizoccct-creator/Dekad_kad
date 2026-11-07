import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/card_room.dart';
import '../models/connection.dart';
import '../models/user_profile.dart';
import '../services/exchange_service.dart';
import '../services/nearby/nearby_protocol.dart';
import '../services/nearby/nearby_service.dart';
import 'app_state.dart';

enum NearbyPhase { off, starting, on, unavailable }

enum PersonStatus { idle, requesting, saved, declined, failed }

class NearbyPerson {
  NearbyPerson(this.id, this.rssi, this.lastSeen);

  final String id;
  int rssi;
  DateTime lastSeen;
  NearbyCard? card;
  PersonStatus status = PersonStatus.idle;
}

/// An incoming request with the requester's profile already parsed.
class IncomingNearbyRequest {
  const IncomingNearbyRequest(
    this.request,
    this.profile,
    this.mode, [
    this.style = const CardStyle(),
  ]);

  final NearbyRequest request;
  final ProfileData profile;
  final ProfileMode mode;

  /// The card skin and move they sent it with.
  final CardStyle style;
}

/// How an outgoing connect ended. [profile] and [style] are theirs, set
/// when they accepted.
class NearbyOutcome {
  const NearbyOutcome(
    this.reply, {
    this.profile,
    this.style = const CardStyle(),
  });

  final NearbyReply reply;
  final ProfileData? profile;
  final CardStyle style;
}

/// Owns the Nearby session: who's around, outgoing and incoming requests.
/// Saved contacts go into [AppState].
class NearbyController extends ChangeNotifier {
  NearbyController({
    required this.state,
    required this.service,
    this.goneAfter = const Duration(seconds: 30),
    this.cardRetry = const Duration(seconds: 15),
  });

  final AppState state;
  final NearbyService service;
  final Duration goneAfter;
  final Duration cardRetry;

  final _people = <String, NearbyPerson>{};
  final _cardTried = <String, DateTime>{};
  final _incoming = StreamController<IncomingNearbyRequest>.broadcast();
  StreamSubscription<NearbyDevice>? _discoverySub;
  StreamSubscription<NearbyRequest>? _requestSub;
  Timer? _sweep;

  NearbyPhase _phase = NearbyPhase.off;
  NearbyUnavailable? _unavailable;

  NearbyPhase get phase => _phase;
  bool get isOn => _phase == NearbyPhase.on;

  /// Set when [phase] is [NearbyPhase.unavailable].
  NearbyUnavailable? get unavailableReason => _unavailable;

  /// People whose card we've read, strongest signal first.
  List<NearbyPerson> get people =>
      _people.values.where((p) => p.card != null).toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));

  /// Requests the UI should ask the user about.
  Stream<IncomingNearbyRequest> get incoming => _incoming.stream;

  Future<void> start() async {
    if (_phase == NearbyPhase.on || _phase == NearbyPhase.starting) return;
    _phase = NearbyPhase.starting;
    _unavailable = null;
    notifyListeners();
    _discoverySub = service.discoveries.listen(_onDiscovery);
    _requestSub = service.requests.listen(_onRequest);
    try {
      await service.start(
        card: () => NearbyCard.fromProfile(state.current, state.mode),
        payload: () => ExchangeService.buildPayload(state.current, state.mode),
      );
    } on NearbyException catch (e) {
      await _teardown();
      _phase = NearbyPhase.unavailable;
      _unavailable = e.reason;
      notifyListeners();
      return;
    }
    _sweep = Timer.periodic(const Duration(seconds: 5), (_) => _dropGone());
    _phase = NearbyPhase.on;
    notifyListeners();
  }

  Future<void> stop() async {
    await _teardown();
    await service.stop();
    _people.clear();
    _cardTried.clear();
    _phase = NearbyPhase.off;
    notifyListeners();
  }

  Future<void> _teardown() async {
    _sweep?.cancel();
    _sweep = null;
    await _discoverySub?.cancel();
    await _requestSub?.cancel();
    _discoverySub = null;
    _requestSub = null;
  }

  void _onDiscovery(NearbyDevice d) {
    final now = DateTime.now();
    final p = _people.putIfAbsent(d.id, () => NearbyPerson(d.id, d.rssi, now))
      ..rssi = d.rssi
      ..lastSeen = now;
    if (p.card == null) {
      final tried = _cardTried[d.id];
      if (tried == null || now.difference(tried) > cardRetry) {
        _cardTried[d.id] = now;
        unawaited(_loadCard(p));
      }
    } else {
      notifyListeners();
    }
  }

  Future<void> _loadCard(NearbyPerson p) async {
    try {
      final card = await service.readCard(p.id);
      if (card == null || !_people.containsKey(p.id)) return;
      p.card = card;
      notifyListeners();
    } catch (e) {
      debugPrint('Nearby: could not read card from ${p.id}: $e');
    }
  }

  void _dropGone() {
    final cutoff = DateTime.now().subtract(goneAfter);
    final before = _people.length;
    _people.removeWhere(
      (_, p) =>
          p.lastSeen.isBefore(cutoff) && p.status != PersonStatus.requesting,
    );
    if (_people.length != before) notifyListeners();
  }

  /// Sends our active profile to [person] and saves them if they accept.
  /// Sends our active profile (with our Card Room style) to [person] and
  /// saves them if they accept. Null if a request is already in flight.
  Future<NearbyOutcome?> connect(NearbyPerson person) async {
    if (person.status == PersonStatus.requesting) return null;
    person.status = PersonStatus.requesting;
    notifyListeners();
    var outcome = const NearbyOutcome(NearbyReply.noAnswer);
    try {
      final result = await service.connect(
        person.id,
        ExchangeService.buildPayload(
          state.current,
          state.mode,
          style: state.cardStyle,
        ),
      );
      final payload = result.payload;
      final profile = payload == null
          ? null
          : ExchangeService.parsePayload(payload);
      if (result.reply == NearbyReply.accepted && profile != null) {
        _save(profile);
        person.status = PersonStatus.saved;
        outcome = NearbyOutcome(
          NearbyReply.accepted,
          profile: profile,
          style: ExchangeService.parseStyle(payload!),
        );
      } else {
        final declined = result.reply == NearbyReply.declined;
        person.status = declined ? PersonStatus.declined : PersonStatus.failed;
        outcome = NearbyOutcome(
          declined ? NearbyReply.declined : NearbyReply.noAnswer,
        );
      }
    } catch (e) {
      debugPrint('Nearby: connect to ${person.id} failed: $e');
      person.status = PersonStatus.failed;
    }
    notifyListeners();
    return outcome;
  }

  void _onRequest(NearbyRequest r) {
    final profile = ExchangeService.parsePayload(r.payload);
    if (profile == null) {
      unawaited(service.respond(r, accept: false));
      return;
    }
    _incoming.add(
      IncomingNearbyRequest(
        r,
        profile,
        ExchangeService.parseMode(r.payload),
        ExchangeService.parseStyle(r.payload),
      ),
    );
  }

  /// Answers an incoming request; accepting saves them and sends our
  /// active profile back.
  Future<void> respond(
    IncomingNearbyRequest incoming, {
    required bool accept,
  }) async {
    if (accept) _save(incoming.profile);
    try {
      await service.respond(
        incoming.request,
        accept: accept,
        payload: accept
            ? ExchangeService.buildPayload(
                state.current,
                state.mode,
                style: state.cardStyle,
              )
            : null,
      );
    } catch (e) {
      debugPrint('Nearby: reply failed: $e');
    }
  }

  void _save(ProfileData p) {
    state.addConnection(
      Connection(
        connectionId: 'c${DateTime.now().microsecondsSinceEpoch}',
        userId: '',
        displayName: p.name,
        role: [p.role, ?p.company].join(' · '),
        photoUrl: p.photoUrl,
        timestamp: DateTime.now(),
        method: 'nearby',
        location: '',
        notes: '',
        tags: const [],
      ),
    );
  }

  @override
  void dispose() {
    _teardown();
    service.stop();
    _incoming.close();
    super.dispose();
  }
}
