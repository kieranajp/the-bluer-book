import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pantry_providers.dart';
import '../../providers/recipe_providers.dart';
import '../../styles/colours.dart';
import '../../styles/spacing.dart';
import '../../styles/text_styles.dart';
import '../../widgets/brand_loader.dart';
import '../../widgets/empty_state.dart';
import 'pantry_add_ingredient_field.dart';
import 'pantry_chip.dart';
import '../../utils/error_message.dart';

/// Your at-home inventory. Add the ingredients you have so the app can tell
/// you what you can cook (and, later, what's missing for your meal plan).
class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pantryAsync = ref.watch(pantryProvider);
    final allNames =
        ref.watch(ingredientsProvider).value?.map((e) => e.name).toList() ??
            const <String>[];

    ref.listen<AsyncValue<Set<String>>>(pantryProvider, (prev, next) {
      if (next.hasError && !(prev?.hasError ?? false)) {
        final message =
            errorMessage(next.error, fallback: 'Failed to load pantry');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: context.colours.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(pantryProvider.notifier).load(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                backgroundColor: context.colours.background,
                elevation: 0,
                title: Text('Pantry', style: TextStyles.appBarTitle(context)),
              ),
              SliverToBoxAdapter(
                child: PantryAddIngredientField(allNames: allNames),
              ),
              pantryAsync.when(
                data: (names) {
                  if (names.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.kitchen_outlined,
                        title: 'Your pantry is empty',
                        subtitle:
                            'Add what you have at home to see what you can cook',
                      ),
                    );
                  }
                  final sorted = names.toList()..sort();
                  return SliverPadding(
                    padding: const EdgeInsets.all(Spacing.m),
                    sliver: SliverToBoxAdapter(
                      child: Wrap(
                        spacing: Spacing.xs,
                        runSpacing: Spacing.xs,
                        children: [
                          for (final name in sorted) PantryChip(name: name),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: BrandLoader()),
                ),
                error: (error, stack) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.cloud_off,
                    title: "Couldn't load pantry",
                    action: OutlinedButton.icon(
                      onPressed: () => ref.read(pantryProvider.notifier).load(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: Spacing.bottomSpacer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
