import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/ingredient.dart';
import '../../domain/recipe.dart';
import '../providers/edit_recipe_provider.dart';
import '../providers/recipe_providers.dart';
import '../widgets/ingredient_edit_card.dart';
import '../widgets/step_edit_card.dart';
import '../widgets/label_edit_chip.dart';
import '../widgets/striped_placeholder.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

class EditRecipeScreen extends ConsumerStatefulWidget {
  final Recipe? recipe;

  const EditRecipeScreen({super.key, this.recipe});

  bool get isCreating => recipe == null;

  @override
  ConsumerState<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends ConsumerState<EditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();

  AutoDisposeStateNotifierProvider<EditRecipeNotifier, EditRecipeState>
      get _provider {
    final recipe = widget.recipe;
    return recipe == null ? newRecipeProvider : editRecipeProvider(recipe);
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
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
    _labelController.clear();
    String selectedType = 'course';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Label'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'course', child: Text('course')),
                    DropdownMenuItem(value: 'cuisine', child: Text('cuisine')),
                    DropdownMenuItem(value: 'diet', child: Text('diet')),
                    DropdownMenuItem(value: 'method', child: Text('method')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedType = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    hintText: 'Name (e.g. main, indian, gluten_free)',
                  ),
                  autofocus: true,
                  onSubmitted: (value) {
                    ref.read(_provider.notifier).addLabel(
                          type: selectedType,
                          name: value,
                        );
                    Navigator.pop(dialogContext);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(_provider.notifier).addLabel(
                        type: selectedType,
                        name: _labelController.text,
                      );
                  Navigator.pop(dialogContext);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
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
                _PhotoSection(
                  editState: editState,
                  notifier: notifier,
                ),
                const SizedBox(height: Spacing.l),
                _BasicInfoSection(
                  editState: editState,
                  notifier: notifier,
                ),
                const SizedBox(height: Spacing.l),
                _DetailsSection(
                  editState: editState,
                  notifier: notifier,
                ),
                const SizedBox(height: Spacing.l),
                _IngredientsSection(
                  editState: editState,
                  notifier: notifier,
                ),
                const SizedBox(height: Spacing.l),
                _StepsSection(
                  editState: editState,
                  notifier: notifier,
                ),
                const SizedBox(height: Spacing.l),
                _LabelsSection(
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

// --- Section widgets (presentational only) ---

class _PhotoSection extends StatelessWidget {
  final EditRecipeState editState;
  final EditRecipeNotifier notifier;

  const _PhotoSection({required this.editState, required this.notifier});

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    notifier.setPhoto(bytes, picked.name);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = editState.pendingPhotoBytes != null || (editState.imageUrl != null && editState.imageUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo', style: TextStyles.sectionHeading(context)),
        const SizedBox(height: Spacing.s),
        GestureDetector(
          onTap: _pickImage,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (editState.pendingPhotoBytes != null)
                    Image.memory(
                      editState.pendingPhotoBytes!,
                      fit: BoxFit.cover,
                    )
                  else if (editState.imageUrl != null && editState.imageUrl!.isNotEmpty)
                    Image.network(
                      editState.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const StripedPlaceholder(
                        icon: Icons.broken_image_outlined,
                      ),
                    )
                  else
                    StripedPlaceholder(
                      icon: Icons.add_a_photo_outlined,
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: Spacing.xs,
                        horizontal: Spacing.s,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasImage ? Icons.edit : Icons.add_a_photo_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasImage ? 'Change photo' : 'Add photo',
                            style: TextStyles.caption(context)
                                .copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (hasImage)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: notifier.removePhoto,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BasicInfoSection extends StatelessWidget {
  final EditRecipeState editState;
  final EditRecipeNotifier notifier;

  const _BasicInfoSection({required this.editState, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Basic Info', style: TextStyles.sectionHeading(context)),
        const SizedBox(height: Spacing.s),
        _FormTextField(
          label: 'Recipe Name',
          value: editState.name,
          onChanged: notifier.updateName,
        ),
        const SizedBox(height: Spacing.s),
        _FormTextField(
          label: 'Description',
          value: editState.description,
          onChanged: notifier.updateDescription,
          maxLines: 3,
        ),
      ],
    );
  }
}

class _DetailsSection extends StatelessWidget {
  final EditRecipeState editState;
  final EditRecipeNotifier notifier;

  const _DetailsSection({required this.editState, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Details', style: TextStyles.sectionHeading(context)),
        const SizedBox(height: Spacing.s),
        Row(
          children: [
            Expanded(
              child: _FormTextField(
                label: 'Prep (min)',
                value: editState.preparationTime.toString(),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) =>
                    notifier.updatePrepTime(int.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: _FormTextField(
                label: 'Cook (min)',
                value: editState.cookingTime.toString(),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) =>
                    notifier.updateCookTime(int.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: _FormTextField(
                label: 'Servings',
                value: editState.servings.toString(),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) =>
                    notifier.updateServings(int.tryParse(v) ?? 1),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IngredientsSection extends ConsumerWidget {
  final EditRecipeState editState;
  final EditRecipeNotifier notifier;

  const _IngredientsSection(
      {required this.editState, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableUnits =
        ref.watch(unitsProvider).valueOrNull ?? <IngredientUnit>[];
    final availableIngredients =
        ref.watch(ingredientsProvider).valueOrNull ?? <IngredientDetail>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Ingredients', style: TextStyles.sectionHeading(context)),
            const Spacer(),
            IconButton(
              onPressed: notifier.addIngredient,
              icon: Icon(Icons.add_circle_outline,
                  color: context.colours.primary),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: editState.ingredients.length,
          onReorderItem: notifier.reorderIngredients,
          buildDefaultDragHandles: false,
          proxyDecorator: (child, index, animation) => Material(
            color: Colors.transparent,
            child: child,
          ),
          itemBuilder: (context, i) {
            return IngredientEditCard(
              key: ValueKey(editState.ingredients[i].id),
              index: i,
              ingredient: editState.ingredients[i],
              availableUnits: availableUnits,
              availableIngredients: availableIngredients,
              onChanged: (updated) => notifier.updateIngredient(i, updated),
              onDelete: () => notifier.removeIngredient(i),
            );
          },
        ),
      ],
    );
  }
}

class _StepsSection extends StatelessWidget {
  final EditRecipeState editState;
  final EditRecipeNotifier notifier;

  const _StepsSection({required this.editState, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Steps', style: TextStyles.sectionHeading(context)),
            const Spacer(),
            IconButton(
              onPressed: notifier.addStep,
              icon: Icon(Icons.add_circle_outline,
                  color: context.colours.primary),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: editState.steps.length,
          onReorderItem: notifier.reorderSteps,
          buildDefaultDragHandles: false,
          proxyDecorator: (child, index, animation) => Material(
            color: Colors.transparent,
            child: child,
          ),
          itemBuilder: (context, i) {
            return StepEditCard(
              key: ValueKey(editState.steps[i].id),
              index: i,
              step: editState.steps[i],
              onChanged: (updated) => notifier.updateStep(i, updated),
              onDelete: () => notifier.removeStep(i),
            );
          },
        ),
      ],
    );
  }
}

class _LabelsSection extends StatelessWidget {
  final EditRecipeState editState;
  final EditRecipeNotifier notifier;
  final VoidCallback onAddLabel;

  const _LabelsSection({
    required this.editState,
    required this.notifier,
    required this.onAddLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Labels', style: TextStyles.sectionHeading(context)),
            const Spacer(),
            IconButton(
              onPressed: onAddLabel,
              icon: Icon(Icons.add_circle_outline,
                  color: context.colours.primary),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        Wrap(
          children: List.generate(editState.labels.length, (i) {
            return LabelEditChip(
              label: editState.labels[i],
              onDelete: () => notifier.removeLabel(i),
            );
          }),
        ),
      ],
    );
  }
}

// --- Shared styled text field ---

class _FormTextField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int? maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _FormTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyles.caption(context),
        filled: true,
        fillColor: context.colours.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Spacing.s, vertical: Spacing.xs),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colours.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colours.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colours.primary),
        ),
      ),
      style: TextStyles.body(context),
      maxLines: maxLines ?? 1,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
    );
  }
}
