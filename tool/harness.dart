/// vers_reminder project harness — impact-aware test runner.
///
/// Usage:
///   dart run tool/harness.dart test --impact      # Run affected tests only
///   dart run tool/harness.dart test --all          # Run full test suite
///   dart run tool/harness.dart test --integration  # Run integration tests
///   dart run tool/harness.dart validate            # Check module graph
library harness;

import 'dart:io';

import 'package:yaml/yaml.dart';

import 'harness/cli.dart';
import 'harness/decoupling_check.dart';
import 'harness/tdd_check.dart';
import 'harness/git.dart';
import 'harness/impact_calculator.dart';
import 'harness/integration_runner.dart';
import 'harness/module_graph.dart';
import 'harness/runner.dart';

void main(List<String> args) async {
  final cli = HarnessCli(args);

  if (!cli.isValid) {
    stderr.writeln(cli.usage);
    exit(cli.subcommand == null ? 0 : 1);
  }

  try {
    switch (cli.subcommand) {
      case 'validate':
        await _handleValidate();
      case 'check-decoupling':
        await _handleCheckDecoupling();
      case 'check-tdd':
        await _handleCheckTdd();
      case 'test':
        await _handleTest(cli);
      default:
        stderr.writeln('Unknown command: ${cli.subcommand}');
        stderr.writeln(cli.usage);
        exit(1);
    }
  } catch (e, stack) {
    stderr.writeln('Error: $e');
    stderr.writeln(stack);
    exit(2);
  }
}

Future<void> _handleValidate() async {
  final yamlPath = 'tool/modules.yaml';
  final yamlFile = File(yamlPath);

  if (!yamlFile.existsSync()) {
    stderr.writeln('modules.yaml not found at $yamlPath');
    exit(1);
  }

  final yamlContent = yamlFile.readAsStringSync();
  final graph = ModuleGraph.fromYaml(yamlContent);

  final issues = graph.validate();
  if (issues.isEmpty) {
    stdout.writeln('✅ modules.yaml is valid — ${graph.nodes.length} modules, no issues.');
    exit(0);
  } else {
    stderr.writeln('❌ modules.yaml has ${issues.length} issue(s):');
    for (final issue in issues) {
      stderr.writeln('  • $issue');
    }
    exit(1);
  }
}

Future<void> _handleTest(HarnessCli cli) async {
  var exitCode = 0;

  // ── Integration tests ─────────────────────────────────────────
  if (cli.integrationFlag) {
    stdout.writeln('Running integration tests...');
    final runner = IntegrationRunner();
    final result = await runner.run();
    stdout.write(result.output);
    if (!result.isSuccess) {
      stderr.writeln('Integration tests FAILED.');
      exitCode = 1;
    }
  }

  // ── Impact-based tests ────────────────────────────────────────
  if (cli.impactFlag) {
    final changedFiles = await GitOps.getChangedFiles();
    if (changedFiles.isEmpty) {
      stdout.writeln('No changed files detected — nothing to test.');
      exit(exitCode);
    }

    stdout.writeln('Changed files:');
    for (final f in changedFiles) {
      stdout.writeln('  $f');
    }

    final yamlContent = File('tool/modules.yaml').readAsStringSync();
    final graph = ModuleGraph.fromYaml(yamlContent);
    final calculator = ImpactCalculator(graph);
    final testDirs = calculator.calculateImpact(changedFiles);

    if (testDirs.isEmpty) {
      stdout.writeln('No impacted test directories — nothing to run.');
      exit(exitCode);
    }

    stdout.writeln('Impacted test directories: ${testDirs.join(', ')}');

    final runner = TestRunner();
    final result = await runner.run(testDirs);
    stdout.write(result.output);
    stdout.writeln(
      '${result.passed} passed, ${result.failed} failed, '
      '${result.total} total.',
    );
    if (!result.isSuccess) {
      exitCode = 1;
    }
  }

  // ── Full suite ────────────────────────────────────────────────
  if (cli.allFlag) {
    stdout.writeln('Running full test suite...');
    final runner = TestRunner();
    final result = await runner.run({'test/'});
    stdout.write(result.output);
    stdout.writeln(
      '${result.passed} passed, ${result.failed} failed, '
      '${result.total} total.',
    );
    if (!result.isSuccess) {
      exitCode = 1;
    }
  }

  exit(exitCode);
}

Future<void> _handleCheckDecoupling() async {
  final yamlPath = 'tool/modules.yaml';
  final yamlFile = File(yamlPath);

  if (!yamlFile.existsSync()) {
    stderr.writeln('modules.yaml not found at $yamlPath');
    exit(1);
  }

  final yamlContent = yamlFile.readAsStringSync();
  final doc = loadYaml(yamlContent) as YamlMap;
  final graph = ModuleGraph.fromYaml(yamlContent);

  final eventsSection = doc['events'];
  final events = (eventsSection is YamlMap) ? eventsSection : YamlMap();

  final check = DecouplingCheck(graph: graph, eventsSection: events);
  final violations = check.run();

  if (violations.isEmpty) {
    stdout.writeln('✅ No decoupling violations found — all imports comply with modules.yaml.');
    exit(0);
  } else {
    stderr.writeln('❌ ${violations.length} decoupling violation(s) detected:');
    for (final v in violations) {
      stderr.writeln('  • $v');
    }
    exit(violations.length);
  }
}

Future<void> _handleCheckTdd() async {
  final check = TddCheck();
  final violations = check.run();

  if (violations.isEmpty) {
    stdout.writeln('✅ TDD compliance — all code changes have test coverage.');
    exit(0);
  }

  final hasErrors = violations.any((v) => v.startsWith('TDD ERROR'));
  final label = hasErrors ? 'ERROR(s) and warning(s)' : 'warning(s)';
  stderr.writeln('❌ TDD ${violations.length} $label:');
  for (final v in violations) {
    stderr.writeln('  • $v');
  }
  exit(violations.length);
}
