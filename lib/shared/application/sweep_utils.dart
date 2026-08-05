import 'dart:io';

/// Deletes every file in [dir] for which [keep] returns `false`, returning the
/// number deleted.
///
/// Shared by the cleanup services so the sweep skeleton (skip non-files, keep
/// the referenced entries, defensive per-file delete) lives in one place and
/// only the keep-predicate differs between them.
///
/// The sweep is defensive: files that vanish between listing and deletion, or
/// that fail to delete for any other reason, are skipped without aborting the
/// rest of the sweep. A missing or inaccessible directory yields 0.
Future<int> sweepDirectory(
  Directory dir, {
  required bool Function(File file) keep,
}) async {
  if (!await dir.exists()) return 0;

  int deleted = 0;
  await for (final entry in dir.list()) {
    if (entry is! File) continue;
    if (keep(entry)) continue;

    try {
      await entry.delete();
      deleted++;
    } catch (_) {
      // Ignore missing/permission errors — defensive.
    }
  }
  return deleted;
}
