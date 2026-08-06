/// Parses and validates CLI arguments for the harness.
class HarnessCli {
  final List<String> args;

  HarnessCli(this.args);

  /// The subcommand: "test", "validate", or null if none provided.
  String? get subcommand {
    if (args.isEmpty) return null;
    final first = args.first;
    if (first.startsWith('-')) return 'test'; // implicit test subcommand
    return first;
  }

  /// Whether `--impact` flag is present.
  bool get impactFlag => args.contains('--impact');

  /// Whether `--all` flag is present.
  bool get allFlag => args.contains('--all');

  /// Whether `--integration` flag is present.
  bool get integrationFlag => args.contains('--integration');

  /// Whether the parsed arguments represent a valid configuration.
  ///
  /// For "test" subcommand, at least one mode flag (--impact, --all, --integration)
  /// must be specified. "validate" and "check-decoupling" require no flags.
  bool get isValid {
    if (subcommand == 'validate') return true;
    if (subcommand == 'check-decoupling') return true;
    if (subcommand == 'check-tdd') return true;
    if (subcommand == 'test') {
      return impactFlag || allFlag || integrationFlag;
    }
    return false;
  }

  /// Returns a human-readable usage string.
  String get usage => ''
      'Usage: dart run tool/harness.dart <command> [flags]\n'
      '\n'
      'Commands:\n'
      '  test              Run tests (requires --impact, --all, or --integration)\n'
      '  validate          Check modules.yaml graph consistency\n'
      '  check-decoupling  Scan imports against modules.yaml, report violations\n'
      '  check-tdd         Validate that code changes have test coverage\n'
      '\n'
      'Flags for "test":\n'
      '  --impact        Run only tests affected by current git diff\n'
      '  --all           Run the full test suite\n'
      '  --integration   Run integration tests separately\n';
}
