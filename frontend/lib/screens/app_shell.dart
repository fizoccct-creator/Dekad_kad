import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../state/app_state.dart';
import '../state/nearby_controller.dart';
import '../theme/tokens.dart';
import 'contacts_screen.dart';
import 'home_screen.dart';
import 'me_screen.dart';
import 'nearby_screen.dart';
import 'scan_screen.dart';

/// Tab bar shell: Home, Contacts, Scan (opens full screen), Me.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.state,
    required this.nearby,
    this.api,
  });

  final AppState state;
  final NearbyController nearby;
  final ApiService? api;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final ApiService _api = widget.api ?? ApiService();
  int _tab = 0; // 0 home, 1 contacts, 2 me
  late final StreamSubscription<IncomingNearbyRequest> _incomingSub;
  final _pending = <IncomingNearbyRequest>[];
  bool _showingRequest = false;

  @override
  void initState() {
    super.initState();
    _incomingSub = widget.nearby.incoming.listen((r) {
      _pending.add(r);
      _showNextRequest();
    });
  }

  @override
  void dispose() {
    _incomingSub.cancel();
    super.dispose();
  }

  /// Shows incoming Nearby requests one at a time, on any tab.
  Future<void> _showNextRequest() async {
    if (_showingRequest || _pending.isEmpty || !mounted) return;
    _showingRequest = true;
    final r = _pending.removeAt(0);
    final state = widget.state;
    final accept = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: DekadColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => NearbyRequestSheet(
        request: r,
        myMode: state.mode,
        myName: state.current.name,
      ),
    );
    await widget.nearby.respond(r, accept: accept ?? false);
    if (mounted && (accept ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${r.profile.name} saved to your connections')),
      );
    }
    _showingRequest = false;
    _showNextRequest();
  }

  void _openNearby() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NearbyScreen(controller: widget.nearby),
    ),
  );

  void _openScanner() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ScanScreen(state: widget.state),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final accent = DekadColors.accent(state.mode);
        Widget item(int? tab, String label, IconData icon, IconData active) {
          final on = tab == _tab;
          final color = on ? accent : DekadColors.ink400;
          return Expanded(
            child: InkResponse(
              onTap: tab == null
                  ? _openScanner
                  : () => setState(() => _tab = tab),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(on ? active : icon, color: color),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: DekadText.caption.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: _tab,
            children: [
              HomeScreen(
                profile: state.profile,
                api: _api,
                state: state,
                onOpenNearby: _openNearby,
              ),
              ContactsScreen(state: state, api: _api, onAdd: _openScanner),
              MeScreen(
                state: state,
                api: _api,
                nearby: widget.nearby,
                onOpenNearby: _openNearby,
                onOpenProfile: (mode) {
                  state.mode = mode;
                  setState(() => _tab = 0);
                },
              ),
            ],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              color: DekadColors.surface,
              border: Border(top: BorderSide(color: DekadColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                child: Row(
                  children: [
                    item(0, 'Home', Icons.home_outlined, Icons.home),
                    item(1, 'Contacts', Icons.people_outline, Icons.people),
                    item(
                      null,
                      'Scan',
                      Icons.qr_code_scanner,
                      Icons.qr_code_scanner,
                    ),
                    item(2, 'Me', Icons.person_outline, Icons.person),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
