import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/connection.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/dekad_widgets.dart';

/// One saved connection with notes, AI summary and follow-up
/// (Figma: "Contact — Detail").
class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({
    super.key,
    required this.state,
    required this.api,
    required this.connectionId,
  });

  final AppState state;
  final ApiService api;
  final String connectionId;

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  late final TextEditingController _notes = TextEditingController(
    text: _connection.notes,
  );
  List<String>? _summary;
  FollowUpSuggestion? _followUp;
  bool _summarizing = false;
  bool _suggesting = false;

  Connection get _connection => widget.state.connections.firstWhere(
    (c) => c.connectionId == widget.connectionId,
  );

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _saveNotes() {
    final text = _notes.text.trim();
    if (text == _connection.notes) return;
    widget.state.updateConnection(_connection.copyWith(notes: text));
  }

  Future<void> _summarize() async {
    _saveNotes();
    if (_notes.text.trim().isEmpty) {
      showSnack(context, 'Add a few notes first');
      return;
    }
    setState(() => _summarizing = true);
    try {
      final bullets = await widget.api.summarizeNotes(_notes.text.trim());
      if (mounted) setState(() => _summary = bullets);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not summarize: $e');
    } finally {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  Future<void> _suggest() async {
    _saveNotes();
    final c = _connection;
    final context_ = [
      'Met ${c.displayName} (${c.role})'
          '${c.location.isEmpty ? '' : ' at ${c.location}'}.',
      if (c.notes.isNotEmpty) 'Notes: ${c.notes}',
    ].join(' ');
    setState(() => _suggesting = true);
    try {
      final s = await widget.api.suggestFollowUp(
        c.connectionId,
        context_,
        c.timestamp,
      );
      if (mounted) setState(() => _followUp = s);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not suggest a follow-up: $e');
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  String _when(int days) => switch (days) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => 'In $days days',
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final c = _connection;
        final met = [
          if (c.location.isNotEmpty) 'Met at ${c.location}',
          formatMetTime(c.timestamp),
          'via ${methodLabel(c.method)}',
        ].join(' · ');
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: CircleIconButton(
                    icon: Icons.chevron_left,
                    tooltip: 'Back',
                    onPressed: () {
                      _saveNotes();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    DekadAvatar(name: c.displayName),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.displayName, style: DekadText.h1),
                          Text(
                            c.role,
                            style: DekadText.label.copyWith(
                              color: DekadColors.ink600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DekadCard(
                  radius: 14,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: DekadColors.pro,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          met,
                          style: DekadText.caption.copyWith(
                            color: DekadColors.ink600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (c.tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in c.tags)
                        TagChip(label: t, background: DekadColors.line),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                DekadCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Overline('Your notes', icon: Icons.notes),
                      TextField(
                        controller: _notes,
                        minLines: 2,
                        maxLines: 8,
                        style: DekadText.body,
                        onTapOutside: (_) {
                          FocusScope.of(context).unfocus();
                          _saveNotes();
                        },
                        decoration: const InputDecoration(
                          hintText: 'What did you talk about?',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                      if (_summary != null) ...[
                        const Divider(color: DekadColors.line, height: 24),
                        const Overline(
                          'AI summary',
                          color: DekadColors.ai,
                          icon: Icons.auto_awesome,
                        ),
                        const SizedBox(height: 8),
                        for (final b in _summary!)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: DekadColors.ai,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(b, style: DekadText.body)),
                              ],
                            ),
                          ),
                      ],
                      const SizedBox(height: 4),
                      PillButton(
                        label: _summary == null
                            ? 'Summarize with AI'
                            : 'Summarize again',
                        icon: Icons.auto_awesome,
                        variant: PillVariant.ai,
                        height: 40,
                        loading: _summarizing,
                        onPressed: _summarize,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                DekadCard(
                  color: DekadColors.aiSoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Follow-up',
                              style: DekadText.bodyStrong,
                            ),
                          ),
                          if (_followUp != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: DekadColors.surface,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 14,
                                    color: DekadColors.ai,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_followUp!.channel[0].toUpperCase()}'
                                    '${_followUp!.channel.substring(1)} · '
                                    '${_when(_followUp!.delayDays)}',
                                    style: DekadText.caption.copyWith(
                                      color: DekadColors.ai,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _followUp == null
                            ? 'Let AI draft a message and pick the best time '
                                  'and channel to reach out.'
                            : '“${_followUp!.message}”',
                        style: DekadText.body.copyWith(
                          color: DekadColors.ink600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (_followUp != null) ...[
                            Expanded(
                              child: PillButton(
                                label: 'Copy',
                                icon: Icons.copy_rounded,
                                variant: PillVariant.secondary,
                                height: 44,
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: _followUp!.message),
                                  );
                                  if (context.mounted) {
                                    showSnack(context, 'Message copied');
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: PillButton(
                              label: _followUp == null
                                  ? 'Draft follow-up'
                                  : 'Redraft',
                              icon: _followUp == null
                                  ? Icons.send_outlined
                                  : Icons.refresh,
                              accent: DekadColors.ai,
                              height: 44,
                              loading: _suggesting,
                              onPressed: _suggest,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
