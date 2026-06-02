import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pantry_providers.dart';
import '../providers/recipe_providers.dart';
import '../widgets/brand_mark.dart';
import '../widgets/empty_state.dart';
import '../styles/colours.dart';
import '../styles/spacing.dart';
import '../styles/text_styles.dart';

/// Your at-home inventory. Add the ingredients you have so the app can tell
/// you what you can cook (and, later, what's missing for your meal plan).
class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pantryAsync = ref.watch(pantryProvider);
    final allNames =
        ref.watch(ingredientsProvider).valueOrNull?.map((e) => e.name).toList() ??
            const <String>[];

    ref.listen<AsyncValue<Set<String>>>(pantryProvider, (prev, next) {
      if (next.hasError && !(prev?.hasError ?? false)) {
        final error = next.error;
        final message = error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Failed to load pantry';
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
              SliverToBoxAdapter(child: _AddIngredientField(allNames: allNames)),
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
                          for (final name in sorted) _PantryChip(name: name),
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

class _PantryChip extends ConsumerWidget {
  final String name;

  const _PantryChip({required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colours;
    return InputChip(
      label: Text(name),
      backgroundColor: c.surfaceContainer,
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
      onDeleted: () => ref.read(pantryProvider.notifier).remove(name),
    );
  }
}

class _AddIngredientField extends ConsumerWidget {
  final List<String> allNames;

  const _AddIngredientField({required this.allNames});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.m, 0, Spacing.m, Spacing.s),
      child: Autocomplete<String>(
        optionsBuilder: (value) {
          final query = value.text.trim().toLowerCase();
          if (query.isEmpty) return const Iterable<String>.empty();
          final pantry = ref.read(pantryProvider).valueOrNull ?? const <String>{};
          return allNames
              .where((n) =>
                  n.toLowerCase().contains(query) && !pantry.contains(n))
              .take(8);
        },
        onSelected: (selection) {
          ref.read(pantryProvider.notifier).add(selection);
        },
        fieldViewBuilder:
            (context, controller, focusNode, onFieldSubmitted) {
          final c = context.colours;
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: 'Add an ingredient you have…',
              prefixIcon: const Icon(Icons.add_rounded),
              filled: true,
              fillColor: c.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (value) {
              final query = value.trim().toLowerCase();
              final match = allNames.firstWhere(
                (n) => n.toLowerCase() == query,
                orElse: () => '',
              );
              if (match.isNotEmpty) {
                ref.read(pantryProvider.notifier).add(match);
                controller.clear();
              }
            },
          );
        },
      ),
    );
  }
}
