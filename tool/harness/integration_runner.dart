import 'dart:io';

import 'runner.dart';

/// Runs Flutter integration tests (those under `integration_test/`).
class IntegrationRunner {
  /// Builds the shell command for running integration tests.
  static String buildCommand() {
    return 'flutter test --no-pub integration_test/';
  }

  /// Executes the integration test suite.
  Future<TestResult> run() async {
    final command = buildCommand();
    final parts = command.split(' ');
    final executable = parts.first;
    final args = parts.sublist(1);

    final result = await Process.run(executable, args, runInShell: true);

    return TestResult.fromProcessResult(result);
  }
}
