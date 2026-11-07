import 'package:flutter/material.dart';

import 'data/sample_connections.dart';
import 'data/sample_profile.dart';
import 'screens/app_shell.dart';
import 'services/nearby/ble_nearby_service.dart';
import 'services/nearby/demo_nearby_service.dart';
import 'state/app_state.dart';
import 'state/nearby_controller.dart';
import 'theme/tokens.dart';

/// `flutter run --dart-define=NEARBY_DEMO=true` swaps Bluetooth for pretend
/// people, so Nearby and the Card Room work in a browser or simulator.
const nearbyDemo = bool.fromEnvironment('NEARBY_DEMO');

void main() {
  runApp(const DekadApp());
}

class DekadApp extends StatefulWidget {
  const DekadApp({super.key});

  @override
  State<DekadApp> createState() => _DekadAppState();
}

class _DekadAppState extends State<DekadApp> {
  final _state = AppState(
    profile: sampleProfile,
    connections: sampleConnections(),
  );
  late final _nearby = NearbyController(
    state: _state,
    service: nearbyDemo ? DemoNearbyService() : BleNearbyService(),
  );

  @override
  void dispose() {
    _nearby.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dekad',
      debugShowCheckedModeBanner: false,
      theme: buildDekadTheme(),
      home: AppShell(state: _state, nearby: _nearby),
    );
  }
}
