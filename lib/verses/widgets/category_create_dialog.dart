import 'package:flutter/material.dart';
import 'package:vers_reminder/shared/shared.dart';

class CategoryCreateDialog extends StatefulWidget {
  const CategoryCreateDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const CategoryCreateDialog(),
    );
  }

  @override
  State<CategoryCreateDialog> createState() => _CategoryCreateDialogState();
}

class _CategoryCreateDialogState extends State<CategoryCreateDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.categoryCreateTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: l10n.categoryNameLabel,
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.nameRequired;
            }
            return null;
          },
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: Text(l10n.create),
        ),
      ],
    );
  }
}
