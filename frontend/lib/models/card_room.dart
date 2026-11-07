import 'connection.dart';

/// How your card flies to someone in the Card Room.
enum SendMove { toss, flip, spin, comet, supernova }

/// The look of your card.
enum CardSkin { classic, midnight, aurora, holo, gold }

/// What a sender picked, carried in the exchange payload so the other
/// person sees the same card and move.
class CardStyle {
  const CardStyle({this.skin = CardSkin.classic, this.move = SendMove.toss});

  final CardSkin skin;
  final SendMove move;

  Map<String, dynamic> toJson() => {'skin': skin.name, 'move': move.name};

  factory CardStyle.fromJson(Object? json) {
    if (json is! Map) return const CardStyle();
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return CardStyle(
      skin: pick(CardSkin.values, json['skin'], CardSkin.classic),
      move: pick(SendMove.values, json['move'], SendMove.toss),
    );
  }
}

/// Activity the badges are measured against.
class DekadStats {
  const DekadStats({
    required this.connections,
    required this.nearbyConnections,
    required this.events,
    required this.contactsWithNotes,
    required this.followUps,
  });

  factory DekadStats.from(List<Connection> connections, int followUps) =>
      DekadStats(
        connections: connections.length,
        nearbyConnections: connections
            .where((c) => c.method == 'nearby')
            .length,
        events: {
          for (final c in connections)
            if (c.location.isNotEmpty) c.location,
        }.length,
        contactsWithNotes: connections
            .where((c) => c.notes.trim().isNotEmpty)
            .length,
        followUps: followUps,
      );

  final int connections;
  final int nearbyConnections;
  final int events;
  final int contactsWithNotes;
  final int followUps;
}

class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.name,
    required this.requirement,
    required this.goal,
    required this.measure,
    this.unlocksSkins = const [],
    this.unlocksMoves = const [],
  });

  final String id;
  final String name;

  /// e.g. "5 connections".
  final String requirement;
  final int goal;
  final int Function(DekadStats) measure;
  final List<CardSkin> unlocksSkins;
  final List<SendMove> unlocksMoves;

  int progress(DekadStats s) => measure(s).clamp(0, goal);
  bool earned(DekadStats s) => measure(s) >= goal;

  String get unlocksLabel => [
    ...unlocksMoves.map((m) => '${label(m)} move'),
    ...unlocksSkins.map((k) => '${skinLabel(k)} skin'),
  ].join(' + ');
}

/// All badges, in the order they're usually earned. Tune goals here.
final badges = <BadgeDef>[
  BadgeDef(
    id: 'first-hello',
    name: 'First hello',
    requirement: 'Your first connection',
    goal: 1,
    measure: (s) => s.connections,
    unlocksSkins: const [CardSkin.midnight],
  ),
  BadgeDef(
    id: 'wave-rider',
    name: 'Wave rider',
    requirement: 'First Nearby connection',
    goal: 1,
    measure: (s) => s.nearbyConnections,
    unlocksMoves: const [SendMove.flip],
  ),
  BadgeDef(
    id: 'connector',
    name: 'Connector',
    requirement: '5 connections',
    goal: 5,
    measure: (s) => s.connections,
    unlocksMoves: const [SendMove.spin],
    unlocksSkins: const [CardSkin.aurora],
  ),
  BadgeDef(
    id: 'event-regular',
    name: 'Event regular',
    requirement: 'Connections at 3 places',
    goal: 3,
    measure: (s) => s.events,
    unlocksSkins: const [CardSkin.holo],
  ),
  BadgeDef(
    id: 'networker',
    name: 'Networker',
    requirement: '10 connections',
    goal: 10,
    measure: (s) => s.connections,
    unlocksMoves: const [SendMove.comet],
  ),
  BadgeDef(
    id: 'note-taker',
    name: 'Note taker',
    requirement: 'Notes on 5 contacts',
    goal: 5,
    measure: (s) => s.contactsWithNotes,
  ),
  BadgeDef(
    id: 'follow-through',
    name: 'Follow-through',
    requirement: '3 AI follow-ups',
    goal: 3,
    measure: (s) => s.followUps,
  ),
  BadgeDef(
    id: 'legend',
    name: 'Legend',
    requirement: '25 connections',
    goal: 25,
    measure: (s) => s.connections,
    unlocksMoves: const [SendMove.supernova],
    unlocksSkins: const [CardSkin.gold],
  ),
];

/// The badge that unlocks [move], or null if it's free.
BadgeDef? badgeForMove(SendMove move) =>
    badges.where((b) => b.unlocksMoves.contains(move)).firstOrNull;

/// The badge that unlocks [skin], or null if it's free.
BadgeDef? badgeForSkin(CardSkin skin) =>
    badges.where((b) => b.unlocksSkins.contains(skin)).firstOrNull;

bool moveUnlocked(SendMove m, DekadStats s) =>
    badgeForMove(m)?.earned(s) ?? true;

bool skinUnlocked(CardSkin k, DekadStats s) =>
    badgeForSkin(k)?.earned(s) ?? true;

/// The unearned badge closest to being earned that unlocks something.
BadgeDef? nextUnlock(DekadStats s) {
  final open = badges
      .where((b) => !b.earned(s) && b.unlocksLabel.isNotEmpty)
      .toList();
  if (open.isEmpty) return null;
  open.sort(
    (a, b) => (b.progress(s) / b.goal).compareTo(a.progress(s) / a.goal),
  );
  return open.first;
}

String label(SendMove m) => switch (m) {
  SendMove.toss => 'Toss',
  SendMove.flip => 'Flip',
  SendMove.spin => 'Spin',
  SendMove.comet => 'Comet',
  SendMove.supernova => 'Supernova',
};

String skinLabel(CardSkin k) => switch (k) {
  CardSkin.classic => 'Classic',
  CardSkin.midnight => 'Midnight',
  CardSkin.aurora => 'Aurora',
  CardSkin.holo => 'Holo',
  CardSkin.gold => 'Gold',
};
