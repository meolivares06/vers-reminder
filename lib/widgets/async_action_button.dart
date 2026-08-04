import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Minimum WCAG AA contrast ratio the filled foreground must clear on a custom
/// brand background.
const double _kMinContrast = 4.5;

/// Visual variant of an [AsyncActionButton].
enum AsyncActionButtonStyle { filled, elevated, text, tile }

/// A reusable inline blocking loader button.
///
/// Runs a `Future<void>` action supplied by the caller. While the future is
/// in flight the button/list-tile is disabled and shows an inline
/// [CircularProgressIndicator] in place of its label; when it settles the
/// button re-enables and the wrapped future's result/errors are forwarded to
/// the caller verbatim (the action is NOT caught or transformed here).
///
/// This widget is intentionally dumb: it does not coordinate with any update
/// state machine or wallpaper trigger. The caller owns the full action
/// (including snackbars / dialogs) inside [onPressed].
class AsyncActionButton extends StatefulWidget {
  const AsyncActionButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.style = AsyncActionButtonStyle.filled,
    this.enabled = true,
    this.subtitle,
    this.backgroundColor,
  });

  /// The full async action to run when tapped. Result/errors flow through
  /// unchanged to the caller.
  final Future<void> Function() onPressed;

  /// The button/tile label (replaced by a spinner while busy).
  final String label;

  /// Optional leading icon (not shown while busy, when the spinner replaces
  /// the label slot).
  final IconData? icon;

  /// Visual variant: filled / elevated / text button or a list tile.
  final AsyncActionButtonStyle style;

  /// Whether the control can be tapped. Disabled controls never start a run.
  final bool enabled;

  /// Optional second line below the label. Only rendered for the [title]
  /// ([AsyncActionButtonStyle.tile]) style; ignored for button styles. The
  /// spinner replaces only the tile title, leaving the subtitle intact.
  final String? subtitle;

  /// Optional [FilledButton] background override (only honored for the
  /// [AsyncActionButtonStyle.filled] style). Used for the gold brand accent on
  /// the active CTA without recoloring the rest of the palette. When set, the
  /// foreground is derived so it clears WCAG AA on that background (never the
  /// near-white `onPrimary` default, which fails on gold).
  final Color? backgroundColor;

  @override
  State<AsyncActionButton> createState() => _AsyncActionButtonState();
}

class _AsyncActionButtonState extends State<AsyncActionButton> {
  bool _busy = false;

  bool get _interactive => widget.enabled && !_busy;

  Future<void> _handlePressed() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The label slot: the inline spinner while busy, the label (and optional
  /// icon) otherwise.
  Widget _child() {
    if (_busy) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    final icon = widget.icon;
    final label = Text(widget.label);
    if (icon == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 8), label],
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.style) {
      case AsyncActionButtonStyle.filled:
        final bg = widget.backgroundColor;
        final fg = _filledForeground(Theme.of(context).colorScheme, bg);
        return FilledButton(
          onPressed: _interactive ? _handlePressed : null,
          style: fg != null
              ? FilledButton.styleFrom(backgroundColor: bg, foregroundColor: fg)
              : null,
          child: _child(),
        );
      case AsyncActionButtonStyle.elevated:
        return ElevatedButton(
          onPressed: _interactive ? _handlePressed : null,
          child: _child(),
        );
      case AsyncActionButtonStyle.text:
        return TextButton(
          onPressed: _interactive ? _handlePressed : null,
          child: _child(),
        );
      case AsyncActionButtonStyle.tile:
        return ListTile(
          leading: Icon(widget.icon),
          title: _busy
              // The spinner is small enough to sit inline; use the title slot
              // so the tile keeps its height consistent.
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : Text(widget.label),
          subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
          onTap: _interactive ? _handlePressed : null,
        );
    }
  }
}

/// Resolves the foreground for the [AsyncActionButtonStyle.filled] style when a
/// custom [AsyncActionButton.backgroundColor] is set.
///
/// The default `FilledButton` foreground is the scheme's `onPrimary` (near
/// white), which fails on the gold brand surface (~1.9:1). Prefers
/// [ColorScheme.onSecondary] when it already clears WCAG AA (dark mode);
/// otherwise falls back to [onGoldAccent] — a fixed dark tone that passes on
/// the gold surface in light mode too.
Color? _filledForeground(ColorScheme scheme, Color? bg) {
  if (bg == null) return null;
  final onSecondary = scheme.onSecondary;
  if (_contrastRatio(bg, onSecondary) >= _kMinContrast) return onSecondary;
  return onGoldAccent;
}

/// WCAG 2.x contrast ratio between two opaque colors (from their relative
/// luminance).
double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG relative luminance of an opaque color.
double _relativeLuminance(Color c) {
  double channel(double v) {
    final s = v / 255;
    return s <= 0.04045
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.r * 255) +
      0.7152 * channel(c.g * 255) +
      0.0722 * channel(c.b * 255);
}
