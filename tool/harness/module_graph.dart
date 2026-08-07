import 'dart:collection';

import 'package:yaml/yaml.dart';

/// Represents a single module in the dependency graph.
class ModuleNode {
  final String name;
  final String path;
  final List<String> deps;

  /// The module's public API surface — cross-module imports must use this path.
  final String? barrel;

  /// Source files belonging to this module, relative to [path].
  final List<String> files;

  /// Exception strings allowing specific cross-module imports to bypass
  /// dependency and barrel checks.
  final List<String> exceptions;

  const ModuleNode({
    required this.name,
    required this.path,
    required this.deps,
    this.barrel,
    this.files = const [],
    this.exceptions = const [],
  });

  /// Convention: test directory mirrors source path (lib/ → test/).
  String get testDir => path.replaceFirst('lib/', 'test/');
}

/// A directed dependency graph of modules parsed from modules.yaml.
class ModuleGraph {
  final Map<String, ModuleNode> nodes;

  ModuleGraph(this.nodes);

  /// Parses a YAML string conforming to the modules.yaml schema.
  ///
  /// Expected structure:
  /// ```yaml
  /// modules:
  ///   <name>:
  ///     path: lib/<name>
  ///     deps: [<dep1>, <dep2>]
  /// ```
  factory ModuleGraph.fromYaml(String yamlContent) {
    final doc = loadYaml(yamlContent);

    if (doc is! YamlMap || !doc.containsKey('modules')) {
      throw ArgumentError('YAML must contain a top-level "modules" key.');
    }

    final modulesYaml = doc['modules'];
    if (modulesYaml is! YamlMap) {
      throw ArgumentError('"modules" must be a YAML mapping.');
    }

    final nodes = <String, ModuleNode>{};
    for (final entry in modulesYaml.entries) {
      final name = entry.key.toString();
      final value = entry.value;

      if (value is! YamlMap) {
        throw FormatException(
          'Module "$name" must be a mapping.',
          value,
        );
      }

      final path = value['path']?.toString();
      if (path == null || path.isEmpty) {
        throw FormatException(
          'Module "$name" is missing required "path" field.',
          value,
        );
      }

      final barrel = value['barrel']?.toString();
      if (barrel != null && barrel.isEmpty) {
        throw FormatException(
          'Module "$name" has an empty "barrel" field.',
          value,
        );
      }

      final depsYaml = value['deps'];
      final deps = <String>[];
      if (depsYaml is YamlList) {
        for (final dep in depsYaml) {
          deps.add(dep.toString());
        }
      }

      final filesYaml = value['files'];
      final files = <String>[];
      if (filesYaml is YamlList) {
        for (final file in filesYaml) {
          files.add(file.toString());
        }
      }

      final exceptionsYaml = value['exceptions'];
      final exceptions = <String>[];
      if (exceptionsYaml is YamlList) {
        for (final exc in exceptionsYaml) {
          exceptions.add(exc.toString());
        }
      }

      nodes[name] = ModuleNode(
        name: name,
        path: path,
        deps: deps,
        barrel: barrel,
        files: files,
        exceptions: exceptions,
      );
    }

    return ModuleGraph(UnmodifiableMapView(nodes));
  }

  /// Returns the module that contains [filePath], or null if no module matches.
  ///
  /// Uses longest-prefix matching to avoid false matches (e.g., a file under
  /// `lib/shared/` must match the shared module, not a shorter prefix).
  ModuleNode? moduleForFile(String filePath) {
    ModuleNode? best;
    int bestLen = 0;

    for (final node in nodes.values) {
      final prefix = '${node.path}/';
      if (filePath.startsWith(prefix) && prefix.length > bestLen) {
        best = node;
        bestLen = prefix.length;
      }
    }

    return best;
  }

  /// Returns the set of module names that (transitively) depend on
  /// [moduleName], including [moduleName] itself.
  ///
  /// Traverses the reverse dependency graph using BFS to collect all modules
  /// that could be affected by a change in the given module.
  Set<String> transitiveDependents(String moduleName) {
    if (!nodes.containsKey(moduleName)) {
      throw ArgumentError('Unknown module: "$moduleName".');
    }

    // Build reverse dependency map: module → who depends on it
    final reverseDeps = <String, Set<String>>{};
    for (final node in nodes.values) {
      for (final dep in node.deps) {
        reverseDeps.putIfAbsent(dep, () => {}).add(node.name);
      }
    }

    final result = <String>{moduleName};
    final queue = Queue<String>.from([moduleName]);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final dependents = reverseDeps[current];
      if (dependents == null) continue;

      for (final dependent in dependents) {
        if (result.add(dependent)) {
          queue.add(dependent);
        }
      }
    }

    return result;
  }

  /// Validates the graph structure and returns a list of issues.
  /// An empty list means the graph is valid.
  List<String> validate() {
    final issues = <String>[];

    for (final node in nodes.values) {
      for (final dep in node.deps) {
        if (!nodes.containsKey(dep)) {
          issues.add(
            'Module "${node.name}" depends on unknown module "$dep".',
          );
        }
      }
    }

    return issues;
  }
}
