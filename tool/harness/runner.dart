import 'dart:io';

/// Result of a test run.
class TestResult {
  final int exitCode;
  final String output;
  final int total;
  final int passed;
  final int failed;

  const TestResult({
    required this.exitCode,
    required this.output,
    this.total = 0,
    this.passed = 0,
    this.failed = 0,
  });

  /// A test run is considered successful when exit code is 0 AND there
  /// are no recorded failures.
  bool get isSuccess => exitCode == 0 && failed == 0;

  /// Parses `flutter test` output to extract test counts.
  ///
  /// Example output line: `00:01 +5 ~1 -2: Some test failed`
  /// `+N` = passed, `~N` = skipped, `-N` = failed
  factory TestResult.fromProcessResult(ProcessResult result) {
    final output = (result.stdout as String) + (result.stderr as String);
    int total = 0, passed = 0, failed = 0;

    // Parse the last summary line
    final lines = output.split('\n');
    for (final line in lines.reversed) {
      if (line.contains('All tests passed')) {
        // Extract total from the overall counter
        final match = RegExp(r'\+(\d+)').firstMatch(line);
        if (match != null) {
          passed = int.parse(match.group(1)!);
          total = passed;
        }
        break;
      }
      // Parse final summary: "267 passed, 10 failed, 277 total."
      final summaryMatch =
          RegExp(r'(\d+)\s+passed,\s+(\d+)\s+failed,\s+(\d+)\s+total').firstMatch(line);
      if (summaryMatch != null) {
        passed = int.parse(summaryMatch.group(1)!);
        failed = int.parse(summaryMatch.group(2)!);
        total = int.parse(summaryMatch.group(3)!);
        break;
      }
      // Parse compact format: "+5 ~1 -2: Some test failed"
      final allMatch = RegExp(r'\+(\d+)\s*(?:~\d+\s*)?-(\d+)').firstMatch(line);
      if (allMatch != null) {
        passed = int.parse(allMatch.group(1)!);
        failed = int.parse(allMatch.group(2)!);
        total = passed + failed;
        break;
      }
      // Parse running counter like "00:01 +5 -2: ..."
      final counterMatch = RegExp(r'\+(\d+)\s*-(\d+)').firstMatch(line);
      if (counterMatch != null) {
        passed = int.parse(counterMatch.group(1)!);
        failed = int.parse(counterMatch.group(2)!);
        total = passed + failed;
        break;
      }
    }

    return TestResult(
      exitCode: result.exitCode,
      output: output,
      total: total,
      passed: passed,
      failed: failed,
    );
  }
}

/// Runs `flutter test` for selected test directories.
class TestRunner {
  /// Builds the shell command string for running tests in the given directories.
  static String buildCommand(Set<String> testDirs) {
    if (testDirs.isEmpty) {
      return '';
    }
    final dirs = testDirs.toList()..sort();
    return 'flutter test --no-pub ${dirs.join(' ')}';
  }

  /// Runs `flutter test` for the given test directories and returns the result.
  Future<TestResult> run(Set<String> testDirs) async {
    final command = buildCommand(testDirs);
    if (command.isEmpty) {
      return const TestResult(exitCode: 0, output: 'No tests selected.');
    }

    final parts = command.split(' ');
    final executable = parts.first;
    final args = parts.sublist(1);

    final result = await Process.run(executable, args, runInShell: true);

    return TestResult.fromProcessResult(result);
  }
}
