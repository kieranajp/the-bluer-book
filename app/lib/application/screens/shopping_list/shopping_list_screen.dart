import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/shopping_list_item.dart';
import '../../providers/pantry_providers.dart';
import '../../styles/colours.dart';
import '../../styles/spacing.dart';
import '../../styles/text_styles.dart';
import '../../widgets/brand_loader.dart';
import '../../widgets/empty_state.dart';
import 'add_shopping_item_dialog.dart';
import 'shopping_list_row.dart';
import '../../utils/error_message.dart';

/// What you still need to buy: every meal-plan ingredient your planned recipes
/// call for that isn't already in the pantry, plus any extras you add by hand
/// or snap a photo of. Checking a meal-plan item off adds it to the pantry;
/// checking a custom item off just removes it.
class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  bool _scanning = false;

  Future<void> _addItem() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const AddShoppingItemDialog(),
    );
    if (name == null) return;
    try {
      await ref.read(shoppingListProvider.notifier).addCustom(name);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage(e, fallback: "Couldn't add that item")),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _scanFromPhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _scanning = true);
    try {
      final bytes = await picked.readAsBytes();
      final added =
          await ref.read(shoppingListProvider.notifier).scan(bytes, picked.name);
      messenger.showSnackBar(
        SnackBar(
          content: Text(added == 0
              ? "Couldn't find any items in that photo"
              : 'Added $added item${added == 1 ? '' : 's'} from your photo'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              errorMessage(e, fallback: "Couldn't read that shopping list")),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(shoppingListProvider);

    ref.listen<AsyncValue<List<ShoppingListItem>>>(shoppingListProvider,
        (prev, next) {
      if (next.hasError && !(prev?.hasError ?? false)) {
        final message =
            errorMessage(next.error, fallback: 'Failed to load shopping list');
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
                actions: [
                  IconButton(
                    icon: _scanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.document_scanner_outlined),
                    tooltip: 'Scan a shopping list',
                    onPressed: _scanning ? null : _scanFromPhoto,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add an item',
                    onPressed: _addItem,
                  ),
                ],
              ),
              listAsync.when(
                data: (items) => items.isEmpty
                    ? const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.shopping_cart_outlined,
                          title: 'Nothing to buy',
                          subtitle:
                              'Add an item or scan a list — or let your meal plan fill this in',
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => ShoppingListRow(item: items[i]),
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
