import 'package:flutter/material.dart';

import '../models/connection.dart';
import '../models/user_profile.dart';
import '../theme/tokens.dart';

enum PillVariant { primary, secondary, ai, ghost }

/// Figma component "Button".
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = PillVariant.primary,
    this.accent = DekadColors.pro,
    this.loading = false,
    this.height = 52,
    this.foreground,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final PillVariant variant;
  final Color accent;
  final bool loading;
  final double height;

  /// Overrides the text/icon colour (e.g. ghost buttons on dark screens).
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      PillVariant.primary => (accent, DekadColors.surface, null),
      PillVariant.secondary => (
        DekadColors.surface,
        DekadColors.ink900,
        DekadColors.line,
      ),
      PillVariant.ai => (DekadColors.aiSoft, DekadColors.ai, null),
      PillVariant.ghost => (Colors.transparent, DekadColors.ink900, null),
    };
    final color = foreground ?? fg;
    final disabled = onPressed == null || loading;
    return Opacity(
      opacity: onPressed == null && !loading ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: border == null
              ? BorderSide.none
              : BorderSide(color: border, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, size: 20, color: color),
                  if (loading || icon != null) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: DekadText.bodyStrong.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma component "Mode Toggle".
class ModeToggle extends StatelessWidget {
  const ModeToggle({super.key, required this.mode, required this.onChanged});

  final ProfileMode mode;
  final ValueChanged<ProfileMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(ProfileMode m, String label, IconData icon) {
      final on = m == mode;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: on ? DekadColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: on ? raisedShadow : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: on ? DekadColors.accent(m) : DekadColors.ink400,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: DekadText.label.copyWith(
                    color: on ? DekadColors.ink900 : DekadColors.ink400,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DekadColors.line,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          segment(ProfileMode.professional, 'Professional', Icons.work_outline),
          const SizedBox(width: 4),
          segment(ProfileMode.personal, 'Personal', Icons.favorite_border),
        ],
      ),
    );
  }
}

String initialsOf(String name) {
  final parts = name
      .replaceAll('.', '')
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

/// Figma component "Avatar".
class DekadAvatar extends StatelessWidget {
  const DekadAvatar({
    super.key,
    required this.name,
    this.size = 56,
    this.mode = ProfileMode.professional,
  });

  final String name;
  final double size;
  final ProfileMode mode;

  @override
  Widget build(BuildContext context) {
    final style = size >= 80
        ? DekadText.h1
        : size >= 52
        ? DekadText.h2
        : DekadText.bodyStrong;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: DekadColors.accentSoft(mode),
        shape: BoxShape.circle,
      ),
      child: Text(
        initialsOf(name),
        style: style.copyWith(color: DekadColors.accent(mode)),
      ),
    );
  }
}

enum ChipTone { neutral, accent, ai }

/// Figma component "Chip".
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.tone = ChipTone.neutral,
    this.mode = ProfileMode.professional,
    this.background,
    this.onTap,
  });

  final String label;
  final ChipTone tone;
  final ProfileMode mode;
  final Color? background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      ChipTone.neutral => (DekadColors.canvas, DekadColors.ink600),
      ChipTone.accent => (
        DekadColors.accentSoft(mode),
        DekadColors.accent(mode),
      ),
      ChipTone.ai => (DekadColors.aiSoft, DekadColors.ai),
    };
    return Material(
      color: background ?? bg,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(label, style: DekadText.label.copyWith(color: fg)),
        ),
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.background = DekadColors.surface,
    this.color = DekadColors.ink900,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color background;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: background,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 44,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// White rounded surface used for cards and grouped lists.
class DekadCard extends StatelessWidget {
  const DekadCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.color = DekadColors.surface,
    this.border,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color? border;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.all(color: border!, width: 1.5),
        boxShadow: elevated ? cardShadow : null,
      ),
      child: child,
    );
  }
}

/// Small uppercase label with an optional leading icon.
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color, this.icon});

  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DekadColors.ink400;
    final label = Text(
      text.toUpperCase(),
      style: DekadText.overline.copyWith(color: c),
    );
    if (icon == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 6),
        label,
      ],
    );
  }
}

String formatMetTime(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final hm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (now.difference(t).inMinutes.abs() < 2) return 'just now';
  if (day == today) return hm;
  if (today.difference(day).inDays == 1) return 'Yesterday';
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  if (today.difference(day).inDays < 7) return days[t.weekday - 1];
  return '${t.day}/${t.month}/${t.year}';
}

String methodLabel(String method) => method.toUpperCase();

/// Figma component "Contact Row".
class ContactTile extends StatelessWidget {
  const ContactTile({super.key, required this.connection, this.onTap});

  final Connection connection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (connection.location.isNotEmpty)
        connection.location.split(',').last.trim(),
      formatMetTime(connection.timestamp),
      methodLabel(connection.method),
    ].join(' · ');
    return Material(
      color: DekadColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              DekadAvatar(name: connection.displayName, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DekadText.bodyStrong,
                    ),
                    Text(
                      connection.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DekadText.caption.copyWith(
                        color: DekadColors.ink600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: DekadColors.ink400,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DekadText.caption,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: DekadColors.ink400),
            ],
          ),
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
