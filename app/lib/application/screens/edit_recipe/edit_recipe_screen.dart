import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/recipe.dart';
import '../../providers/edit_recipe_provider.dart';
import '../../widgets/add_label_dialog.dart';
import '../../styles/colours.dart';
import '../../styles/text_styles.dart';
import '../../styles/spacing.dart';
import 'edit_recipe_basic_info_section.dart';
import 'edit_recipe_details_section.dart';
import 'edit_recipe_ingredients_section.dart';
import 'edit_recipe_labels_section.dart';
import 'edit_recipe_photo_section.dart';
import 'edit_recipe_steps_section.dart';

class EditRecipeScreen extends ConsumerStatefulWidget {
  final Recipe? recipe;

  const EditRecipeScreen({super.key, this.recipe});

  bool get isCreating => recipe == null;

  @override
  ConsumerState<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends ConsumerState<EditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();

  AutoDisposeStateNotifierProvider<EditRecipeNotifier, EditRecipeState>
      get _provider {
    final recipe = widget.recipe;
    return recipe == null ? newRecipeProvider : editRecipeProvider(recipe);
  }

  Future<void> _save() async {
    final notifier = ref.read(_provider.notifier);
    final error = notifier.validate();
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final successMessage =
        widget.isCreating ? 'Recipe created' : 'Recipe updated';

    try {
      final success = await notifier.save();
      if (success) {
        messenger.showSnackBar(SnackBar(content: Text(successMessage)));
        navigator.pop();
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to save recipe')),
      );
    }
  }

  Future<bool> _onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content:
            const Text('You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _addLabel() {
    showDialog(
      context: context,
      builder: (_) => AddLabelDialog(
        onAdd: (type, name) =>
            ref.read(_provider.notifier).addLabel(type: type, name: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editState = ref.watch(_provider);
    final notifier = ref.read(_provider.notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: context.colours.background,
        appBar: AppBar(
          backgroundColor: context.colours.background,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) Navigator.pop(context);
            },
          ),
          title: Text(
            widget.isCreating ? 'New Recipe' : 'Edit Recipe',
            style: TextStyles.appBarTitle(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: Spacing.s),
              child: editState.isSaving
                  ? const Padding(
                      padding: EdgeInsets.all(Spacing.m),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: Icon(Icons.check, color: context.colours.primary),
                      onPressed: _save,
                    ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: Spacing.all,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EditRecipePhotoSection(
                  editState: editState,
                  notifier: notifier,
                ),
                const SizedBox(height: Spacing.l),
                EditRecipeBasicInfoSection(
                  editState: editState,
                  notifier: notifier,
                ),
                const SizedBox(height: Spacing.l),
                EditRecipeDetailsSection(
                  editState: editState,
                  notifier: notifier,
                ),
                const SizedBox(height: Spacing.l),
                EditRecipeIngredientsSection(
                  editState: editState,
                  notifier: notifier,
                ),
                const SizedBox(height: Spacing.l),
                EditRecipeStepsSection(
                  editState: editState,
                  notifier: notifier,
                ),
                const SizedBox(height: Spacing.l),
                EditRecipeLabelsSection(
                  editState: editState,
                  notifier: notifier,
                  onAddLabel: _addLabel,
                ),
                const SizedBox(height: Spacing.bottomSpacer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
