import 'package:dekad/data/sample_connections.dart';
import 'package:dekad/data/sample_profile.dart';
import 'package:dekad/models/user_profile.dart';
import 'package:dekad/screens/app_shell.dart';
import 'package:dekad/screens/home_screen.dart';
import 'package:dekad/services/exchange_service.dart';
import 'package:dekad/state/app_state.dart';
import 'package:dekad/theme/tokens.dart';
import 'package:dekad/widgets/dekad_widgets.dart';
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

  testWidgets('contacts tab lists and searches saved connections', (
    tester,
  ) async {
    final state = AppState(
      profile: sampleProfile,
      connections: sampleConnections(),
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDekadTheme(),
        home: AppShell(state: state),
      ),
    );

    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();
    expect(find.text('Priya Raman'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'stripe');
    await tester.pumpAndSettle();
    expect(find.text('Daniel Okafor'), findsOneWidget);
    expect(find.text('Priya Raman'), findsNothing);
  });

  test('initials come from first and last name', () {
    expect(initialsOf('Alex Johnson'), 'AJ');
    expect(initialsOf('Alex J.'), 'AJ');
    expect(initialsOf('Priya'), 'P');
    expect(initialsOf(''), '?');
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
