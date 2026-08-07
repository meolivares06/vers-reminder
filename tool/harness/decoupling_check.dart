import 'dart:io';

import 'package:yaml/yaml.dart';

import 'module_graph.dart';

/// Validates cross-module import compliance against modules.yaml.
///
/// Checks:
/// 1. **Missing dep** — source module's deps must contain target module,
///    unless an exception entry covers the import.
/// 2. **Barrel bypass** — cross-module imports must use the target
///    module's barrel path (not a direct internal file). Intra-module
///    imports are allowed.
/// 3. **Phantom events** — every event in the YAML events section must
///    have at least one emitter and at least one receiver.
class DecouplingCheck {
  final ModuleGraph graph;
  final YamlMap eventsSection;

  DecouplingCheck({required this.graph, required this.eventsSection});

  /// Regex matching package:vers_reminder/ imports.
  /// Captures the path relative to lib/ (e.g. "wallpaper/wallpaper.dart").
  static final _importRegex = RegExp(
    r"^\s*import\s+'package:vers_reminder/(.+\.dart)';",
    multiLine: true,
  );

  /// Runs all checks across every source file declared in the module graph.
  ///
  /// Returns a list of violation strings. An empty list means no violations.
  List<String> run() {
    final violations = <String>[];

    for (final node in graph.nodes.values) {
      for (final file in node.files) {
        final filePath = '${node.path}/$file';
        final sourceFile = File(filePath);

        if (!sourceFile.existsSync()) continue;

        final content = sourceFile.readAsStringSync();

        for (final match in _importRegex.allMatches(content)) {
          final importPath = match.group(1)!;
          violations.addAll(checkImport(filePath, importPath));
        }
      }
    }

    violations.addAll(checkPhantomEvents());
    return violations;
  }

  /// Checks a single import for missing-dependency and barrel-bypass
  /// violations.
  ///
  /// [sourceFilePath] is the file containing the import (e.g.
  /// `lib/wallpaper/application/wallpaper_state.dart`).
  /// [importPath] is the extracted path relative to lib/ (e.g.
  /// `shared/shared.dart`).
  ///
  /// Returns violations, or an empty list if the import is compliant.
  List<String> checkImport(String sourceFilePath, String importPath) {
    final violations = <String>[];

    final sourceModule = graph.moduleForFile(sourceFilePath);
    if (sourceModule == null) return violations;

    // Determine target module from the first path segment of the import.
    final targetName = importPath.split('/').first;
    final targetModule = graph.nodes[targetName];

    // Intra-module import — always allowed.
    if (targetName == sourceModule.name) return violations;

    // Target is not a known module — nothing to validate.
    if (targetModule == null) return violations;

    // Check if this import is covered by an exception.
    final isExcepted = sourceModule.exceptions.any(
      (e) => _matchesException(e, importPath, targetName),
    );
    if (isExcepted) return violations;

    // Check 1: Missing dependency.
    if (!sourceModule.deps.contains(targetName)) {
      violations.add(
        'Missing dependency: ${sourceModule.name} → $targetName '
        '(import: $importPath)',
      );
    }

    // Check 2: Barrel bypass.
    if (targetModule.barrel != null) {
      // Strip "lib/" prefix from the barrel to compare with lib/-relative path.
      final barrelPath = targetModule.barrel!.replaceFirst('lib/', '');
      if (importPath != barrelPath) {
        violations.add(
          'Barrel bypass: ${sourceModule.name} imports $importPath '
          'instead of barrel ${targetModule.barrel}',
        );
      }
    }

    return violations;
  }

  /// Checks the events section for phantom declarations that have no
  /// emitters or no receivers.
  ///
  /// Returns violation strings, or an empty list if every event is valid.
  List<String> checkPhantomEvents() {
    final violations = <String>[];

    for (final entry in eventsSection.entries) {
      final eventName = entry.key.toString();
      final eventValue = entry.value;

      if (eventValue is! YamlMap) continue;

      final emitters = eventValue['emitters'];
      final receivers = eventValue['receivers'];

      if (emitters is! YamlList || emitters.isEmpty) {
        violations.add('Phantom event: "$eventName" has no emitters.');
      }
      if (receivers is! YamlList || receivers.isEmpty) {
        violations.add('Phantom event: "$eventName" has no receivers.');
      }
    }

    return violations;
  }

  /// Checks if an exception entry covers a specific import.
  ///
  /// Exception format: `"source → target/file.dart (reason)"`.
  /// This matches if the exception string contains [importPath].
  bool _matchesException(
    String exception,
    String importPath,
    String targetName,
  ) {
    return exception.contains(importPath);
  }
}
