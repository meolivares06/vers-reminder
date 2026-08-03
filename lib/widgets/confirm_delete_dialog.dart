import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';

class ConfirmDeleteDialog extends StatelessWidget {
  final String citation;

  const ConfirmDeleteDialog({super.key, required this.citation});

  static Future<bool?> show(BuildContext context, String citation) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDeleteDialog(citation: citation),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.confirmDelete),
      content: Text(l10n.confirmDeleteCitation(citation)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            l10n.delete,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }
}
