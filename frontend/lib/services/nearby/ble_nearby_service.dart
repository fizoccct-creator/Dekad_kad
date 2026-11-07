import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import 'nearby_protocol.dart';
import 'nearby_service.dart';

/// Bluetooth LE implementation of [NearbyService].
///
/// Each phone is both a peripheral (advertises the Dekad service and hosts
/// the GATT server, via ble_peripheral) and a central (scans and connects to
/// others, via flutter_reactive_ble).
class BleNearbyService implements NearbyService {
  BleNearbyService({FlutterReactiveBle? ble})
    : _ble = ble ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;
  final _discoveries = StreamController<NearbyDevice>.broadcast();
  final _requests = StreamController<NearbyRequest>.broadcast();
  final _assemblers = <String, FrameAssembler>{};
  final _replies = <String, Uint8List>{};
  StreamSubscription<DiscoveredDevice>? _scan;
  NearbyCard Function()? _card;
  bool _running = false;

  /// Central operations run one at a time; phones handle that far better
  /// than parallel connections.
  Future<void> _queue = Future.value();

  static final _service = Uuid.parse(NearbyUuids.service);
  static final _infoChar = Uuid.parse(NearbyUuids.info);
  static final _requestChar = Uuid.parse(NearbyUuids.request);
  static final _replyChar = Uuid.parse(NearbyUuids.reply);

  @override
  Stream<NearbyDevice> get discoveries => _discoveries.stream;

  @override
  Stream<NearbyRequest> get requests => _requests.stream;

  @override
  Future<void> start({
    required NearbyCard Function() card,
    required String Function() payload,
  }) async {
    if (_running) return;
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      throw NearbyException(NearbyUnavailable.unsupported);
    }
    await _askPermissions();
    await _checkStatus();
    if (!await BlePeripheral.isSupported()) {
      throw NearbyException(NearbyUnavailable.unsupported);
    }
    _card = card;
    await BlePeripheral.initialize();
    BlePeripheral.setReadRequestCallback(_onRead);
    BlePeripheral.setWriteRequestCallback(_onWrite);
    await BlePeripheral.clearServices();
    await BlePeripheral.addService(
      BleService(
        uuid: NearbyUuids.service,
        primary: true,
        characteristics: [
          BleCharacteristic(
            uuid: NearbyUuids.info,
            properties: [CharacteristicProperties.read.index],
            permissions: [AttributePermissions.readable.index],
          ),
          BleCharacteristic(
            uuid: NearbyUuids.request,
            properties: [CharacteristicProperties.write.index],
            permissions: [AttributePermissions.writeable.index],
          ),
          BleCharacteristic(
            uuid: NearbyUuids.reply,
            properties: [
              CharacteristicProperties.read.index,
              CharacteristicProperties.notify.index,
            ],
            permissions: [AttributePermissions.readable.index],
          ),
        ],
      ),
    );
    // No localName: on Android it would rename the phone's Bluetooth name.
    await BlePeripheral.startAdvertising(services: [NearbyUuids.service]);
    _scan = _ble
        .scanForDevices(
          withServices: [_service],
          scanMode: ScanMode.lowLatency,
          requireLocationServicesEnabled: false,
        )
        .listen(
          (d) => _discoveries.add(NearbyDevice(d.id, d.rssi)),
          onError: (Object e) => debugPrint('Nearby scan error: $e'),
        );
    _running = true;
  }

  Future<void> _askPermissions() async {
    // iOS shows its own Bluetooth prompt the first time we use it.
    if (!Platform.isAndroid) return;
    final result = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();
    if (result.values.any((s) => !s.isGranted)) {
      throw NearbyException(NearbyUnavailable.unauthorized);
    }
    // Android 11 and older need location to scan; newer versions ignore this.
    await Permission.locationWhenInUse.request();
  }

  Future<void> _checkStatus() async {
    final status = await _ble.statusStream
        .firstWhere((s) => s != BleStatus.unknown)
        .timeout(const Duration(seconds: 5), onTimeout: () => _ble.status);
    switch (status) {
      case BleStatus.ready || BleStatus.locationServicesDisabled:
        return;
      case BleStatus.poweredOff:
        throw NearbyException(NearbyUnavailable.bluetoothOff);
      case BleStatus.unauthorized:
        throw NearbyException(NearbyUnavailable.unauthorized);
      case BleStatus.unsupported || BleStatus.unknown:
        throw NearbyException(NearbyUnavailable.unsupported);
    }
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await _scan?.cancel();
    _scan = null;
    try {
      await BlePeripheral.stopAdvertising();
      await BlePeripheral.clearServices();
    } catch (e) {
      debugPrint('Nearby stop error: $e');
    }
    _assemblers.clear();
    _replies.clear();
  }

  // ---------- Peripheral side (someone connects to us) ----------

  ReadRequestResult? _onRead(
    String deviceId,
    String characteristicId,
    int offset,
    Uint8List? value,
  ) {
    Uint8List? bytes;
    if (NearbyUuids.same(characteristicId, NearbyUuids.info)) {
      bytes = _card?.call().toBytes();
    } else if (NearbyUuids.same(characteristicId, NearbyUuids.reply)) {
      bytes = _replies[deviceId] ?? Uint8List(0);
    }
    if (bytes == null) return null;
    final start = math.min(offset, bytes.length);
    return ReadRequestResult(value: bytes.sublist(start), offset: offset);
  }

  WriteRequestResult? _onWrite(
    String deviceId,
    String characteristicId,
    int offset,
    Uint8List? value,
  ) {
    if (!NearbyUuids.same(characteristicId, NearbyUuids.request) ||
        value == null) {
      return WriteRequestResult();
    }
    final message = _assemblers
        .putIfAbsent(deviceId, FrameAssembler.new)
        .add(value);
    if (message != null) {
      try {
        _requests.add(
          NearbyRequest(deviceId: deviceId, payload: utf8.decode(message)),
        );
      } on FormatException {
        debugPrint('Nearby: ignored a malformed request');
      }
    }
    return WriteRequestResult();
  }

  @override
  Future<void> respond(
    NearbyRequest request, {
    required bool accept,
    String? payload,
  }) async {
    if (accept && payload != null) {
      _replies[request.deviceId] = Uint8List.fromList(utf8.encode(payload));
    }
    await BlePeripheral.updateCharacteristic(
      characteristicId: NearbyUuids.reply,
      value: Uint8List.fromList([accept ? replyAccepted : replyDeclined]),
      deviceId: request.deviceId,
    );
  }

  // ---------- Central side (we connect to someone) ----------

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<T> _session<T>(String id, Future<T> Function() body) async {
    final connected = Completer<void>();
    final sub = _ble
        .connectToDevice(id: id, connectionTimeout: const Duration(seconds: 10))
        .listen(
          (u) {
            if (connected.isCompleted) return;
            if (u.connectionState == DeviceConnectionState.connected) {
              connected.complete();
            } else if (u.connectionState ==
                DeviceConnectionState.disconnected) {
              connected.completeError(
                StateError(u.failure?.message ?? 'Disconnected'),
              );
            }
          },
          onError: (Object e) {
            if (!connected.isCompleted) connected.completeError(e);
          },
        );
    try {
      await connected.future.timeout(const Duration(seconds: 12));
      await _ble.discoverAllServices(id);
      return await body();
    } finally {
      await sub.cancel(); // disconnects
    }
  }

  QualifiedCharacteristic _char(String id, Uuid c) => QualifiedCharacteristic(
    deviceId: id,
    serviceId: _service,
    characteristicId: c,
  );

  @override
  Future<NearbyCard?> readCard(String deviceId) => _serial(
    () => _session(deviceId, () async {
      final bytes = await _ble.readCharacteristic(_char(deviceId, _infoChar));
      return NearbyCard.fromBytes(bytes);
    }),
  );

  @override
  Future<NearbyConnectResult> connect(String deviceId, String payload) =>
      _serial(
        () => _session(deviceId, () async {
          var mtu = 23;
          try {
            mtu = await _ble.requestMtu(deviceId: deviceId, mtu: 247);
          } catch (_) {
            // iOS negotiates the MTU itself.
            mtu = 185;
          }
          final answer = Completer<int>();
          final replySub = _ble
              .subscribeToCharacteristic(_char(deviceId, _replyChar))
              .listen((v) {
                if (v.isNotEmpty && !answer.isCompleted) answer.complete(v[0]);
              });
          try {
            // Give the subscription a moment to register on the other side.
            await Future<void>.delayed(const Duration(milliseconds: 300));
            for (final f in frames(utf8.encode(payload), mtu - 3)) {
              await _ble.writeCharacteristicWithResponse(
                _char(deviceId, _requestChar),
                value: f,
              );
            }
            final code = await answer.future.timeout(
              const Duration(seconds: 60),
              onTimeout: () => -1,
            );
            if (code == -1) {
              return const NearbyConnectResult(NearbyReply.noAnswer);
            }
            if (code != replyAccepted) {
              return const NearbyConnectResult(NearbyReply.declined);
            }
            final bytes = await _ble.readCharacteristic(
              _char(deviceId, _replyChar),
            );
            return NearbyConnectResult(
              NearbyReply.accepted,
              utf8.decode(bytes),
            );
          } finally {
            await replySub.cancel();
          }
        }),
      );
}
