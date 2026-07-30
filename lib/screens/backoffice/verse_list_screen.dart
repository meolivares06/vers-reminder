import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/verse.dart';
import '../../providers/verse_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/verse_tile.dart';
import '../../widgets/confirm_delete_dialog.dart';
import 'verse_form_screen.dart';

class VerseListScreen extends StatefulWidget {
  const VerseListScreen({super.key});

  @override
  State<VerseListScreen> createState() => _VerseListScreenState();
}

class _VerseListScreenState extends State<VerseListScreen> {
  String _currentLocale = 'es';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();
    final locale = localeProvider.locale.languageCode;

    // Reload verses when locale changes (watch above triggers rebuild)
    if (_currentLocale != locale) {
      _currentLocale = locale;
      // Schedule after build to avoid calling async during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<VerseProvider>().loadVerses(locale);
      });
    }

    return Consumer<VerseProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.groupedVerses.isEmpty) {
          return Center(child: Text(l10n.noVerses));
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadVerses(locale),
          child: ListView(
            children: provider.groupedVerses.entries.map((entry) {
              return _CategoryGroup(
                categoryName: entry.key,
                verses: entry.value,
                onVerseTap: (verse) => _openForm(context, verse: verse),
                onVerseDelete: (verse) =>
                    _confirmDelete(context, provider, verse),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _openForm(BuildContext context, {Verse? verse}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerseFormScreen(verse: verse),
      ),
    );
    // Refresh verses when returning from form
    if (mounted) {
      context.read<VerseProvider>().loadVerses(_currentLocale);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, VerseProvider provider, Verse verse) async {
    final confirmed = await ConfirmDeleteDialog.show(context, verse.citation);
    if (confirmed == true) {
      await provider.removeVerse(verse.id!);
    }
  }
}

class _CategoryGroup extends StatelessWidget {
  final String categoryName;
  final List<Verse> verses;
  final Function(Verse) onVerseTap;
  final Function(Verse) onVerseDelete;

  const _CategoryGroup({
    required this.categoryName,
    required this.verses,
    required this.onVerseTap,
    required this.onVerseDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            categoryName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...verses.map(
          (verse) => VerseTile(
            verse: verse,
            onTap: () => onVerseTap(verse),
            onDelete: () => onVerseDelete(verse),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
