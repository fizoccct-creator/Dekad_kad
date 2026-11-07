import 'dart:async';

import 'package:dekad/services/nearby/nearby_protocol.dart';
import 'package:dekad/services/nearby/nearby_service.dart';

/// In-memory [NearbyService] for tests.
class FakeNearbyService implements NearbyService {
  final discoveriesController = StreamController<NearbyDevice>.broadcast();
  final requestsController = StreamController<NearbyRequest>.broadcast();

  /// Cards returned by [readCard], by device id.
  final cards = <String, NearbyCard>{};

  /// What [connect] answers with.
  NearbyConnectResult connectResult = const NearbyConnectResult(
    NearbyReply.noAnswer,
  );

  /// Set to make [start] fail.
  NearbyUnavailable? failWith;

  bool running = false;
  String Function()? payload;
  final sentPayloads = <String>[];
  final responses = <({NearbyRequest request, bool accept, String? payload})>[];

  @override
  Stream<NearbyDevice> get discoveries => discoveriesController.stream;

  @override
  Stream<NearbyRequest> get requests => requestsController.stream;

  @override
  Future<void> start({
    required NearbyCard Function() card,
    required String Function() payload,
  }) async {
    if (failWith != null) throw NearbyException(failWith!);
    this.payload = payload;
    running = true;
  }

  @override
  Future<void> stop() async => running = false;

  @override
  Future<NearbyCard?> readCard(String deviceId) async => cards[deviceId];

  @override
  Future<NearbyConnectResult> connect(String deviceId, String payload) async {
    sentPayloads.add(payload);
    return connectResult;
  }

  @override
  Future<void> respond(
    NearbyRequest request, {
    required bool accept,
    String? payload,
  }) async {
    responses.add((request: request, accept: accept, payload: payload));
  }
}
