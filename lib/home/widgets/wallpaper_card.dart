import 'dart:io';

import 'package:flutter/material.dart';

import 'package:vers_reminder/shared/shared.dart';

/// Dumb widget — renders the current wallpaper with countdown overlay and
/// optional refresh FAB. All state is passed in via constructor parameters.
class WallpaperCard extends StatefulWidget {
  final String? path;
  final DateTime? timestamp;
  final int? nextInMinutes;
  final VoidCallback? onTap;
  final VoidCallback? onFabPressed;
  final bool wallpaperPermissionGranted;
  final bool isGenerating;

  const WallpaperCard({
    super.key,
    this.path,
    this.timestamp,
    this.nextInMinutes,
    this.onTap,
    this.onFabPressed,
    this.wallpaperPermissionGranted = false,
    this.isGenerating = false,
  });

  @override
  State<WallpaperCard> createState() => _WallpaperCardState();
}

class _WallpaperCardState extends State<WallpaperCard> {
  bool _wallpaperFileExists = false;
  String? _lastCheckedPath;

  @override
  void initState() {
    super.initState();
    if (widget.path != null) {
      _wallpaperFileExists = true;
      _lastCheckedPath = widget.path;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFile());
  }

  @override
  void didUpdateWidget(covariant WallpaperCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != null && widget.path != _lastCheckedPath) {
      _lastCheckedPath = widget.path;
      _wallpaperFileExists = false;
      _checkFile();
    }
  }

  void _checkFile() {
    final path = widget.path;
    if (path != null) {
      File(path).exists().then((exists) {
        if (mounted && exists != _wallpaperFileExists) {
          setState(() => _wallpaperFileExists = exists);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasWallpaper =
        widget.path != null && _wallpaperFileExists;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: hasWallpaper
            ? Stack(
                fit: StackFit.expand,
                children: [
                  InkWell(
                    onTap: widget.onTap,
                    child: Image.file(
                      File(widget.path!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (widget.nextInMinutes != null)
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.nextInMinutes == 1
                              ? l10n.nextInLessThanOneMinute
                              : l10n.nextInApproximatelyMinutes(
                                  widget.nextInMinutes!,
                                ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  if (widget.onFabPressed != null)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        onPressed:
                            widget.isGenerating ? null : widget.onFabPressed,
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                        foregroundColor: onGoldAccent,
                        tooltip:
                            widget.isGenerating ? null : l10n.changeNow,
                        child: widget.isGenerating
                            ? SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: onGoldAccent,
                                ),
                              )
                            : const Icon(Icons.refresh),
                      ),
                    ),
                ],
              )
            : InkWell(
                onTap: widget.onTap,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wallpaper_outlined,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.noWallpaper,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
