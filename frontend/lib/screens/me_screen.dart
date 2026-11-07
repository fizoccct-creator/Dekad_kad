import 'package:flutter/material.dart';

import '../models/card_room.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../state/nearby_controller.dart';
import '../theme/tokens.dart';
import '../widgets/dekad_widgets.dart';
import 'badges_screen.dart';
import 'event_badge_screen.dart';

/// Profiles and settings (Figma: "Me — Profiles & settings").
class MeScreen extends StatelessWidget {
  const MeScreen({
    super.key,
    required this.state,
    required this.api,
    required this.onOpenProfile,
    required this.nearby,
    required this.onOpenNearby,
  });

  final AppState state;
  final ApiService api;

  /// Switches to [ProfileMode] and shows it on Home.
  final ValueChanged<ProfileMode> onOpenProfile;
  final NearbyController nearby;
  final VoidCallback onOpenNearby;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([state, nearby]),
      builder: (context, _) {
        final pro = state.profile.professional;
        final per = state.profile.personal;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                const Text('Me', style: DekadText.h1),
                const SizedBox(height: 16),
                const Overline('Your profiles'),
                const SizedBox(height: 8),
                _Group(
                  children: [
                    _Row(
                      icon: Icons.work_outline,
                      iconColor: DekadColors.pro,
                      iconBackground: DekadColors.proSoft,
                      title: 'Professional',
                      subtitle: '${pro.name} · ${pro.role}',
                      onTap: () => onOpenProfile(ProfileMode.professional),
                    ),
                    _Row(
                      icon: Icons.favorite_border,
                      iconColor: DekadColors.personal,
                      iconBackground: DekadColors.personalSoft,
                      title: 'Personal',
                      subtitle: '${per.name} · ${per.role}',
                      onTap: () => onOpenProfile(ProfileMode.personal),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Overline('At events'),
                const SizedBox(height: 8),
                _Group(
                  children: [
                    _Row(
                      icon: Icons.bluetooth,
                      iconColor: DekadColors.accent(state.mode),
                      iconBackground: DekadColors.accentSoft(state.mode),
                      title: 'Be visible nearby',
                      subtitle: 'Let people around you find you',
                      onTap: onOpenNearby,
                      trailing: Switch(
                        value:
                            nearby.isOn || nearby.phase == NearbyPhase.starting,
                        activeTrackColor: DekadColors.accent(state.mode),
                        onChanged: (v) => v ? onOpenNearby() : nearby.stop(),
                      ),
                    ),
                    _Row(
                      icon: Icons.military_tech,
                      iconColor: const Color(0xFFB8860B),
                      iconBackground: const Color(0xFFFFF4D6),
                      title: 'Badges',
                      subtitle: () {
                        final s = state.stats;
                        final n = badges.where((b) => b.earned(s)).length;
                        return '$n of ${badges.length} earned · unlock card moves and skins';
                      }(),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BadgesScreen(state: state),
                        ),
                      ),
                    ),
                    _Row(
                      icon: Icons.badge_outlined,
                      iconColor: DekadColors.ai,
                      iconBackground: DekadColors.aiSoft,
                      title: 'Event badge',
                      subtitle: state.badge == null
                          ? 'Let AI write one for your next event'
                          : '${state.badgeEvent} · AI written',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              EventBadgeScreen(state: state, api: api),
                        ),
                      ),
                    ),
                    _Row(
                      icon: Icons.nfc,
                      title: 'Tap to share (NFC)',
                      trailing: Switch(
                        value: state.nfcEnabled,
                        activeTrackColor: DekadColors.accent(state.mode),
                        onChanged: (v) => state.nfcEnabled = v,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DekadColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: DekadColors.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor = DekadColors.ink600,
    this.iconBackground = DekadColors.canvas,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DekadText.bodyStrong),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DekadText.caption,
                    ),
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right, color: DekadColors.ink400),
          ],
        ),
      ),
    );
  }
}
