import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/nearby/nearby_protocol.dart';
import '../services/nearby/nearby_service.dart';
import '../state/nearby_controller.dart';
import '../theme/tokens.dart';
import '../widgets/dekad_widgets.dart';
import 'card_room_screen.dart';

/// Dekad users around you (Figma: "Nearby — People around you").
/// Opening it turns on "Be visible nearby".
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key, required this.controller});

  final NearbyController controller;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  NearbyController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    if (_c.phase != NearbyPhase.on) _c.start();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _connect(NearbyPerson p) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => CardRoomScreen(controller: _c, person: p),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_c, _c.state]),
      builder: (context, _) {
        final mode = _c.state.mode;
        final people = _c.people;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    children: [
                      Row(
                        children: [
                          CircleIconButton(
                            icon: Icons.chevron_left,
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Nearby', style: DekadText.h2),
                                Text(
                                  'Dekad users around you',
                                  style: DekadText.caption,
                                ),
                              ],
                            ),
                          ),
                          TagChip(
                            label: mode == ProfileMode.professional
                                ? 'Professional'
                                : 'Personal',
                            tone: ChipTone.accent,
                            mode: mode,
                            background: DekadColors.surface,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _Radar(
                        spin: _spin,
                        accent: DekadColors.accent(mode),
                        people: people,
                        active: _c.isOn,
                      ),
                      _StatusLine(controller: _c),
                      if (_c.isOn) ...[
                        const SizedBox(height: 16),
                        Overline(
                          people.isEmpty
                              ? 'Looking for people…'
                              : '${people.length} '
                                    '${people.length == 1 ? 'person' : 'people'} nearby',
                        ),
                        const SizedBox(height: 8),
                        if (people.isEmpty)
                          Text(
                            'Ask the people around you to open Dekad and turn '
                            'on Nearby too.',
                            style: DekadText.body.copyWith(
                              color: DekadColors.ink400,
                            ),
                          ),
                        for (final p in people)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _PersonRow(
                              person: p,
                              mode: mode,
                              onConnect: () => _connect(p),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: _c.isOn
                        ? PillButton(
                            label: 'Stop being visible',
                            icon: Icons.close,
                            variant: PillVariant.secondary,
                            onPressed: () async {
                              await _c.stop();
                              if (context.mounted) Navigator.of(context).pop();
                            },
                          )
                        : _c.unavailableReason == NearbyUnavailable.unsupported
                        ? PillButton(
                            label: 'Back',
                            variant: PillVariant.secondary,
                            onPressed: () => Navigator.of(context).pop(),
                          )
                        : PillButton(
                            label: _c.phase == NearbyPhase.starting
                                ? 'Starting…'
                                : 'Try again',
                            icon: Icons.bluetooth,
                            accent: DekadColors.accent(mode),
                            loading: _c.phase == NearbyPhase.starting,
                            onPressed: _c.start,
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.controller});

  final NearbyController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final (color, text) = switch (c.phase) {
      NearbyPhase.on => (
        DekadColors.success,
        'You’re visible as ${c.state.current.name} · '
            '${c.state.mode == ProfileMode.professional ? 'Professional' : 'Personal'}',
      ),
      NearbyPhase.starting => (DekadColors.ink400, 'Turning on Bluetooth…'),
      NearbyPhase.off => (DekadColors.ink400, 'You’re not visible'),
      NearbyPhase.unavailable => (
        DekadColors.personal,
        switch (c.unavailableReason) {
          NearbyUnavailable.bluetoothOff =>
            'Bluetooth is off. Turn it on to use Nearby.',
          NearbyUnavailable.unauthorized =>
            'Dekad needs Bluetooth permission. Allow it in Settings.',
          _ => 'This device can’t use Nearby. Use the QR code instead.',
        },
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: DekadText.caption.copyWith(color: DekadColors.ink600),
          ),
        ),
      ],
    );
  }
}

class _Radar extends StatelessWidget {
  const _Radar({
    required this.spin,
    required this.accent,
    required this.people,
    required this.active,
  });

  final Animation<double> spin;
  final Color accent;
  final List<NearbyPerson> people;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: LayoutBuilder(
        builder: (context, box) {
          final c = Offset(box.maxWidth / 2, 120);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: spin,
                  builder: (context, _) => CustomPaint(
                    painter: _RadarPainter(accent, active ? spin.value : null),
                  ),
                ),
              ),
              Positioned(
                left: c.dx - 28,
                top: c.dy - 28,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: active ? accent : DekadColors.ink200,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bluetooth,
                    color: DekadColors.surface,
                  ),
                ),
              ),
              for (final (i, p) in people.take(8).indexed)
                () {
                  // Stronger signal sits closer to the centre.
                  final strength = ((p.rssi + 95) / 45).clamp(0.0, 1.0);
                  final r = 105 - 55 * strength;
                  final a = -math.pi / 2 + i * (2 * math.pi / 8) + 0.4;
                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    left: c.dx + r * math.cos(a) - 24,
                    top: c.dy + r * math.sin(a) - 24,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: DekadColors.surface,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: DekadAvatar(
                        name: p.card!.name,
                        size: 42,
                        mode: p.card!.mode,
                      ),
                    ),
                  );
                }(),
            ],
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.accent, this.sweep);

  final Color accent;

  /// 0..1 rotation of the sweep, or null when inactive.
  final double? sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, 120);
    for (final (r, a) in const [(110.0, 0.06), (80.0, 0.1), (50.0, 0.16)]) {
      canvas.drawCircle(c, r, Paint()..color = accent.withValues(alpha: a));
    }
    if (sweep == null) return;
    final rect = Rect.fromCircle(center: c, radius: 110);
    final start = sweep! * 2 * math.pi;
    canvas.drawArc(
      rect,
      start,
      0.9,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + 0.9,
          colors: [accent.withValues(alpha: 0), accent.withValues(alpha: 0.18)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.sweep != sweep || old.accent != accent;
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.mode,
    required this.onConnect,
  });

  final NearbyPerson person;
  final ProfileMode mode;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final card = person.card!;
    final Widget action = switch (person.status) {
      PersonStatus.requesting => const _Pill(
        label: 'Requested',
        color: DekadColors.ink400,
        background: DekadColors.canvas,
      ),
      PersonStatus.saved => const _Pill(
        label: 'Saved',
        icon: Icons.check,
        color: DekadColors.success,
        background: DekadColors.successSoft,
      ),
      PersonStatus.declined => const _Pill(
        label: 'Not now',
        color: DekadColors.ink400,
        background: DekadColors.canvas,
      ),
      PersonStatus.idle || PersonStatus.failed => Material(
        color: DekadColors.accent(mode),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onConnect,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(
              person.status == PersonStatus.failed ? 'Retry' : 'Connect',
              style: DekadText.label.copyWith(color: DekadColors.surface),
            ),
          ),
        ),
      ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: DekadColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          DekadAvatar(name: card.name, size: 44, mode: card.mode),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DekadText.bodyStrong,
                ),
                if (card.role.isNotEmpty)
                  Text(
                    card.role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DekadText.caption.copyWith(
                      color: DekadColors.ink600,
                    ),
                  ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: DekadColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(distanceLabel(person.rssi), style: DekadText.caption),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: DekadText.label.copyWith(color: color)),
        ],
      ),
    );
  }
}
