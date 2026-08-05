import 'module_graph.dart';

/// Computes impacted test directories from a git diff using the module
/// dependency graph.
class ImpactCalculator {
  final ModuleGraph graph;

  ImpactCalculator(this.graph);

  /// Given a list of changed file paths (e.g., from `git diff`), returns the
  /// minimal set of test directories covering all affected modules and their
  /// transitive dependents.
  ///
  /// Files outside known module paths are silently ignored.
  /// Duplicate test directories are deduplicated (Set).
  Set<String> calculateImpact(List<String> changedFiles) {
    final affectedModules = <String>{};

    for (final file in changedFiles) {
      final module = graph.moduleForFile(file);
      if (module != null) {
        affectedModules.add(module.name);
      }
    }

    // Expand to transitive dependents
    final allAffected = <String>{};
    for (final moduleName in affectedModules) {
      allAffected.addAll(graph.transitiveDependents(moduleName));
    }

    // Map module names to test directories
    final testDirs = <String>{};
    for (final moduleName in allAffected) {
      final node = graph.nodes[moduleName];
      if (node != null) {
        testDirs.add(node.testDir);
      }
    }

    return testDirs;
  }
}
