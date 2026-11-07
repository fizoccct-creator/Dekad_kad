import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/card_room.dart';
import '../models/user_profile.dart';
import '../theme/tokens.dart';
import 'dekad_widgets.dart' show initialsOf;

/// Colours for a [CardSkin] (Figma component "Profile Card").
class SkinPalette {
  const SkinPalette(this.colors, {this.dark = false, this.glow});

  final List<Color> colors;

  /// True when the skin is light enough to need dark text.
  final bool dark;
  final Color? glow;

  Color get foreground => dark ? DekadColors.ink900 : DekadColors.surface;
  Color get muted => dark
      ? DekadColors.ink900.withValues(alpha: 0.65)
      : Colors.white.withValues(alpha: 0.75);
  Color get chip => dark
      ? Colors.white.withValues(alpha: 0.5)
      : Colors.white.withValues(alpha: 0.18);
  Color get glowColor => glow ?? colors.first;
}

SkinPalette paletteFor(CardSkin skin) => switch (skin) {
  CardSkin.classic => const SkinPalette([Color(0xFF3D4BFF), Color(0xFF7C4DFF)]),
  CardSkin.midnight => const SkinPalette([
    Color(0xFF0F1222),
    Color(0xFF2A2F55),
  ], glow: Color(0xFF3D4BFF)),
  CardSkin.aurora => const SkinPalette([
    Color(0xFF16A34A),
    Color(0xFF3D4BFF),
    Color(0xFF7C4DFF),
  ]),
  CardSkin.holo => const SkinPalette(
    [
      Color(0xFFFFB3C7),
      Color(0xFFB5F2FF),
      Color(0xFFC9B8FF),
      Color(0xFFFFE3A3),
    ],
    dark: true,
    glow: Color(0xFFC9B8FF),
  ),
  CardSkin.gold => const SkinPalette(
    [Color(0xFFB8860B), Color(0xFFFFD36E), Color(0xFFB8860B)],
    dark: true,
    glow: Color(0xFFFFD36E),
  ),
};

const cardSize = Size(260, 380);

/// Front of the card. [light] (-1..1) moves the shine, so it follows the
/// tilt; holo also shifts its colours.
class CardFront extends StatelessWidget {
  const CardFront({
    super.key,
    required this.profile,
    required this.mode,
    required this.skin,
    this.light = 0,
  });

  final ProfileData profile;
  final ProfileMode mode;
  final CardSkin skin;
  final double light;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(skin);
    final holo = skin == CardSkin.holo;
    final colors = holo
        ? [
            for (var i = 0; i < p.colors.length; i++)
              p.colors[(i + (light * 2).round().abs()) % p.colors.length],
          ]
        : p.colors;
    return SizedBox.fromSize(
      size: cardSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + light * 0.4, -1),
              end: Alignment(1 + light * 0.4, 1),
              colors: colors,
            ),
          ),
          child: Stack(
            children: [
              // Shine band that slides with the tilt.
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(light * 120, 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: const Alignment(-1, -0.6),
                        end: const Alignment(1, 0.6),
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: holo ? 0.45 : 0.25),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0.35, 0.5, 0.65],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'DEKAD',
                          style: DekadText.overline.copyWith(
                            color: p.foreground,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: p.chip,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            mode.name.toUpperCase(),
                            style: DekadText.overline.copyWith(
                              color: p.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.chip,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        initialsOf(profile.name),
                        style: DekadText.h2.copyWith(color: p.foreground),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DekadText.h1.copyWith(color: p.foreground),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.role,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DekadText.bodyStrong.copyWith(color: p.foreground),
                    ),
                    if (profile.company != null)
                      Text(
                        profile.company!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DekadText.label.copyWith(color: p.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back of the card: a big monogram on the skin.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.skin});

  final CardSkin skin;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(skin);
    return SizedBox.fromSize(
      size: cardSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
            colors: p.colors,
          ),
        ),
        child: Center(
          child: Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.chip,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Text(
              'D',
              style: DekadText.display.copyWith(
                color: p.foreground,
                fontSize: 52,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders [front]/[back] in 3D. Angles are in radians.
class Card3D extends StatelessWidget {
  const Card3D({
    super.key,
    required this.front,
    required this.back,
    this.rotX = 0,
    this.rotY = 0,
    this.rotZ = 0,
    this.glow,
  });

  final Widget front;
  final Widget back;
  final double rotX;
  final double rotY;
  final double rotZ;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final showBack = math.cos(rotX) * math.cos(rotY) < 0;
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateZ(rotZ)
      ..rotateX(rotX)
      ..rotateY(rotY);
    // The back is drawn pre-flipped so it reads correctly once turned.
    final face = showBack
        ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi),
            child: back,
          )
        : front;
    return Transform(
      alignment: Alignment.center,
      transform: m,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            const BoxShadow(
              color: Color(0x73000000),
              offset: Offset(0, 24),
              blurRadius: 40,
            ),
            if (glow != null)
              BoxShadow(color: glow!.withValues(alpha: 0.35), blurRadius: 48),
          ],
        ),
        child: face,
      ),
    );
  }
}

/// Where the card is at time [t] (0 = in hand, 1 = gone) for a send move.
/// Offsets are fractions of the screen size. Arrivals play it backwards.
class MoveFrame {
  const MoveFrame({
    this.dx = 0,
    this.dy = 0,
    this.rotX = 0,
    this.rotY = 0,
    this.rotZ = 0,
    this.scale = 1,
    this.opacity = 1,
  });

  final double dx, dy, rotX, rotY, rotZ, scale, opacity;
}

Duration moveDuration(SendMove m) => switch (m) {
  SendMove.toss => const Duration(milliseconds: 650),
  SendMove.flip => const Duration(milliseconds: 900),
  SendMove.spin => const Duration(milliseconds: 1000),
  SendMove.comet => const Duration(milliseconds: 1100),
  SendMove.supernova => const Duration(milliseconds: 1400),
};

MoveFrame moveFrame(SendMove m, double t) {
  final e = Curves.easeIn.transform(t);
  final fade = t > 0.85 ? (1 - (t - 0.85) / 0.15) : 1.0;
  switch (m) {
    case SendMove.toss:
      return MoveFrame(dy: -1.2 * e, rotX: 0.6 * t, scale: 1 - 0.35 * t);
    case SendMove.flip:
      return MoveFrame(
        dy: -1.2 * e,
        rotX: 2 * math.pi * Curves.easeInOut.transform(t),
        scale: 1 - 0.3 * t,
      );
    case SendMove.spin:
      return MoveFrame(
        dy: -1.2 * math.pow(t, 1.8).toDouble(),
        rotY: 4 * math.pi * Curves.easeOut.transform(t),
        scale: 1 - 0.3 * t,
      );
    case SendMove.comet:
      return MoveFrame(
        dx: 0.9 * e,
        dy: -1.25 * e,
        rotZ: 0.6 * t,
        rotY: 0.5 * t,
        scale: 1 - 0.55 * t,
      );
    case SendMove.supernova:
      // Charge up and glow, then collapse into a burst.
      if (t < 0.35) {
        final c = t / 0.35;
        return MoveFrame(
          scale: 1 + 0.25 * Curves.easeOut.transform(c),
          rotY: 0.4 * c,
        );
      }
      final c = (t - 0.35) / 0.65;
      return MoveFrame(
        scale: 1.25 * (1 - Curves.easeIn.transform(c)),
        rotY: 0.4 + 2 * math.pi * c,
        opacity: fade,
      );
  }
}

/// Comet trail and supernova burst behind the card.
class MoveParticles extends CustomPainter {
  MoveParticles({required this.move, required this.t, required this.color});

  final SendMove move;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (move == SendMove.comet && t > 0) {
      for (var i = 0; i < 14; i++) {
        final lag = (t - i * 0.035).clamp(0.0, 1.0);
        final f = moveFrame(move, lag);
        final p = center + Offset(f.dx * size.width, f.dy * size.height);
        final a = (1 - i / 14) * (1 - t * 0.6);
        canvas.drawCircle(
          p,
          18 * (1 - i / 14) + 4,
          Paint()
            ..color = color.withValues(alpha: 0.5 * a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
    }
    if (move == SendMove.supernova && t > 0.3) {
      final c = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        40 + 260 * c,
        Paint()
          ..color = color.withValues(alpha: 0.35 * (1 - c))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
      final rnd = math.Random(7);
      for (var i = 0; i < 28; i++) {
        final angle = rnd.nextDouble() * 2 * math.pi;
        final dist =
            (80 + rnd.nextDouble() * 220) * Curves.easeOut.transform(c);
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * dist,
          2 + rnd.nextDouble() * 3,
          Paint()..color = color.withValues(alpha: 1 - c),
        );
      }
    }
  }

  @override
  bool shouldRepaint(MoveParticles old) =>
      old.t != t || old.move != move || old.color != color;
}

/// Plays a send move (or an arrival when [arriving]) for a card.
/// [progress] runs 0→1.
class MovingCard extends StatelessWidget {
  const MovingCard({
    super.key,
    required this.move,
    required this.progress,
    required this.front,
    required this.back,
    required this.glow,
    this.arriving = false,
    this.rotX = 0,
    this.rotY = 0,
  });

  final SendMove move;
  final double progress;
  final Widget front;
  final Widget back;
  final Color glow;
  final bool arriving;

  /// Extra tilt from the user's drag.
  final double rotX;
  final double rotY;

  @override
  Widget build(BuildContext context) {
    final t = arriving ? 1 - progress : progress;
    final f = moveFrame(move, t);
    return LayoutBuilder(
      builder: (context, box) {
        final size = MediaQuery.sizeOf(context);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: MoveParticles(move: move, t: t, color: glow),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(f.dx * size.width, f.dy * size.height),
              child: Opacity(
                opacity: f.opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: f.scale,
                  child: Card3D(
                    front: front,
                    back: back,
                    rotX: f.rotX + rotX,
                    rotY: f.rotY + rotY,
                    rotZ: f.rotZ,
                    glow: glow,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

IconData moveIcon(SendMove m) => switch (m) {
  SendMove.toss => Icons.north_east,
  SendMove.flip => Icons.flip_camera_android,
  SendMove.spin => Icons.threesixty,
  SendMove.comet => Icons.auto_awesome,
  SendMove.supernova => Icons.flare,
};
