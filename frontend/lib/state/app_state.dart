import 'package:flutter/foundation.dart';

import '../models/card_room.dart';
import '../models/connection.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart' show BadgeText;

/// In-memory app state shared by the tabs. Replace with local storage once
/// sign-up exists.
class AppState extends ChangeNotifier {
  AppState({required UserProfile profile, List<Connection>? connections})
    : _profile = profile,
      _connections = [...?connections];

  UserProfile _profile;
  ProfileMode _mode = ProfileMode.professional;
  final List<Connection> _connections;
  bool _nfcEnabled = true;
  BadgeText? _badge;
  int _followUps = 0;
  CardSkin _skin = CardSkin.classic;
  SendMove _move = SendMove.toss;
  String _badgeEvent = '';

  UserProfile get profile => _profile;
  ProfileMode get mode => _mode;
  ProfileData get current => _profile.forMode(_mode);
  bool get nfcEnabled => _nfcEnabled;
  BadgeText? get badge => _badge;

  DekadStats get stats => DekadStats.from(_connections, _followUps);

  /// The card skin and send move for the Card Room. Falls back to the free
  /// ones if a choice is no longer unlocked.
  CardStyle get cardStyle {
    final s = stats;
    return CardStyle(
      skin: skinUnlocked(_skin, s) ? _skin : CardSkin.classic,
      move: moveUnlocked(_move, s) ? _move : SendMove.toss,
    );
  }

  set cardSkin(CardSkin value) {
    if (!skinUnlocked(value, stats)) return;
    _skin = value;
    notifyListeners();
  }

  set sendMove(SendMove value) {
    if (!moveUnlocked(value, stats)) return;
    _move = value;
    notifyListeners();
  }

  void recordFollowUp() {
    _followUps++;
    notifyListeners();
  }

  String get badgeEvent => _badgeEvent;

  /// Newest first.
  List<Connection> get connections => List.unmodifiable(
    [..._connections]..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
  );

  set mode(ProfileMode value) {
    if (value == _mode) return;
    _mode = value;
    notifyListeners();
  }

  set nfcEnabled(bool value) {
    _nfcEnabled = value;
    notifyListeners();
  }

  void saveBadge(String event, BadgeText badge) {
    _badgeEvent = event;
    _badge = badge;
    notifyListeners();
  }

  void updateBio(ProfileMode mode, String bio) {
    final updated = _profile.forMode(mode).copyWith(bio: bio);
    _profile = mode == ProfileMode.professional
        ? UserProfile(professional: updated, personal: _profile.personal)
        : UserProfile(professional: _profile.professional, personal: updated);
    notifyListeners();
  }

  void addConnection(Connection connection) {
    _connections.add(connection);
    notifyListeners();
  }

  void updateConnection(Connection connection) {
    final i = _connections.indexWhere(
      (c) => c.connectionId == connection.connectionId,
    );
    if (i == -1) return;
    _connections[i] = connection;
    notifyListeners();
  }
}
