import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:vers_reminder/shared/shared.dart' hide Category;
import 'package:vers_reminder/scheduler/scheduler.dart';
import 'package:vers_reminder/verses/application/verse_provider.dart';
import 'package:vers_reminder/verses/widgets/category_create_dialog.dart';

/// Horizontal scrollable chip bar for category management.
///
/// Each chip toggles the category on/off in [SchedulerConfig.activeCategoryIds].
/// The last chip (✚) opens [CategoryCreateDialog] to add a new category.
/// When no chips are selected, all verses are shown (no filter).
class CategoryChipBar extends StatelessWidget {
  const CategoryChipBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheduler = context.watch<SchedulerConfig>();
    final verseProvider = context.watch<VerseProvider>();
    final categories = verseProvider.categories;
    final activeIds = scheduler.activeCategoryIds;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length + 1, // +1 for ✚
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index < categories.length) {
            final cat = categories[index];
            final isActive = activeIds.contains(cat.id);
            return FilterChip(
              label: Text(cat.name),
              selected: isActive,
              selectedColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              checkmarkColor: Theme.of(context).colorScheme.primary,
              onSelected: (_) => scheduler.toggleCategory(cat.id!),
            );
          }
          // ✚ chip — add new category
          return ActionChip(
            avatar: const Icon(Icons.add, size: 16),
            label: Text(l10n.addCategory),
            onPressed: () => _showCreateDialog(context),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const CategoryCreateDialog(),
    );
  }
}
