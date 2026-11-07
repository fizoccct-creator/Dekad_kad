import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/user_profile.dart';
import '../services/exchange_service.dart';
import '../theme/tokens.dart';
import '../widgets/dekad_widgets.dart';
import 'nfc_share_screen.dart';

/// Full-screen QR code for the active profile (Figma: "Share — QR code").
class ShareQrScreen extends StatelessWidget {
  const ShareQrScreen({super.key, required this.profile, required this.mode});

  final ProfileData profile;
  final ProfileMode mode;

  String get _plainText => [
    profile.name,
    [profile.role, ?profile.company].join(' · '),
    ...profile.links,
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final accent = DekadColors.accent(mode);
    final payload = ExchangeService.buildPayload(profile, mode);
    final other = mode == ProfileMode.professional
        ? 'Personal'
        : 'Professional';
    return Scaffold(
      backgroundColor: accent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            children: [
              Row(
                children: [
                  CircleIconButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    background: Colors.white.withValues(alpha: 0.2),
                    color: DekadColors.surface,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Share profile',
                      style: DekadText.h2.copyWith(color: DekadColors.surface),
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
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                decoration: BoxDecoration(
                  color: DekadColors.surface,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: cardShadow,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        DekadAvatar(name: profile.name, size: 44, mode: mode),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(profile.name, style: DekadText.bodyStrong),
                              Text(
                                profile.role,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DekadText.caption.copyWith(
                                  color: DekadColors.ink600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    QrImageView(
                      data: payload,
                      size: 232,
                      backgroundColor: DekadColors.surface,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: DekadColors.ink900,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.circle,
                        color: DekadColors.ink900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scan with Dekad or any phone camera',
                      style: DekadText.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Copy info',
                      icon: Icons.copy_rounded,
                      variant: PillVariant.secondary,
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: _plainText),
                        );
                        if (context.mounted) {
                          showSnack(context, 'Profile details copied');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PillButton(
                      label: 'Tap phones',
                      icon: Icons.nfc,
                      variant: PillVariant.secondary,
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              NfcShareScreen(profile: profile, mode: mode),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Switch to $other to share a different profile.',
                style: DekadText.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
