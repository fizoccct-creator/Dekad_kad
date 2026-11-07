import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/dekad_widgets.dart';
import 'nfc_share_screen.dart';
import 'rewrite_bio_screen.dart';
import 'share_qr_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    this.api,
    this.state,
    this.onOpenNearby,
  });

  final UserProfile profile;
  final ApiService? api;

  /// Shared state from the app shell. When null (e.g. in tests) the screen
  /// keeps its own.
  final AppState? state;

  /// Opens the Nearby screen; hidden when null.
  final VoidCallback? onOpenNearby;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  late final AppState _state =
      widget.state ?? AppState(profile: widget.profile);

  @override
  void dispose() {
    if (widget.state == null) _state.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _editBio() async {
    final mode = _state.mode;
    final controller = TextEditingController(text: _state.current.bio);
    final bio = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DekadColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit ${mode.name} bio', style: DekadText.h2),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 300,
              style: DekadText.body,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: PillButton(
                label: 'Save',
                icon: Icons.check,
                accent: DekadColors.accent(mode),
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (bio != null && bio.isNotEmpty) _state.updateBio(mode, bio);
  }

  void _push(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final mode = _state.mode;
        final p = _state.current;
        final accent = DekadColors.accent(mode);
        final firstName = _state.profile.professional.name.split(' ').first;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                Text(_greeting, style: DekadText.caption),
                const SizedBox(height: 2),
                Text('Hi, $firstName', style: DekadText.h1),
                const SizedBox(height: 16),
                ModeToggle(mode: mode, onChanged: (m) => _state.mode = m),
                const SizedBox(height: 16),
                _ProfileCard(
                  profile: p,
                  mode: mode,
                  onEdit: _editBio,
                  onPolish: () =>
                      _push(RewriteBioScreen(state: _state, api: _api)),
                ),
                const SizedBox(height: 20),
                const Text('Share this profile', style: DekadText.h2),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PillButton(
                        label: 'Show QR',
                        icon: Icons.qr_code_2,
                        accent: accent,
                        onPressed: () =>
                            _push(ShareQrScreen(profile: p, mode: mode)),
                      ),
                    ),
                    if (_state.nfcEnabled) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: PillButton(
                          label: 'Tap (NFC)',
                          icon: Icons.nfc,
                          variant: PillVariant.secondary,
                          onPressed: () =>
                              _push(NfcShareScreen(profile: p, mode: mode)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Only your ${mode.name} profile is shared.',
                      style: DekadText.caption,
                    ),
                  ],
                ),
                if (widget.onOpenNearby != null) ...[
                  const SizedBox(height: 20),
                  _NearbyEntry(mode: mode, onTap: widget.onOpenNearby!),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

String linkLabel(String url) {
  final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
  return switch (host) {
    'linkedin.com' => 'LinkedIn',
    'twitter.com' || 'x.com' => 'X',
    'instagram.com' => 'Instagram',
    'github.com' => 'GitHub',
    _ => host,
  };
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.mode,
    required this.onEdit,
    required this.onPolish,
  });

  final ProfileData profile;
  final ProfileMode mode;
  final VoidCallback onEdit;
  final VoidCallback onPolish;

  @override
  Widget build(BuildContext context) {
    return DekadCard(
      radius: DekadRadius.card,
      padding: const EdgeInsets.all(20),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DekadAvatar(name: profile.name, mode: mode),
              const Spacer(),
              Material(
                color: DekadColors.canvas,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: DekadColors.ink600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Edit',
                          style: DekadText.label.copyWith(
                            color: DekadColors.ink600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Overline('${mode.name} profile', color: DekadColors.accent(mode)),
          const SizedBox(height: 4),
          Text(profile.name, style: DekadText.h1),
          Text(profile.role, style: DekadText.bodyStrong),
          if (profile.company != null)
            Text(
              profile.company!,
              style: DekadText.label.copyWith(color: DekadColors.ink400),
            ),
          const SizedBox(height: 16),
          Text(
            profile.bio,
            style: DekadText.body.copyWith(color: DekadColors.ink600),
          ),
          if (profile.links.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in profile.links) TagChip(label: linkLabel(l)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Material(
            color: DekadColors.aiSoft,
            borderRadius: BorderRadius.circular(DekadRadius.md),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPolish,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: DekadColors.ai,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Polish my bio with AI',
                        style: DekadText.label.copyWith(color: DekadColors.ai),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: DekadColors.ai,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyEntry extends StatelessWidget {
  const _NearbyEntry({required this.mode, required this.onTap});

  final ProfileMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = DekadColors.accent(mode);
    return Material(
      color: DekadColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DekadColors.accentSoft(mode),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bluetooth, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('People nearby', style: DekadText.bodyStrong),
                    Text(
                      'Find other Dekad users around you and connect',
                      style: DekadText.caption.copyWith(
                        color: DekadColors.ink600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
