import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/dekad_widgets.dart';

/// AI-written badge for an event (Figma: "AI — Event badge").
/// Always uses the professional profile.
class EventBadgeScreen extends StatefulWidget {
  const EventBadgeScreen({super.key, required this.state, required this.api});

  final AppState state;
  final ApiService api;

  @override
  State<EventBadgeScreen> createState() => _EventBadgeScreenState();
}

class _EventBadgeScreenState extends State<EventBadgeScreen> {
  late final _event = TextEditingController(
    text: widget.state.badgeEvent.isEmpty
        ? 'Web Summit 2026, Lisbon'
        : widget.state.badgeEvent,
  );
  final _goal = TextEditingController();
  late BadgeText? _badge = widget.state.badge;
  bool _loading = false;

  ProfileData get _pro => widget.state.profile.professional;

  @override
  void dispose() {
    _event.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final event = _event.text.trim();
    if (event.isEmpty) {
      showSnack(context, 'Add the event first');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final goal = _goal.text.trim();
      final badge = await widget.api.generateBadgeText(
        'badge-${DateTime.now().millisecondsSinceEpoch}',
        goal.isEmpty ? event : '$event. My goal: $goal',
        [_pro.role, ?_pro.company].join(' at '),
      );
      if (mounted) setState(() => _badge = badge);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not write the badge: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Event badge', style: DekadText.h2),
                          Text(
                            'Written from your professional profile',
                            style: DekadText.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _event,
                    style: DekadText.body,
                    decoration: const InputDecoration(
                      labelText: 'Event',
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _goal,
                    style: DekadText.body,
                    decoration: const InputDecoration(
                      labelText: 'Your goal (optional)',
                      hintText: 'e.g. hiring PMs, meeting investors',
                      prefixIcon: Icon(Icons.work_outline, size: 18),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_badge != null)
                    Center(
                      child: _BadgeCard(
                        event: _event.text.split(',').first.trim(),
                        profile: _pro,
                        badge: _badge!,
                      ),
                    )
                  else
                    DekadCard(
                      color: DekadColors.aiSoft,
                      child: Text(
                        'Tell us the event and AI will write a short title, '
                        'message and call to action for your badge.',
                        style: DekadText.body.copyWith(color: DekadColors.ai),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: _badge == null ? 'Write my badge' : 'Regenerate',
                      icon: _badge == null ? Icons.auto_awesome : Icons.refresh,
                      variant: PillVariant.ai,
                      loading: _loading,
                      onPressed: _generate,
                    ),
                  ),
                  if (_badge != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: PillButton(
                        label: 'Save badge',
                        icon: Icons.check,
                        onPressed: _loading
                            ? null
                            : () {
                                widget.state.saveBadge(
                                  _event.text.trim(),
                                  _badge!,
                                );
                                showSnack(context, 'Badge saved');
                                Navigator.of(context).pop();
                              },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.event,
    required this.profile,
    required this.badge,
  });

  final String event;
  final ProfileData profile;
  final BadgeText badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: DekadColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: DekadColors.pro,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  event.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: DekadText.overline.copyWith(
                    color: DekadColors.surface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DekadAvatar(name: profile.name),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.name, style: DekadText.h2),
                          Text(
                            [profile.role, ?profile.company].join(' · '),
                            maxLines: 2,
                            style: DekadText.caption.copyWith(
                              color: DekadColors.ink600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  badge.title,
                  style: DekadText.h2.copyWith(color: DekadColors.pro),
                ),
                const SizedBox(height: 8),
                Text(
                  badge.message,
                  style: DekadText.label.copyWith(color: DekadColors.ink600),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: DekadColors.proSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          badge.cta,
                          style: DekadText.label.copyWith(
                            color: DekadColors.pro,
                          ),
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: DekadColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.qr_code_2, size: 22),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
