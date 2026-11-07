import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/card_room.dart';
import '../services/nearby/nearby_service.dart';
import '../state/app_state.dart';
import '../state/nearby_controller.dart';
import '../theme/tokens.dart';
import '../widgets/card_3d.dart';
import '../widgets/dekad_widgets.dart';
import 'badges_screen.dart';

const _bg = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF0F1222), Color(0xFF1B1F3A)],
);
const _gold = Color(0xFFFFD36E);

enum _Phase { ready, sending, waiting, arriving, done, failed }

/// The game-like moment before a connection: turn your card in 3D, pick a
/// move and skin you've unlocked, swipe up to send it
/// (Figma: "Card Room — Ready to send").
class CardRoomScreen extends StatefulWidget {
  const CardRoomScreen({
    super.key,
    required this.controller,
    required this.person,
  });

  final NearbyController controller;
  final NearbyPerson person;

  @override
  State<CardRoomScreen> createState() => _CardRoomScreenState();
}

class _CardRoomScreenState extends State<CardRoomScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fly = AnimationController(vsync: this);
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  _Phase _phase = _Phase.ready;
  double _rotX = 0, _rotY = 0, _dragY = 0;
  double _settleFromX = 0, _settleFromY = 0;
  NearbyOutcome? _outcome;

  /// Badges earned by this connection, shown when their card lands.
  List<BadgeDef> _newBadges = const [];

  AppState get _state => widget.controller.state;
  String get _first => widget.person.card!.name.split(' ').first;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      final k = Curves.easeOutBack.transform(_settle.value);
      setState(() {
        _rotX = _settleFromX * (1 - k);
        _rotY = _settleFromY * (1 - k);
      });
    });
  }

  @override
  void dispose() {
    _fly.dispose();
    _settle.dispose();
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_phase != _Phase.ready) return;
    _settle.stop();
    setState(() {
      _rotY = (_rotY + d.delta.dx / 120).clamp(-1.2, 1.2);
      _rotX = (_rotX - d.delta.dy / 160).clamp(-0.9, 0.9);
      _dragY += d.delta.dy;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_phase != _Phase.ready) return;
    final swipedUp = d.velocity.pixelsPerSecond.dy < -700 || _dragY < -140;
    _dragY = 0;
    if (swipedUp) {
      _send();
    } else {
      _settleFromX = _rotX;
      _settleFromY = _rotY;
      _settle.forward(from: 0);
    }
  }

  Future<void> _send() async {
    final style = _state.cardStyle;
    final before = {
      for (final b in badges)
        if (b.earned(_state.stats)) b.id,
    };
    HapticFeedback.mediumImpact();
    setState(() => _phase = _Phase.sending);
    _fly.duration = moveDuration(style.move);
    final connect = widget.controller.connect(widget.person);
    await _fly.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _phase = _Phase.waiting;
      _rotX = _rotY = 0;
    });
    _pulse.repeat();
    final outcome = await connect;
    if (!mounted) return;
    _pulse.stop();
    _outcome = outcome;
    if (outcome?.reply == NearbyReply.accepted) {
      final s = _state.stats;
      _newBadges = [
        for (final b in badges)
          if (b.earned(s) && !before.contains(b.id)) b,
      ];
      HapticFeedback.heavyImpact();
      setState(() => _phase = _Phase.arriving);
      _fly.duration = moveDuration(outcome!.style.move);
      await _fly.forward(from: 0);
      if (mounted) setState(() => _phase = _Phase.done);
    } else {
      setState(() => _phase = _Phase.failed);
    }
  }

  void _retry() {
    _fly.value = 0;
    setState(() => _phase = _Phase.ready);
  }

  void _pickMove(SendMove m) {
    final badge = badgeForMove(m);
    if (!moveUnlocked(m, _state.stats)) {
      _lockedHint(badge!, '${label(m)} move');
      return;
    }
    HapticFeedback.selectionClick();
    _state.sendMove = m;
  }

  void _pickSkin(CardSkin k) {
    final badge = badgeForSkin(k);
    if (!skinUnlocked(k, _state.stats)) {
      _lockedHint(badge!, '${skinLabel(k)} skin');
      return;
    }
    HapticFeedback.selectionClick();
    _state.cardSkin = k;
  }

  void _lockedHint(BadgeDef b, String what) {
    final s = _state.stats;
    showSnack(
      context,
      'Earn ${b.name} (${b.requirement}, ${b.progress(s)}/${b.goal}) '
      'to unlock $what',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final style = _state.cardStyle;
        final stats = _state.stats;
        final earned = badges.where((b) => b.earned(stats)).length;
        return Scaffold(
          backgroundColor: DekadColors.ink900,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: _bg),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(
                  children: [
                    _header(earned),
                    Expanded(child: _stage(style)),
                    _footer(style, stats),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(int earned) {
    final (title, sub) = switch (_phase) {
      _Phase.ready || _Phase.sending => (
        'Send to $_first',
        'Card Room · ${widget.person.card!.role}',
      ),
      _Phase.waiting => ('Sent!', 'Waiting for $_first to accept…'),
      _Phase.arriving ||
      _Phase.done => ('$_first’s card', 'Saved to your connections'),
      _Phase.failed => (
        _outcome?.reply == NearbyReply.declined
            ? '$_first said not now'
            : '$_first didn’t answer',
        'Your card wasn’t shared',
      ),
    };
    return Row(
      children: [
        CircleIconButton(
          icon: Icons.close,
          tooltip: 'Close',
          background: Colors.white.withValues(alpha: 0.12),
          color: DekadColors.surface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DekadText.h2.copyWith(color: DekadColors.surface),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DekadText.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.white.withValues(alpha: 0.12),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BadgesScreen(state: _state),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
              child: Row(
                children: [
                  const Icon(Icons.military_tech, size: 16, color: _gold),
                  const SizedBox(width: 4),
                  Text(
                    '$earned badges',
                    style: DekadText.label.copyWith(color: DekadColors.surface),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stage(CardStyle style) {
    final mine = _state.current;
    final mode = _state.mode;
    final myPalette = paletteFor(style.skin);
    final theirs = _outcome;

    if (_phase == _Phase.waiting) {
      return Center(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = _pulse.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                for (final k in [0.0, 0.5])
                  Opacity(
                    opacity: (1 - ((t + k) % 1)).clamp(0.0, 1.0),
                    child: Container(
                      width: 80 + 180 * ((t + k) % 1),
                      height: 80 + 180 * ((t + k) % 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: myPalette.glowColor.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                DekadAvatar(
                  name: widget.person.card!.name,
                  size: 72,
                  mode: widget.person.card!.mode,
                ),
              ],
            );
          },
        ),
      );
    }

    if ((_phase == _Phase.arriving || _phase == _Phase.done) &&
        theirs?.profile != null) {
      final p = paletteFor(theirs!.style.skin);
      return AnimatedBuilder(
        animation: _fly,
        builder: (context, _) => Center(
          child: MovingCard(
            move: theirs.style.move,
            progress: _phase == _Phase.done ? 1 : _fly.value,
            arriving: true,
            glow: p.glowColor,
            front: CardFront(
              profile: theirs.profile!,
              mode: widget.person.card!.mode,
              skin: theirs.style.skin,
            ),
            back: CardBack(skin: theirs.style.skin),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onDoubleTap: _phase == _Phase.ready
          ? () {
              HapticFeedback.lightImpact();
              _spin.forward(from: 0);
            }
          : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_fly, _spin]),
        builder: (context, _) {
          final spin = Curves.easeInOutCubic.transform(_spin.value);
          final sending = _phase == _Phase.sending;
          final failed = _phase == _Phase.failed;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Soft glow under the card in the skin's colour.
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: myPalette.glowColor.withValues(alpha: 0.35),
                      blurRadius: 120,
                    ),
                  ],
                ),
              ),
              FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: MovingCard(
                    move: style.move,
                    progress: failed ? 0 : (sending ? _fly.value : 0),
                    glow: myPalette.glowColor,
                    rotX: _rotX,
                    rotY: _rotY + spin * 2 * math.pi,
                    front: CardFront(
                      profile: mine,
                      mode: mode,
                      skin: style.skin,
                      light: (_rotY / 1.2).clamp(-1.0, 1.0),
                    ),
                    back: CardBack(skin: style.skin),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _footer(CardStyle style, DekadStats stats) {
    final white60 = Colors.white.withValues(alpha: 0.6);
    switch (_phase) {
      case _Phase.waiting:
        return Text(
          'They’ll see your card fly in with your ${label(style.move)} move.',
          textAlign: TextAlign.center,
          style: DekadText.caption.copyWith(color: white60),
        );
      case _Phase.arriving || _Phase.done:
        final theirs = _outcome!.style;
        return Column(
          children: [
            Text(
              '${skinLabel(theirs.skin)} card · ${label(theirs.move)} move',
              style: DekadText.caption.copyWith(color: _gold),
            ),
            for (final b in _newBadges) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _gold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.military_tech, color: _gold, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'New badge: ${b.name}'
                        '${b.unlocksLabel.isEmpty ? '' : ' · ${b.unlocksLabel} unlocked'}',
                        style: DekadText.label.copyWith(
                          color: DekadColors.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: PillButton(
                label: 'Done',
                icon: Icons.check,
                accent: DekadColors.accent(_state.mode),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        );
      case _Phase.failed:
        return Row(
          children: [
            Expanded(
              child: PillButton(
                label: 'Close',
                variant: PillVariant.ghost,
                foreground: DekadColors.surface,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PillButton(
                label: 'Try again',
                icon: Icons.refresh,
                accent: DekadColors.accent(_state.mode),
                onPressed: _retry,
              ),
            ),
          ],
        );
      case _Phase.ready || _Phase.sending:
        final next = nextUnlock(stats);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                  Text(
                    'Swipe up to send · drag to turn · double-tap to spin',
                    style: DekadText.caption.copyWith(color: white60),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Overline('Send move', color: white60),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final m in SendMove.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _Option(
                        icon: moveIcon(m),
                        label: label(m),
                        selected: style.move == m,
                        locked: !moveUnlocked(m, stats),
                        onTap: () => _pickMove(m),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Overline('Card skin', color: white60),
                const Spacer(),
                Text(
                  skinLabel(style.skin),
                  style: DekadText.caption.copyWith(color: white60),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final k in CardSkin.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _SkinSwatch(
                        skin: k,
                        selected: style.skin == k,
                        locked: !skinUnlocked(k, stats),
                        onTap: () => _pickSkin(k),
                      ),
                    ),
                  ),
              ],
            ),
            if (next != null) ...[
              const SizedBox(height: 12),
              Text(
                'Next: ${next.name} (${next.progress(stats)}/${next.goal}) '
                'unlocks ${next.unlocksLabel}',
                style: DekadText.caption.copyWith(color: _gold),
              ),
            ],
          ],
        );
    }
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? DekadColors.pro
        : Colors.white.withValues(alpha: locked ? 0.4 : 0.85);
    return Semantics(
      button: true,
      selected: selected,
      label: locked ? '$label, locked' : label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? DekadColors.surface
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: DekadColors.pro.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(locked ? Icons.lock_outline : icon, size: 22, color: fg),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  label,
                  style: DekadText.caption.copyWith(
                    color: selected ? DekadColors.ink900 : fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinSwatch extends StatelessWidget {
  const _SkinSwatch({
    required this.skin,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final CardSkin skin;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(skin);
    return Semantics(
      button: true,
      selected: selected,
      label: '${skinLabel(skin)} skin${locked ? ', locked' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: locked ? 0.45 : 1,
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: p.colors),
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: Colors.white, width: 2.5)
                  : null,
            ),
            child: locked
                ? const Icon(Icons.lock_outline, size: 16, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Receiver's side: their card flies in with their move, then you accept
/// and yours flies back (Figma: "Card Room — Card arrives").
/// [onAnswer] is called as soon as the user decides.
class CardArrivalScreen extends StatefulWidget {
  const CardArrivalScreen({
    super.key,
    required this.request,
    required this.state,
    required this.onAnswer,
  });

  final IncomingNearbyRequest request;
  final AppState state;
  final Future<void> Function(bool accept) onAnswer;

  @override
  State<CardArrivalScreen> createState() => _CardArrivalScreenState();
}

class _CardArrivalScreenState extends State<CardArrivalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fly = AnimationController(vsync: this);
  bool _sendingMine = false;

  @override
  void initState() {
    super.initState();
    _fly.duration = moveDuration(widget.request.style.move);
    HapticFeedback.mediumImpact();
    _fly.forward();
  }

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  Future<void> _answer(bool accept) async {
    final reply = widget.onAnswer(accept);
    if (!accept) {
      await reply;
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() => _sendingMine = true);
    _fly.duration = moveDuration(widget.state.cardStyle.move);
    await Future.wait([reply, _fly.forward(from: 0)]);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final first = r.profile.name.split(' ').first;
    final mine = widget.state.cardStyle;
    final style = _sendingMine ? mine : r.style;
    final p = paletteFor(style.skin);
    return Scaffold(
      backgroundColor: DekadColors.ink900,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: _bg),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Column(
              children: [
                Text(
                  _sendingMine
                      ? 'Sending yours · ${label(mine.move)}'
                      : 'Incoming · ${label(r.style.move)} move',
                  style: DekadText.overline.copyWith(color: _gold),
                ),
                const SizedBox(height: 4),
                Text(
                  _sendingMine
                      ? 'Connected with $first'
                      : '$first sent you their card',
                  textAlign: TextAlign.center,
                  style: DekadText.h1.copyWith(color: DekadColors.surface),
                ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _fly,
                    builder: (context, _) => Center(
                      child: FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: MovingCard(
                            move: style.move,
                            progress: _fly.value,
                            arriving: !_sendingMine,
                            glow: p.glowColor,
                            front: _sendingMine
                                ? CardFront(
                                    profile: widget.state.current,
                                    mode: widget.state.mode,
                                    skin: mine.skin,
                                  )
                                : CardFront(
                                    profile: r.profile,
                                    mode: r.mode,
                                    skin: r.style.skin,
                                  ),
                            back: CardBack(skin: style.skin),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!_sendingMine) ...[
                  Row(
                    children: [
                      Expanded(
                        child: PillButton(
                          label: 'Not now',
                          variant: PillVariant.ghost,
                          foreground: DekadColors.surface,
                          onPressed: () => _answer(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PillButton(
                          label: 'Accept',
                          icon: Icons.check,
                          accent: DekadColors.accent(widget.state.mode),
                          onPressed: () => _answer(true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Accepting sends your ${widget.state.mode.name} card back '
                    'with your ${label(mine.move)} move',
                    textAlign: TextAlign.center,
                    style: DekadText.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
