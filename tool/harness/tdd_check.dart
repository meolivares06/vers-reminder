import 'dart:io';

/// Validates that code changes in `lib/` are accompanied by test changes in
/// `test/`.
///
/// Checks:
/// 1. If any `lib/` file changed and no `test/` file changed → WARNING
/// 2. If the commit message starts with `fix:` and no `test/` → ERROR
///
/// Enforcement:
/// - ERROR violations block the commit (non-zero exit).
/// - WARNING violations are reported but do not block.
class TddCheck {
  /// Returns a list of violation strings. Empty list = clean.
  List<String> run() {
    final violations = <String>[];

    // Resolve the diff range. On CI (merge commits), compare against the
    // merge base. Locally, compare HEAD~1..HEAD for the latest commit.
    final baseRef = _resolveBaseRef();
    final changed = _changedFiles(baseRef);
    if (changed.isEmpty) return violations;

    final libChanged = changed.any((f) => f.startsWith('lib/'));
    final testChanged = changed.any((f) => f.startsWith('test/'));
    if (!libChanged) return violations;

    final commitMessage = _lastCommitMessage();

    if (!testChanged) {
      final isFix = commitMessage.startsWith('fix:') ||
          commitMessage.startsWith('fix(');
      if (isFix) {
        violations.add(
          'TDD ERROR: fix commit "$commitMessage" changes lib/ but has no '
          'test changes. Bug fixes must include a regression test.',
        );
      } else {
        violations.add(
          'TDD WARNING: code changes in lib/ with no corresponding test '
          'changes. Consider adding test coverage for "$commitMessage".',
        );
      }
    }

    return violations;
  }

  /// Returns the git ref to diff against.
  String _resolveBaseRef() {
    // Check if there's a merge base (CI/PR context).
    final mergeBase = _runGit(
      ['merge-base', 'HEAD', 'origin/main'],
    );
    if (mergeBase != null && mergeBase.isNotEmpty) {
      return mergeBase;
    }
    // Fallback: diff the latest commit only.
    return 'HEAD~1';
  }

  /// Returns the set of files changed between [baseRef] and HEAD.
  List<String> _changedFiles(String baseRef) {
    final output = _runGit(['diff', '--name-only', '$baseRef..HEAD']);
    if (output == null || output.isEmpty) return [];
    return output
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Returns the last commit's subject line.
  String _lastCommitMessage() {
    final output = _runGit(['log', '-1', '--format=%s']);
    return output?.trim() ?? '';
  }

  /// Runs a git command and returns its stdout, or null on failure.
  String? _runGit(List<String> args) {
    try {
      final result = Process.runSync('git', args);
      if (result.exitCode != 0) return null;
      return (result.stdout as String).trim();
    } catch (_) {
      return null;
    }
  }
}
