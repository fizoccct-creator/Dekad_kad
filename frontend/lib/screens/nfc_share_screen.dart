import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/exchange_service.dart';
import '../theme/tokens.dart';
import '../widgets/dekad_widgets.dart';
import 'share_qr_screen.dart';

enum _NfcStatus { searching, done, failed }

/// "Hold phones back to back" (Figma: "Share — NFC tap").
class NfcShareScreen extends StatefulWidget {
  const NfcShareScreen({super.key, required this.profile, required this.mode});

  final ProfileData profile;
  final ProfileMode mode;

  @override
  State<NfcShareScreen> createState() => _NfcShareScreenState();
}

class _NfcShareScreenState extends State<NfcShareScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  _NfcStatus _status = _NfcStatus.searching;
  String _message = 'Looking for a nearby phone…';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _status = _NfcStatus.searching;
      _message = 'Looking for a nearby phone…';
    });
    try {
      await ExchangeService.exchangeViaNfc(widget.profile, widget.mode);
      if (!mounted) return;
      setState(() {
        _status = _NfcStatus.done;
        _message = 'Profile exchanged';
      });
    } on UnimplementedError {
      _fail('NFC exchange is coming soon. Use the QR code for now.');
    } on StateError catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('NFC exchange failed: $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    _pulse.stop();
    setState(() {
      _status = _NfcStatus.failed;
      _message = message;
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final accent = DekadColors.accent(mode);
    return Scaffold(
      backgroundColor: DekadColors.accentSoft(mode),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleIconButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
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
              const Spacer(),
              SizedBox.square(
                dimension: 280,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final t = _pulse.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        for (final (d, a) in const [
                          (280.0, 0.08),
                          (220.0, 0.14),
                          (160.0, 0.22),
                        ])
                          Container(
                            width: d * (0.94 + 0.06 * t),
                            height: d * (0.94 + 0.06 * t),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: a),
                            ),
                          ),
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _status == _NfcStatus.done
                                ? Icons.check
                                : Icons.nfc,
                            size: 44,
                            color: DekadColors.surface,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Hold phones back to back',
                textAlign: TextAlign.center,
                style: DekadText.h1,
              ),
              const SizedBox(height: 8),
              Text(
                'Only your ${mode.name} profile will be shared. '
                'You’ll get theirs in return.',
                textAlign: TextAlign.center,
                style: DekadText.body.copyWith(color: DekadColors.ink600),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: DekadColors.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_status == _NfcStatus.searching)
                      SizedBox.square(
                        dimension: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    else
                      Icon(
                        _status == _NfcStatus.done
                            ? Icons.check_circle
                            : Icons.info_outline,
                        size: 16,
                        color: _status == _NfcStatus.done
                            ? DekadColors.success
                            : DekadColors.ink400,
                      ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _message,
                        style: DekadText.label.copyWith(
                          color: DekadColors.ink600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_status == _NfcStatus.failed)
                TextButton(
                  onPressed: () {
                    _pulse.repeat();
                    _start();
                  },
                  child: const Text('Try again'),
                ),
              PillButton(
                label: 'Show QR code instead',
                icon: Icons.qr_code_2,
                variant: PillVariant.ghost,
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ShareQrScreen(profile: widget.profile, mode: mode),
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
