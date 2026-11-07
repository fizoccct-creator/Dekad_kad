import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/dekad_widgets.dart';

/// Current bio vs. AI suggestion (Figma: "AI — Rewrite bio").
class RewriteBioScreen extends StatefulWidget {
  const RewriteBioScreen({super.key, required this.state, required this.api});

  final AppState state;
  final ApiService api;

  @override
  State<RewriteBioScreen> createState() => _RewriteBioScreenState();
}

class _RewriteBioScreenState extends State<RewriteBioScreen> {
  static const _maxLength = 200;
  late final ProfileMode _mode = widget.state.mode;
  late final String _original = widget.state.profile.forMode(_mode).bio;
  String? _suggestion;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bio = await widget.api.rewriteBio(
        _original,
        _mode,
        maxLength: _maxLength,
      );
      if (mounted) setState(() => _suggestion = bio);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not rewrite bio: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply() {
    widget.state.updateBio(_mode, _suggestion!);
    showSnack(context, 'Bio updated');
    Navigator.of(context).pop();
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rewrite bio', style: DekadText.h2),
                          Text(
                            'For your ${_mode.name} profile',
                            style: DekadText.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DekadCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Overline('Current'),
                        const SizedBox(height: 8),
                        Text(
                          _original,
                          style: DekadText.body.copyWith(
                            color: DekadColors.ink600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DekadCard(
                    border: DekadColors.ai,
                    elevated: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Overline(
                          'AI suggestion',
                          color: DekadColors.ai,
                          icon: Icons.auto_awesome,
                        ),
                        const SizedBox(height: 10),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(
                              color: DekadColors.ai,
                              backgroundColor: DekadColors.aiSoft,
                            ),
                          )
                        else if (_error != null)
                          Text(
                            _error!,
                            style: DekadText.body.copyWith(
                              color: DekadColors.ink600,
                            ),
                          )
                        else if (_suggestion != null)
                          Text(_suggestion!, style: DekadText.body),
                      ],
                    ),
                  ),
                  if (_suggestion != null && !_loading) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${_suggestion!.length} / $_maxLength characters',
                      style: DekadText.caption,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Try again',
                      icon: Icons.refresh,
                      variant: PillVariant.secondary,
                      onPressed: _loading ? null : _generate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PillButton(
                      label: 'Use this bio',
                      icon: Icons.check,
                      accent: DekadColors.accent(_mode),
                      onPressed: _loading || _suggestion == null
                          ? null
                          : _apply,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
