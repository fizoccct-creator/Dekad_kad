import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/exchange_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.profile, this.api});

  final UserProfile profile;
  final ApiService? api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  late UserProfile _profile = widget.profile;
  ProfileMode _mode = ProfileMode.professional;
  bool _rewriting = false;

  ProfileData get _current => _profile.forMode(_mode);

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _exchangeViaNfc() async {
    try {
      await ExchangeService.exchangeViaNfc(_current, _mode);
      _snack('Profile exchanged');
    } on UnimplementedError {
      _snack('NFC exchange is coming soon. Use the QR code for now.');
    } catch (e) {
      _snack('NFC exchange failed: $e');
    }
  }

  void _showQrCode() {
    final payload = ExchangeService.buildPayload(_current, _mode);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Your ${_mode.name} QR code'),
        content: SizedBox.square(
          dimension: 240,
          child: QrImageView(data: payload, backgroundColor: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _rewriteBio() async {
    setState(() => _rewriting = true);
    try {
      final bio = await _api.rewriteBio(_current.bio, _mode);
      if (!mounted) return;
      setState(() {
        final updated = _current.copyWith(bio: bio);
        _profile = _mode == ProfileMode.professional
            ? UserProfile(professional: updated, personal: _profile.personal)
            : UserProfile(
                professional: _profile.professional,
                personal: updated,
              );
      });
      _snack('Bio rewritten');
    } catch (e) {
      _snack('Could not rewrite bio: $e');
    } finally {
      if (mounted) setState(() => _rewriting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Dekad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ProfileMode>(
            segments: const [
              ButtonSegment(
                value: ProfileMode.professional,
                label: Text('Professional'),
                icon: Icon(Icons.work_outline),
              ),
              ButtonSegment(
                value: ProfileMode.personal,
                label: Text('Personal'),
                icon: Icon(Icons.person_outline),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 24),
          Text(_current.name, style: text.headlineMedium),
          Text(_current.role, style: text.titleMedium),
          if (_current.company != null) Text(_current.company!),
          const SizedBox(height: 16),
          Text(_current.bio, style: text.bodyMedium),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _showQrCode,
                icon: const Icon(Icons.qr_code),
                label: const Text('Show QR code'),
              ),
              OutlinedButton.icon(
                onPressed: _exchangeViaNfc,
                icon: const Icon(Icons.nfc),
                label: const Text('Exchange via NFC'),
              ),
              OutlinedButton.icon(
                onPressed: _rewriting ? null : _rewriteBio,
                icon: _rewriting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text('Rewrite bio'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
