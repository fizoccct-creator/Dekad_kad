import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'contacts_screen.dart';
import 'home_screen.dart';
import 'me_screen.dart';
import 'scan_screen.dart';

/// Tab bar shell: Home, Contacts, Scan (opens full screen), Me.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state, this.api});

  final AppState state;
  final ApiService? api;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final ApiService _api = widget.api ?? ApiService();
  int _tab = 0; // 0 home, 1 contacts, 2 me

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
              HomeScreen(profile: state.profile, api: _api, state: state),
              ContactsScreen(state: state, api: _api, onAdd: _openScanner),
              MeScreen(
                state: state,
                api: _api,
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
