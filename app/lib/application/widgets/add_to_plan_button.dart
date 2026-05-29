import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_providers.dart';
import '../styles/colours.dart';
import '../styles/shapes.dart';

/// Extended FAB-style "Add to meal plan" / "Remove from meal plan" action.
/// Torn-corner radii + a blob-shaped leading icon — two of the Shape DNA
/// families on a single component for clear M3 Expressive intent.
class AddToPlanButton extends ConsumerWidget {
  final String uuid;
  final bool isInMealPlan;

  const AddToPlanButton({
    super.key,
    required this.uuid,
    required this.isInMealPlan,
  });

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(recipeListProvider.notifier);
    try {
      await notifier.toggleMealPlan(uuid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isInMealPlan ? 'Removed from meal plan' : 'Added to meal plan',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update meal plan'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colours;
    final bg = isInMealPlan ? c.surfaceContainerHigh : c.primary;
    final fg = isInMealPlan ? c.textPrimary : c.onPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      child: GestureDetector(
        onTap: () => _toggle(context, ref),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: Shapes.tornCornerSmall,
            boxShadow: isInMealPlan
                ? null
                : [
                    BoxShadow(
                      color: c.primary.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.2),
                  borderRadius: Shapes.blob(40),
                ),
                child: Icon(
                  isInMealPlan
                      ? Icons.event_busy_outlined
                      : Icons.calendar_today_rounded,
                  size: 20,
                  color: fg,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isInMealPlan ? 'Remove from meal plan' : 'Add to meal plan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 22, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
