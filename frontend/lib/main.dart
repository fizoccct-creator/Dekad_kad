import 'package:flutter/material.dart';

import 'data/sample_connections.dart';
import 'data/sample_profile.dart';
import 'screens/app_shell.dart';
import 'state/app_state.dart';
import 'theme/tokens.dart';

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

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dekad',
      debugShowCheckedModeBanner: false,
      theme: buildDekadTheme(),
      home: AppShell(state: _state),
    );
  }
}
