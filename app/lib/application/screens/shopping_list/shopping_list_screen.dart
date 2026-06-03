import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pantry_providers.dart';
import '../../styles/colours.dart';
import '../../styles/spacing.dart';
import '../../styles/text_styles.dart';
import '../../widgets/brand_loader.dart';
import '../../widgets/empty_state.dart';
import 'shopping_list_row.dart';

/// What you still need to buy for your meal plan — every ingredient your
/// planned recipes call for that isn't already in the pantry. Checking an item
/// off adds it to the pantry, so it drops off the list.
class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(shoppingListProvider);

    ref.listen<AsyncValue<List<String>>>(shoppingListProvider, (prev, next) {
      if (next.hasError && !(prev?.hasError ?? false)) {
        final error = next.error;
        final message = error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Failed to load shopping list';
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
          onRefresh: () => ref.read(shoppingListProvider.notifier).load(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                backgroundColor: context.colours.background,
                elevation: 0,
                title: Text('Shopping list',
                    style: TextStyles.appBarTitle(context)),
              ),
              listAsync.when(
                data: (items) => items.isEmpty
                    ? const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.shopping_cart_outlined,
                          title: 'Nothing to buy',
                          subtitle: 'Your pantry already covers your meal plan',
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => ShoppingListRow(ingredient: items[i]),
                          childCount: items.length,
                        ),
                      ),
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: BrandLoader()),
                ),
                error: (error, stack) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.cloud_off,
                    title: "Couldn't load shopping list",
                    action: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(shoppingListProvider.notifier).load(),
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
