import 'package:flutter/material.dart';

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
        return FilledButton(onPressed: _interactive ? _handlePressed : null,
            child: _child());
      case AsyncActionButtonStyle.elevated:
        return ElevatedButton(
            onPressed: _interactive ? _handlePressed : null, child: _child());
      case AsyncActionButtonStyle.text:
        return TextButton(
            onPressed: _interactive ? _handlePressed : null, child: _child());
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
          subtitle: widget.subtitle != null
              ? Text(widget.subtitle!)
              : null,
          onTap: _interactive ? _handlePressed : null,
        );
    }
  }
}
