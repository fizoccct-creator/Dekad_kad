import '../models/connection.dart';

/// Placeholder contacts until saved connections are persisted.
List<Connection> sampleConnections() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  Connection c(
    String id,
    String name,
    String role,
    DateTime at,
    String method,
    String location,
    String notes,
    List<String> tags,
  ) => Connection(
    connectionId: id,
    userId: 'u-$id',
    displayName: name,
    role: role,
    timestamp: at,
    method: method,
    location: location,
    notes: notes,
    tags: tags,
  );

  return [
    c(
      'c1',
      'Priya Raman',
      'Design Lead · Northwind',
      today.add(const Duration(hours: 10, minutes: 24)),
      'qr',
      'Web Summit, Lisbon',
      'leads design systems team at northwind, ~40 designers. hiring 2 senior '
          'PMs in Q1, open to referrals. wants intro to our user research team. '
          'coffee next week?',
      ['Design systems', 'Hiring'],
    ),
    c(
      'c2',
      'Marcus Lee',
      'Founder · Brightloop',
      today.add(const Duration(hours: 11, minutes: 5)),
      'nfc',
      'Web Summit, Lisbon',
      'climate fintech, raising seed. wants feedback on onboarding flow.',
      ['Investor'],
    ),
    c(
      'c3',
      'Sofia Alves',
      'VC Associate · Atlas Ventures',
      today.add(const Duration(hours: 13, minutes: 40)),
      'qr',
      'Web Summit, Lisbon',
      '',
      [],
    ),
    c(
      'c4',
      'Daniel Okafor',
      'Staff Engineer · Stripe',
      today.subtract(const Duration(days: 3)),
      'qr',
      'Product Meetup',
      'payments infra, interested in our API roadmap.',
      [],
    ),
    c(
      'c5',
      'Hana Kim',
      'UX Researcher · Figma',
      today.subtract(const Duration(days: 4)),
      'nfc',
      'Coffee chat',
      '',
      [],
    ),
  ];
}
