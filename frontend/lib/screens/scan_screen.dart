import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/connection.dart';
import '../services/exchange_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/dekad_widgets.dart';
import 'nfc_share_screen.dart';
import 'share_qr_screen.dart';

/// Camera scanner for other people's Dekad QR codes (Figma: "Scan — Camera").
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handling = false;
  bool _torch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null) return;
    final profile = ExchangeService.parsePayload(raw);
    if (profile == null) {
      showSnack(context, 'That isn’t a Dekad profile code');
      return;
    }
    _handling = true;
    await _controller.stop();
    if (!mounted) return;
    final connection = Connection(
      connectionId: 'c${DateTime.now().microsecondsSinceEpoch}',
      userId: '',
      displayName: profile.name,
      role: [profile.role, ?profile.company].join(' · '),
      photoUrl: profile.photoUrl,
      timestamp: DateTime.now(),
      method: 'qr',
      location: '',
      notes: '',
      tags: const [],
    );
    // Save straight away so a dismissed sheet never loses the contact.
    widget.state.addConnection(connection);
    final scanNext = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DekadColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) =>
          ConnectionSavedSheet(state: widget.state, connection: connection),
    );
    if (!mounted) return;
    if (scanNext ?? false) {
      _handling = false;
      await _controller.start();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _replaceWith(Widget screen) => Navigator.of(
    context,
  ).pushReplacement(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final mode = widget.state.mode;
    final accent = DekadColors.accent(mode);
    final white70 = Colors.white.withValues(alpha: 0.7);
    return Scaffold(
      backgroundColor: DekadColors.ink900,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, _) => _CameraError(error),
          ),
          Container(color: DekadColors.ink900.withValues(alpha: 0.45)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.close,
                        tooltip: 'Close',
                        background: Colors.white.withValues(alpha: 0.14),
                        color: DekadColors.surface,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Scan a code',
                          style: DekadText.h2.copyWith(
                            color: DekadColors.surface,
                          ),
                        ),
                      ),
                      CircleIconButton(
                        icon: _torch ? Icons.flash_on : Icons.flash_off,
                        tooltip: 'Flashlight',
                        background: Colors.white.withValues(alpha: 0.14),
                        color: DekadColors.surface,
                        onPressed: () async {
                          await _controller.toggleTorch();
                          if (mounted) setState(() => _torch = !_torch);
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  _Viewfinder(color: accent),
                  const SizedBox(height: 24),
                  Text(
                    'Point at someone’s Dekad QR code',
                    style: DekadText.bodyStrong.copyWith(
                      color: DekadColors.surface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'They’ll be saved to your connections.',
                    style: DekadText.caption.copyWith(color: white70),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Segment(label: 'Scan', selected: true, onTap: () {}),
                        _Segment(
                          label: 'My code',
                          onTap: () => _replaceWith(
                            ShareQrScreen(
                              profile: widget.state.current,
                              mode: mode,
                            ),
                          ),
                        ),
                        if (widget.state.nfcEnabled)
                          _Segment(
                            label: 'Tap NFC',
                            onTap: () => _replaceWith(
                              NfcShareScreen(
                                profile: widget.state.current,
                                mode: mode,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError(this.error);

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final text = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Camera access is off. Turn it on in Settings to scan codes.',
      MobileScannerErrorCode.unsupported =>
        'This device has no camera we can use.',
      _ => 'The camera couldn’t start.',
    };
    return ColoredBox(
      color: DekadColors.ink900,
      child: Align(
        alignment: const Alignment(0, -0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            '$text\nYou can still share yours with “My code”.',
            textAlign: TextAlign.center,
            style: DekadText.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? DekadColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: DekadText.label.copyWith(
            color: selected
                ? DekadColors.ink900
                : Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 260,
      child: CustomPaint(painter: _CornerPainter(color)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const len = 40.0, r = 16.0, i = 4.0;
    final w = size.width, h = size.height;
    final corners = [
      Path()
        ..moveTo(i, i + len)
        ..lineTo(i, i + r)
        ..arcToPoint(const Offset(i + r, i), radius: const Radius.circular(r))
        ..lineTo(i + len, i),
      Path()
        ..moveTo(w - i - len, i)
        ..lineTo(w - i - r, i)
        ..arcToPoint(Offset(w - i, i + r), radius: const Radius.circular(r))
        ..lineTo(w - i, i + len),
      Path()
        ..moveTo(w - i, h - i - len)
        ..lineTo(w - i, h - i - r)
        ..arcToPoint(Offset(w - i - r, h - i), radius: const Radius.circular(r))
        ..lineTo(w - i - len, h - i),
      Path()
        ..moveTo(i + len, h - i)
        ..lineTo(i + r, h - i)
        ..arcToPoint(Offset(i, h - i - r), radius: const Radius.circular(r))
        ..lineTo(i, h - i - len),
    ];
    for (final p in corners) {
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

/// Bottom sheet shown after a successful scan (Figma: "Scan — Connection
/// saved"). Pops `true` for "Scan next".
class ConnectionSavedSheet extends StatefulWidget {
  const ConnectionSavedSheet({
    super.key,
    required this.state,
    required this.connection,
  });

  final AppState state;

  /// Already added to [state]; the sheet only adds notes and tags.
  final Connection connection;

  @override
  State<ConnectionSavedSheet> createState() => _ConnectionSavedSheetState();
}

class _ConnectionSavedSheetState extends State<ConnectionSavedSheet> {
  static const _quickTags = ['Follow up', 'Investor', 'Hiring', 'Intro'];
  final _note = TextEditingController();
  final _tags = <String>{};

  Connection get _connection => widget.connection;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _finish(bool scanNext) {
    widget.state.updateConnection(
      _connection.copyWith(notes: _note.text.trim(), tags: _tags.toList()),
    );
    Navigator.of(context).pop(scanNext);
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.state.mode;
    final first = _connection.displayName.split(' ').first;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: DekadColors.ink200,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: DekadColors.successSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 28,
                color: DekadColors.success,
              ),
            ),
            const SizedBox(height: 16),
            const Text('You’re connected!', style: DekadText.h1),
            const SizedBox(height: 4),
            Text(
              '$first is saved to your connections. '
              'Share your ${mode.name} profile back from Home.',
              textAlign: TextAlign.center,
              style: DekadText.label.copyWith(color: DekadColors.ink400),
            ),
            const SizedBox(height: 16),
            ContactTile(connection: _connection),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 1,
              maxLines: 3,
              style: DekadText.body,
              decoration: const InputDecoration(
                labelText: 'Quick note',
                hintText: 'What did you talk about?',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _quickTags)
                    TagChip(
                      label: t,
                      mode: mode,
                      tone: _tags.contains(t)
                          ? ChipTone.accent
                          : ChipTone.neutral,
                      background: _tags.contains(t) ? null : DekadColors.line,
                      onTap: () => setState(
                        () =>
                            _tags.contains(t) ? _tags.remove(t) : _tags.add(t),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Scan next',
                    icon: Icons.qr_code_scanner,
                    variant: PillVariant.secondary,
                    onPressed: () => _finish(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PillButton(
                    label: 'Done',
                    icon: Icons.check,
                    accent: DekadColors.accent(mode),
                    onPressed: () => _finish(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
