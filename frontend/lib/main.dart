import 'package:flutter/material.dart';

import 'data/sample_profile.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const DekadApp());
}

class DekadApp extends StatelessWidget {
  const DekadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dekad',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: HomeScreen(profile: sampleProfile),
    );
  }
}
