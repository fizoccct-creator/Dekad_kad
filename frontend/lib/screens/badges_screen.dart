import 'package:flutter/material.dart';

import '../models/card_room.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/dekad_widgets.dart';

const _badgeColors = [
  DekadColors.pro,
  DekadColors.ai,
  DekadColors.success,
  DekadColors.personal,
  Color(0xFFB8860B),
];

/// Earned and locked badges, and what each unlocks in the Card Room
/// (Figma: "Badges — Unlocks").
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = state.stats;
        final earned = badges.where((b) => b.earned(s)).length;
        final next = nextUnlock(s);
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.chevron_left,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Badges', style: DekadText.h2),
                        Text(
                          '$earned of ${badges.length} earned · unlock moves and skins',
                          style: DekadText.caption,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (next != null) _NextUnlock(badge: next, stats: s),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, box) {
                    final w = (box.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final (i, b) in badges.indexed)
                          SizedBox(
                            width: w,
                            child: _BadgeTile(
                              badge: b,
                              stats: s,
                              color: _badgeColors[i % _badgeColors.length],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NextUnlock extends StatelessWidget {
  const _NextUnlock({required this.badge, required this.stats});

  final BadgeDef badge;
  final DekadStats stats;

  @override
  Widget build(BuildContext context) {
    final done = badge.progress(stats);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1222), Color(0xFF2A2F55)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFFFFD36E)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXT UNLOCK · ${badge.unlocksLabel.toUpperCase()}',
                      style: DekadText.overline.copyWith(
                        color: const Color(0xFFFFD36E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${badge.requirement} to earn ${badge.name}',
                      style: DekadText.bodyStrong.copyWith(
                        color: DekadColors.surface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: done / badge.goal,
              minHeight: 8,
              color: const Color(0xFFFFD36E),
              backgroundColor: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$done / ${badge.goal}',
            style: DekadText.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.badge,
    required this.stats,
    required this.color,
  });

  final BadgeDef badge;
  final DekadStats stats;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final earned = badge.earned(stats);
    final c = earned ? color : DekadColors.ink400;
    return Opacity(
      opacity: earned ? 1 : 0.65,
      child: DekadCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                earned ? Icons.military_tech : Icons.lock_outline,
                size: 18,
                color: c,
              ),
            ),
            const SizedBox(height: 8),
            Text(badge.name, style: DekadText.bodyStrong),
            Text(badge.requirement, style: DekadText.caption),
            if (!earned)
              Text(
                '${badge.progress(stats)} / ${badge.goal}',
                style: DekadText.caption,
              ),
            if (badge.unlocksLabel.isNotEmpty)
              Text(
                'Unlocks ${badge.unlocksLabel}',
                style: DekadText.caption.copyWith(
                  color: earned ? DekadColors.ai : DekadColors.ink400,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
