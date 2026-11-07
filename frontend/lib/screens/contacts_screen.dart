import 'package:flutter/material.dart';

import '../models/connection.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/dekad_widgets.dart';
import 'contact_detail_screen.dart';

/// Saved connections grouped by day (Figma: "Contacts").
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({
    super.key,
    required this.state,
    required this.api,
    this.onAdd,
  });

  final AppState state;
  final ApiService api;

  /// Opens the scanner.
  final VoidCallback? onAdd;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String _query = '';
  String? _place; // null = all

  bool _matches(Connection c) {
    if (_place != null && c.location != _place) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return [
      c.displayName,
      c.role,
      c.notes,
      c.location,
      ...c.tags,
    ].any((s) => s.toLowerCase().contains(q));
  }

  String _groupOf(Connection c) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(c.timestamp.year, c.timestamp.month, c.timestamp.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff < 7) return 'This week';
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final all = widget.state.connections;
        final places = {
          for (final c in all)
            if (c.location.isNotEmpty) c.location,
        }.toList();
        final shown = all.where(_matches).toList();
        final groups = <String, List<Connection>>{};
        for (final c in shown) {
          groups.putIfAbsent(_groupOf(c), () => []).add(c);
        }
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Connections', style: DekadText.h1),
                          Text(
                            '${all.length} people · ${places.length} places',
                            style: DekadText.caption,
                          ),
                        ],
                      ),
                    ),
                    if (widget.onAdd != null)
                      CircleIconButton(
                        icon: Icons.add,
                        tooltip: 'Scan a code',
                        background: DekadColors.accent(widget.state.mode),
                        color: DekadColors.surface,
                        onPressed: widget.onAdd,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: DekadText.body,
                  decoration: InputDecoration(
                    hintText: 'Search names, companies, notes',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: DekadColors.ink400,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(
                        color: DekadColors.accent(widget.state.mode),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      for (final p in [null, ...places])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TagChip(
                            label: p ?? 'All',
                            mode: widget.state.mode,
                            tone: p == _place
                                ? ChipTone.accent
                                : ChipTone.neutral,
                            background: p == _place
                                ? null
                                : DekadColors.surface,
                            onTap: () => setState(() => _place = p),
                          ),
                        ),
                    ],
                  ),
                ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Text(
                      all.isEmpty
                          ? 'No connections yet. Scan someone’s code to add them.'
                          : 'No one matches that search.',
                      textAlign: TextAlign.center,
                      style: DekadText.body.copyWith(color: DekadColors.ink400),
                    ),
                  ),
                for (final entry in groups.entries) ...[
                  const SizedBox(height: 16),
                  Overline(entry.key),
                  const SizedBox(height: 8),
                  for (final c in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ContactTile(
                        connection: c,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ContactDetailScreen(
                              state: widget.state,
                              api: widget.api,
                              connectionId: c.connectionId,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
