import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../domain/ingredient.dart';
import '../../domain/recipe.dart';
import '../../domain/step.dart' as domain;
import '../providers/recipe_providers.dart';
import '../styles/colours.dart';
import '../styles/shapes.dart';
import '../utils/ingredient_highlighter.dart';
import '../utils/wave_gesture_detector.dart';

/// Hands-busy cooking view: one step at a time at a comfortable across-the-
/// kitchen reading size, the ingredients needed for that step pulled out
/// beside it, the screen kept awake, and an optional touchless hand-wave to
/// advance when your fingers are covered in dough.
///
/// Steps advance by swiping the page horizontally (always available) or, when
/// the camera toggle is on, by waving a hand left→right (next) / right→left
/// (previous) in front of the front camera.
class CookingModeScreen extends ConsumerStatefulWidget {
  final Recipe recipe;

  const CookingModeScreen({super.key, required this.recipe});

  @override
  ConsumerState<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends ConsumerState<CookingModeScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  WaveGestureController? _wave;
  bool _gesturesEnabled = false;
  bool _invertGestures = false;

  @override
  void initState() {
    super.initState();
    // Keep the screen on while cooking — nobody wants the display sleeping
    // mid-step with wet hands.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _wave?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<domain.Step> _sortedSteps(Recipe recipe) {
    final steps = [...recipe.steps]..sort((a, b) => a.order.compareTo(b.order));
    return steps;
  }

  void _goTo(int target, int count) {
    final clamped = target.clamp(0, count - 1);
    if (clamped == _index) return;
    _pageController.animateToPage(
      clamped,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _onWave(WaveDirection direction, int count) {
    if (!mounted) return;
    // Hand sweeping left→right (rightward) advances; right→left goes back.
    if (direction == WaveDirection.right) {
      _goTo(_index + 1, count);
    } else {
      _goTo(_index - 1, count);
    }
  }

  Future<void> _toggleGestures(int count) async {
    if (_gesturesEnabled) {
      setState(() => _gesturesEnabled = false);
      await _wave?.stop();
      if (mounted) setState(() {});
      return;
    }

    setState(() => _gesturesEnabled = true);
    final wave = _wave ??= WaveGestureController(
      onWave: (d) => _onWave(d, count),
      invertDirection: _invertGestures,
      onError: _onCameraError,
    );
    await wave.start();
    if (mounted) setState(() {});
  }

  void _onCameraError(Object error) {
    if (!mounted) return;
    setState(() => _gesturesEnabled = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Couldn't start the camera for hand gestures"),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _toggleInvert() {
    setState(() {
      _invertGestures = !_invertGestures;
      _wave?.invertDirection = _invertGestures;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Track live recipe edits, mirroring the details screen.
    final recipeListAsync = ref.watch(recipeListProvider);
    final recipe = recipeListAsync.maybeWhen(
      data: (recipes) => recipes.firstWhere(
        (r) => r.uuid == widget.recipe.uuid,
        orElse: () => widget.recipe,
      ),
      orElse: () => widget.recipe,
    );
    final steps = _sortedSteps(recipe);
    final c = context.colours;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: steps.isEmpty
            ? _EmptyState(recipeName: recipe.name)
            : Column(
                children: [
                  _TopBar(
                    title: recipe.name,
                    gesturesEnabled: _gesturesEnabled,
                    onToggleGestures: () => _toggleGestures(steps.length),
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  _ProgressHeader(current: _index, total: steps.length),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: steps.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => _StepPage(
                        step: steps[i],
                        stepNumber: i + 1,
                        ingredients: ingredientsInStep(
                          steps[i].description,
                          recipe.ingredients,
                        ),
                      ),
                    ),
                  ),
                  if (_gesturesEnabled)
                    _GestureStatusBar(
                      controller: _wave?.cameraController,
                      inverted: _invertGestures,
                      onSwap: _toggleInvert,
                    ),
                  _BottomControls(
                    index: _index,
                    total: steps.length,
                    onPrev: () => _goTo(_index - 1, steps.length),
                    onNext: () => _goTo(_index + 1, steps.length),
                    onFinish: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Top bar: close, title, gesture toggle.
// ─────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String title;
  final bool gesturesEnabled;
  final VoidCallback onToggleGestures;
  final VoidCallback onClose;

  const _TopBar({
    required this.title,
    required this.gesturesEnabled,
    required this.onToggleGestures,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: c.textSecondary,
            tooltip: 'Exit cooking mode',
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onToggleGestures,
            isSelected: gesturesEnabled,
            icon: const Icon(Icons.front_hand_outlined),
            selectedIcon: const Icon(Icons.front_hand_rounded),
            color: c.textSecondary,
            style: IconButton.styleFrom(
              backgroundColor:
                  gesturesEnabled ? c.secondaryContainer : Colors.transparent,
              foregroundColor:
                  gesturesEnabled ? c.onSecondaryContainer : c.textSecondary,
            ),
            tooltip: gesturesEnabled
                ? 'Hand gestures on'
                : 'Turn on hand gestures',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Progress: "Step X of N" + a chunky bar.
// ─────────────────────────────────────────────────────────────────────────
class _ProgressHeader extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressHeader({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP ${current + 1} OF $total',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : (current + 1) / total,
              minHeight: 8,
              backgroundColor: c.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(c.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// A single step page: big number, big instruction text (with ingredient
// highlighting), and the ingredients used in this step.
// ─────────────────────────────────────────────────────────────────────────
class _StepPage extends StatelessWidget {
  final domain.Step step;
  final int stepNumber;
  final List<Ingredient> ingredients;

  const _StepPage({
    required this.step,
    required this.stepNumber,
    required this.ingredients,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: Shapes.squircle(18),
            ),
            child: Text(
              '$stepNumber',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: c.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _StepText(description: step.description, ingredients: ingredients),
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 32),
            _StepIngredients(ingredients: ingredients),
          ],
        ],
      ),
    );
  }
}

/// Large, distance-readable instruction text with ingredient names emphasised.
class _StepText extends StatelessWidget {
  final String description;
  final List<Ingredient> ingredients;

  const _StepText({required this.description, required this.ingredients});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final base = TextStyle(
      fontSize: 28,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: c.textPrimary,
    );

    final segments = highlightIngredients(description, ingredients);
    if (segments.every((s) => !s.isHighlighted)) {
      return Text(description, style: base);
    }

    final highlight = base.copyWith(
      color: c.primary,
      fontWeight: FontWeight.w800,
    );
    return Text.rich(
      TextSpan(
        children: [
          for (final s in segments)
            TextSpan(text: s.text, style: s.isHighlighted ? highlight : base),
        ],
      ),
    );
  }
}

/// "What you need now" — the ingredients mentioned in this step, big enough to
/// read from across the counter, each with its quantity.
class _StepIngredients extends StatelessWidget {
  final List<Ingredient> ingredients;

  const _StepIngredients({required this.ingredients});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT YOU NEED NOW',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < ingredients.length; i++) ...[
            if (i > 0)
              Divider(
                height: 20,
                thickness: 1,
                color: c.outlineVariant.withValues(alpha: 0.4),
              ),
            _StepIngredientRow(ingredient: ingredients[i]),
          ],
        ],
      ),
    );
  }
}

class _StepIngredientRow extends StatelessWidget {
  final Ingredient ingredient;

  const _StepIngredientRow({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final qty = formatIngredientQuantity(ingredient);
    final name = ingredient.preparation != null &&
            ingredient.preparation!.isNotEmpty
        ? '${ingredient.detail.name}, ${ingredient.preparation}'
        : ingredient.detail.name;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: c.textPrimary,
            ),
          ),
        ),
        if (qty.isNotEmpty) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              qty,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: c.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Live gesture status: tiny camera preview + a "swap direction" control so
// the mirrored/rotated front camera can be corrected per device.
// ─────────────────────────────────────────────────────────────────────────
class _GestureStatusBar extends StatelessWidget {
  final CameraController? controller;
  final bool inverted;
  final VoidCallback onSwap;

  const _GestureStatusBar({
    required this.controller,
    required this.inverted,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final ready = controller != null && controller!.value.isInitialized;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 44,
                child: ready
                    ? FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: controller!.value.previewSize?.height ?? 44,
                          height: controller!.value.previewSize?.width ?? 44,
                          child: CameraPreview(controller!),
                        ),
                      )
                    : Container(
                        color: c.surfaceContainerHighest,
                        child: Icon(
                          Icons.videocam_outlined,
                          size: 20,
                          color: c.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ready
                    ? 'Wave your hand left → right for next'
                    : 'Starting camera…',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.textSecondary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onSwap,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text(inverted ? 'Swapped' : 'Swap'),
              style: TextButton.styleFrom(foregroundColor: c.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Bottom Prev / Next (Finish on last step).
// ─────────────────────────────────────────────────────────────────────────
class _BottomControls extends StatelessWidget {
  final int index;
  final int total;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const _BottomControls({
    required this.index,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final isFirst = index == 0;
    final isLast = index == total - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
      child: Row(
        children: [
          Expanded(
            child: _PrevButton(enabled: !isFirst, onTap: onPrev),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: isLast ? onFinish : onNext,
              child: Container(
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: Shapes.tornCornerSmall,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLast ? 'Finish' : 'Next step',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLast
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      color: c.onPrimary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrevButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _PrevButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceContainerHigh,
            borderRadius: Shapes.tornCornerSmall,
          ),
          child: Icon(Icons.arrow_back_rounded, color: c.textPrimary, size: 22),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String recipeName;

  const _EmptyState({required this.recipeName});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: c.textSecondary,
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.soup_kitchen_outlined,
                    size: 48, color: c.textSecondary),
                const SizedBox(height: 16),
                Text(
                  'No steps to cook',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$recipeName has no method steps yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: c.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
