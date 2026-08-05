import 'dart:io';

/// Git operations used by the harness.
class GitOps {
  /// Returns the repository root directory.
  static Future<String> getRepoRoot() async {
    final result = await Process.run(
      'git',
      ['rev-parse', '--show-toplevel'],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw StateError(
        'Not a git repository (or git not found). '
        'stderr: ${result.stderr}',
      );
    }
    return (result.stdout as String).trim();
  }

  /// Returns the list of changed files compared to the merge base of the
  /// current branch with the target branch (default: phase-3 for stacked PRs).
  ///
  /// Falls back to `git diff HEAD~1 --name-only` if the merge-base resolution
  /// fails.
  static Future<List<String>> getChangedFiles({String? baseRef}) async {
    final effectiveBase = baseRef ?? 'refactor/modular-refactor-phase-3';

    // Try merge-base first
    var result = await Process.run(
      'git',
      ['merge-base', 'HEAD', effectiveBase],
      runInShell: true,
    );

    String compareRef;
    if (result.exitCode == 0) {
      compareRef = (result.stdout as String).trim();
    } else {
      // Fallback: diff against the branch directly
      compareRef = effectiveBase;
    }

    result = await Process.run(
      'git',
      ['diff', '--name-only', compareRef],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      // Last resort: diff against HEAD~1
      result = await Process.run(
        'git',
        ['diff', '--name-only', 'HEAD~1'],
        runInShell: true,
      );
    }

    final output = (result.stdout as String).trim();
    if (output.isEmpty) return [];

    return output.split('\n').where((f) => f.isNotEmpty).toList();
  }
}
