import 'package:dekad/data/sample_profile.dart';
import 'package:dekad/models/user_profile.dart';
import 'package:dekad/screens/home_screen.dart';
import 'package:dekad/services/exchange_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('switches between professional and personal profiles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(profile: sampleProfile)),
    );

    expect(find.text('Alex Johnson'), findsOneWidget);
    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    expect(find.text('Alex J.'), findsOneWidget);
    expect(find.text('Alex Johnson'), findsNothing);
  });

  test('QR payload carries only the active profile and round-trips', () {
    final payload = ExchangeService.buildPayload(
      sampleProfile.professional,
      ProfileMode.professional,
    );
    expect(payload, isNot(contains('instagram')));
    expect(ExchangeService.parsePayload(payload)?.name, 'Alex Johnson');
    expect(ExchangeService.parsePayload('not json'), isNull);
  });
}
