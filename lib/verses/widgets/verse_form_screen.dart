import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vers_reminder/shared/shared.dart';
import 'package:vers_reminder/verses/application/verse_provider.dart';
import 'package:vers_reminder/verses/widgets/category_create_dialog.dart';

class VerseFormScreen extends StatefulWidget {
  final Verse? verse;

  const VerseFormScreen({super.key, this.verse});

  @override
  State<VerseFormScreen> createState() => _VerseFormScreenState();
}

class _VerseFormScreenState extends State<VerseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _citationController = TextEditingController();
  final _textEsController = TextEditingController();
  final _textPtController = TextEditingController();

  final Set<int> _selectedCategoryIds = {};
  String? _errorMessage;

  bool get isEditing => widget.verse != null;

  @override
  void initState() {
    super.initState();
    if (widget.verse != null) {
      _citationController.text = widget.verse!.citation;
      _textEsController.text = widget.verse!.textEs;
      _textPtController.text = widget.verse!.textPt ?? '';
    }
  }

  @override
  void dispose() {
    _citationController.dispose();
    _textEsController.dispose();
    _textPtController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryIds.isEmpty) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.selectAtLeastOneCategory;
      });
      return;
    }

    final provider = context.read<VerseProvider>();
    final verse = Verse(
      id: widget.verse?.id,
      citation: _citationController.text.trim(),
      textEs: _textEsController.text.trim(),
      textPt: _textPtController.text.trim().isEmpty
          ? null
          : _textPtController.text.trim(),
      createdAt: widget.verse?.createdAt,
    );

    await provider.saveVerse(verse, _selectedCategoryIds.toList());
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addCategoryInline() async {
    final name = await CategoryCreateDialog.show(context);
    if (name != null && name.isNotEmpty) {
      final provider = context.read<VerseProvider>();
      await provider.addCategory(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.editVerse : l10n.newVerse),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _citationController,
                decoration: InputDecoration(
                  labelText: l10n.citation,
                  hintText: l10n.citationHint,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.citationRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _textEsController,
                decoration: InputDecoration(
                  labelText: l10n.textEs,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.textRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _textPtController,
                decoration: InputDecoration(
                  labelText: l10n.textPt,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Consumer<VerseProvider>(
                builder: (context, provider, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.categoriesLabel,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ...provider.categories.map(
                            (cat) => FilterChip(
                              label: Text(cat.name),
                              selected: cat.id != null &&
                                  _selectedCategoryIds.contains(cat.id),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategoryIds.add(cat.id!);
                                  } else {
                                    _selectedCategoryIds.remove(cat.id);
                                  }
                                  _errorMessage = null;
                                });
                              },
                            ),
                          ),
                          ActionChip(
                            label: Text(l10n.addCategory),
                            onPressed: _addCategoryInline,
                          ),
                        ],
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
