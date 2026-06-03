import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../domain/recipe.dart';
import '../../../domain/step.dart' as domain;
import '../../../infrastructure/analytics/analytics.dart';
import '../../providers/analytics_providers.dart';
import '../../providers/recipe_providers.dart';
import '../../styles/colours.dart';
import '../../utils/ingredient_highlighter.dart';
import '../../utils/wave_gesture_detector.dart';
import 'cooking_bottom_controls.dart';
import 'cooking_empty_state.dart';
import 'cooking_gesture_status_bar.dart';
import 'cooking_progress_header.dart';
import 'cooking_step_page.dart';
import 'cooking_top_bar.dart';

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
    ref.read(analyticsProvider).capture(
      AnalyticsEvent.cookingModeStarted,
      properties: {
        'recipe_uuid': widget.recipe.uuid,
        'step_count': widget.recipe.steps.length,
      },
    );
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
            ? CookingEmptyState(recipeName: recipe.name)
            : Column(
                children: [
                  CookingTopBar(
                    title: recipe.name,
                    gesturesEnabled: _gesturesEnabled,
                    onToggleGestures: () => _toggleGestures(steps.length),
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  CookingProgressHeader(current: _index, total: steps.length),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: steps.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => CookingStepPage(
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
                    CookingGestureStatusBar(
                      controller: _wave?.cameraController,
                      inverted: _invertGestures,
                      onSwap: _toggleInvert,
                    ),
                  CookingBottomControls(
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
