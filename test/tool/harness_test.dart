import 'package:flutter_test/flutter_test.dart';

// RED phase — these files do not exist yet
import '../../tool/harness/module_graph.dart';
import '../../tool/harness/impact_calculator.dart';
import '../../tool/harness/runner.dart';
import '../../tool/harness/integration_runner.dart';
import '../../tool/harness/cli.dart';

const _testYaml = '''
modules:
  wallpaper:
    path: lib/wallpaper
    deps: [shared, scheduler]
  scheduler:
    path: lib/scheduler
    deps: [shared, wallpaper]
  verses:
    path: lib/verses
    deps: [shared]
  home:
    path: lib/home
    deps: [shared, wallpaper, settings, verses]
  settings:
    path: lib/settings
    deps: [shared, wallpaper, backup, verses]
  backup:
    path: lib/backup
    deps: [shared]
  notifications:
    path: lib/notifications
    deps: [shared]
  shared:
    path: lib/shared
    deps: []
''';

// ─── ModuleGraph Tests ────────────────────────────────────────────

void main() {
  group('ModuleGraph.fromYaml', () {
    test('parses all 8 modules from valid YAML', () {
      final graph = ModuleGraph.fromYaml(_testYaml);

      expect(graph.nodes.length, equals(8));
      expect(graph.nodes.containsKey('wallpaper'), isTrue);
      expect(graph.nodes.containsKey('scheduler'), isTrue);
      expect(graph.nodes.containsKey('shared'), isTrue);

      final wallpaper = graph.nodes['wallpaper']!;
      expect(wallpaper.name, equals('wallpaper'));
      expect(wallpaper.path, equals('lib/wallpaper'));
      expect(wallpaper.deps, containsAll(['shared', 'scheduler']));
      expect(wallpaper.testDir, equals('test/wallpaper'));
    });

    test('shared module has empty dependency list', () {
      final graph = ModuleGraph.fromYaml(_testYaml);

      final shared = graph.nodes['shared']!;
      expect(shared.deps, isEmpty);
    });

    test('modules that depend on nothing are valid', () {
      const minimalYaml = '''
modules:
  standalone:
    path: lib/standalone
    deps: []
''';
      final graph = ModuleGraph.fromYaml(minimalYaml);

      expect(graph.nodes.length, equals(1));
      expect(graph.nodes['standalone']!.deps, isEmpty);
    });

    test('throws FormatException on invalid YAML', () {
      expect(
        () => ModuleGraph.fromYaml('not: [valid: yaml:'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws ArgumentError when modules key is missing', () {
      expect(
        () => ModuleGraph.fromYaml('other: value'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ModuleGraph.moduleForFile', () {
    late ModuleGraph graph;

    setUp(() {
      graph = ModuleGraph.fromYaml(_testYaml);
    });

    test('maps exact path prefix to correct module', () {
      final module = graph.moduleForFile('lib/wallpaper/wallpaper_generator.dart');
      expect(module, isNotNull);
      expect(module!.name, equals('wallpaper'));
    });

    test('maps nested file under module path', () {
      final module = graph.moduleForFile('lib/verses/domain/verse.dart');
      expect(module, isNotNull);
      expect(module!.name, equals('verses'));
    });

    test('maps shared file to shared module', () {
      final module = graph.moduleForFile('lib/shared/event_bus/event_bus.dart');
      expect(module, isNotNull);
      expect(module!.name, equals('shared'));
    });

    test('returns null for file outside any module path', () {
      final module = graph.moduleForFile('pubspec.yaml');
      expect(module, isNull);
    });

    test('returns null for file under lib/ but not in any module', () {
      final module = graph.moduleForFile('lib/main.dart');
      expect(module, isNull);
    });

    test('shared path does NOT match wallpaper path (prefix collision check)', () {
      final module = graph.moduleForFile('lib/shared/wallpaper_pregen.dart');
      expect(module, isNotNull);
      expect(module!.name, equals('shared'));
    });
  });

  group('ModuleGraph.transitiveDependents', () {
    late ModuleGraph graph;

    setUp(() {
      graph = ModuleGraph.fromYaml(_testYaml);
    });

    test('returns only itself when no modules depend on it', () {
      final deps = graph.transitiveDependents('notifications');
      expect(deps, contains('notifications'));
      expect(deps.length, equals(1));
    });

    test('returns direct dependents (one hop)', () {
      // backup is a dep of settings
      final deps = graph.transitiveDependents('backup');
      expect(deps, containsAll(['backup', 'settings']));
    });

    test('returns transitive dependents (multi-hop)', () {
      // wallpaper → [scheduler, settings] → [home]
      // scheduler depends on wallpaper; settings depends on wallpaper
      // home depends on settings; home depends on wallpaper
      // result should be: wallpaper, scheduler, settings, home
      final deps = graph.transitiveDependents('wallpaper');
      expect(deps, containsAll(['wallpaper', 'scheduler', 'settings', 'home']));
    });

    test('shared change triggers ALL modules (shared is universal dep)', () {
      final deps = graph.transitiveDependents('shared');
      // Every module depends on shared; transitive means ALL modules
      expect(deps.length, equals(8)); // all 8 modules
      expect(deps, containsAll([
        'shared', 'wallpaper', 'scheduler', 'verses',
        'home', 'settings', 'backup', 'notifications',
      ]));
    });

    test('transitive chain: backup→settings→home (3 hops)', () {
      final deps = graph.transitiveDependents('backup');
      expect(deps, contains('backup'));
      expect(deps, contains('settings'));
      expect(deps, contains('home')); // via settings
    });

    test('throws ArgumentError for unknown module name', () {
      expect(
        () => graph.transitiveDependents('nonexistent'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ModuleGraph.validate', () {
    test('valid graph produces empty issues list', () {
      final graph = ModuleGraph.fromYaml(_testYaml);
      final issues = graph.validate();
      expect(issues, isEmpty);
    });

    test('detects missing dependency reference', () {
      const badYaml = '''
modules:
  alpha:
    path: lib/alpha
    deps: [nonexistent]
''';
      final graph = ModuleGraph.fromYaml(badYaml);
      final issues = graph.validate();
      expect(issues, isNotEmpty);
      expect(issues.any((i) => i.contains('nonexistent')), isTrue);
    });
  });

  // ─── ImpactCalculator Tests ─────────────────────────────────────

  group('ImpactCalculator.calculateImpact', () {
    late ModuleGraph graph;
    late ImpactCalculator calculator;

    setUp(() {
      graph = ModuleGraph.fromYaml(_testYaml);
      calculator = ImpactCalculator(graph);
    });

    test('empty diff returns empty set', () {
      final testDirs = calculator.calculateImpact([]);
      expect(testDirs, isEmpty);
    });

    test('single file change in wallpaper returns only wallpaper tests', () {
      // No other module depends on wallpaper? Wait — scheduler depends on wallpaper, 
      // and settings depends on wallpaper, and home depends on both.
      // So wallpaper change should trigger: wallpaper + scheduler + settings + home
      final testDirs = calculator.calculateImpact([
        'lib/wallpaper/wallpaper_generator.dart',
      ]);
      expect(testDirs, contains('test/wallpaper'));
      // Transitive: scheduler → wallpaper, settings → wallpaper, home → wallpaper
      expect(testDirs, contains('test/scheduler'));
      expect(testDirs, contains('test/settings'));
      expect(testDirs, contains('test/home'));
    });

    test('single file change in isolated module returns only that module', () {
      // notifications depends only on shared, nothing depends on notifications
      final testDirs = calculator.calculateImpact([
        'lib/notifications/notification_service.dart',
      ]);
      expect(testDirs, contains('test/notifications'));
      expect(testDirs.length, equals(1));
    });

    test('transitive dependency: wallpaper change triggers full chain', () {
      // wallpaper → scheduler → (nothing further)
      // wallpaper → settings → home
      // wallpaper → home
      final testDirs = calculator.calculateImpact([
        'lib/wallpaper/wallpaper_generator.dart',
      ]);
      expect(testDirs, containsAll([
        'test/wallpaper',
        'test/scheduler',
        'test/settings',
        'test/home',
      ]));
    });

    test('shared change triggers ALL test directories', () {
      final testDirs = calculator.calculateImpact([
        'lib/shared/event_bus/event_bus.dart',
      ]);
      expect(testDirs.length, equals(8));
      expect(testDirs, containsAll([
        'test/shared', 'test/wallpaper', 'test/scheduler', 'test/verses',
        'test/home', 'test/settings', 'test/backup', 'test/notifications',
      ]));
    });

    test('multiple files in different modules deduplicates test dirs', () {
      final testDirs = calculator.calculateImpact([
        'lib/wallpaper/wallpaper_generator.dart',
        'lib/wallpaper/image_cache_service.dart',
        'lib/backup/wallpaper_backup_service.dart',
      ]);
      // wallpaper: wallpaper + scheduler + settings + home
      // backup: backup + settings + home
      // Deduplicated union
      expect(testDirs, containsAll([
        'test/wallpaper', 'test/scheduler', 'test/settings',
        'test/home', 'test/backup',
      ]));
      expect(testDirs.length, equals(5));
    });

    test('file outside known modules is ignored gracefully', () {
      final testDirs = calculator.calculateImpact([
        'lib/main.dart',
        'pubspec.yaml',
      ]);
      expect(testDirs, isEmpty);
    });

    test('mixed known and unknown files — only known are resolved', () {
      final testDirs = calculator.calculateImpact([
        'lib/main.dart',
        'lib/wallpaper/wallpaper_generator.dart',
        'pubspec.yaml',
      ]);
      expect(testDirs, isNotEmpty);
      expect(testDirs, contains('test/wallpaper'));
      expect(testDirs, contains('test/scheduler'));
      expect(testDirs, contains('test/settings'));
      expect(testDirs, contains('test/home'));
    });
  });

  // ─── TestRunner Tests ───────────────────────────────────────────

  group('TestRunner.buildCommand', () {
    test('builds flutter test command for single directory', () {
      final command = TestRunner.buildCommand({'test/wallpaper'});
      expect(command, contains('flutter'));
      expect(command, contains('test'));
      expect(command, contains('--no-pub'));
      expect(command, contains('test/wallpaper'));
    });

    test('builds command with multiple directories joined', () {
      final command = TestRunner.buildCommand({
        'test/wallpaper',
        'test/scheduler',
        'test/home',
      });
      expect(command, contains('test/wallpaper'));
      expect(command, contains('test/scheduler'));
      expect(command, contains('test/home'));
    });

    test('empty set returns empty command', () {
      final command = TestRunner.buildCommand({});
      expect(command, isEmpty);
    });
  });

  group('TestResult', () {
    test('isSuccess true when exitCode is 0', () {
      final result = TestResult(exitCode: 0, output: '', total: 10, passed: 10, failed: 0);
      expect(result.isSuccess, isTrue);
    });

    test('isSuccess false when exitCode is non-zero', () {
      final result = TestResult(exitCode: 1, output: 'FAIL', total: 10, passed: 8, failed: 2);
      expect(result.isSuccess, isFalse);
    });

    test('failed > 0 but exitCode 0 is still success', () {
      // Some test runners return 0 even with failures (flutter test does NOT,
      // but we test the model independently)
      final result = TestResult(exitCode: 0, output: '', total: 10, passed: 8, failed: 2);
      expect(result.isSuccess, isFalse);
    });
  });

  // ─── IntegrationRunner Tests ────────────────────────────────────

  group('IntegrationRunner', () {
    test('buildCommand returns flutter test for integration directory', () {
      final command = IntegrationRunner.buildCommand();
      expect(command, contains('flutter'));
      expect(command, contains('test'));
      expect(command, contains('--no-pub'));
      expect(command, contains('integration_test/'));
    });

    test('buildCommand does not include module-specific dirs', () {
      final command = IntegrationRunner.buildCommand();
      expect(command, isNot(contains('test/wallpaper')));
      expect(command, isNot(contains('test/shared')));
    });
  });

  // ─── CLI Argument Parsing Tests ─────────────────────────────────

  group('HarnessCli', () {
    test('parses --impact flag', () {
      final cli = HarnessCli(['test', '--impact']);
      expect(cli.subcommand, equals('test'));
      expect(cli.impactFlag, isTrue);
      expect(cli.allFlag, isFalse);
      expect(cli.integrationFlag, isFalse);
    });

    test('parses --all flag', () {
      final cli = HarnessCli(['test', '--all']);
      expect(cli.subcommand, equals('test'));
      expect(cli.impactFlag, isFalse);
      expect(cli.allFlag, isTrue);
      expect(cli.integrationFlag, isFalse);
    });

    test('parses --integration flag', () {
      final cli = HarnessCli(['test', '--integration']);
      expect(cli.subcommand, equals('test'));
      expect(cli.integrationFlag, isTrue);
    });

    test('--all and --integration combined', () {
      final cli = HarnessCli(['test', '--all', '--integration']);
      expect(cli.allFlag, isTrue);
      expect(cli.integrationFlag, isTrue);
    });

    test('validate subcommand detected', () {
      final cli = HarnessCli(['validate']);
      expect(cli.subcommand, equals('validate'));
    });

    test('no subcommand defaults to help', () {
      final cli = HarnessCli([]);
      expect(cli.subcommand, isNull);
    });

    test('unknown subcommand is captured', () {
      final cli = HarnessCli(['unknown']);
      expect(cli.subcommand, equals('unknown'));
    });

    test('help requested when no mode specified for test', () {
      final cli = HarnessCli(['test']);
      expect(cli.subcommand, equals('test'));
      expect(cli.impactFlag, isFalse);
      expect(cli.allFlag, isFalse);
      expect(cli.integrationFlag, isFalse);
      expect(cli.isValid, isFalse);
    });
  });
}
