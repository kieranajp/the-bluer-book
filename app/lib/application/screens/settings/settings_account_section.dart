import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_providers.dart';
import '../../styles/colours.dart';
import '../../styles/spacing.dart';
import '../../styles/text_styles.dart';

/// "Account" block on the Settings screen: current home + sign-out +
/// link out to the Play-store-required account-deletion web URL.
///
/// We deliberately link out to the web URL rather than wiring an
/// in-app DELETE /api/account form here. Both backend endpoints exist
/// (Phase 6) but a web page satisfies the Play data-safety
/// requirement for a publicly-reachable URL, and asking the user to
/// confirm in a browser keeps the destructive action one extra
/// deliberate step away from a thumb-tap.
class SettingsAccountSection extends ConsumerWidget {
  static const _deleteAccountUrl = 'https://recipes.kieranajp.uk/account/delete';

  const SettingsAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final me = auth is AuthStateSignedIn ? auth.me : null;
    final activeHome = me?.activeHome;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Account', style: TextStyles.sectionHeading(context)),
        const SizedBox(height: Spacing.s),
        if (activeHome != null) ...[
          Container(
            padding: const EdgeInsets.all(Spacing.m),
            decoration: BoxDecoration(
              color: context.colours.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.home_outlined),
                const SizedBox(width: Spacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activeHome.name, style: TextStyles.body(context)),
                      Text(
                        'You\'re an ${activeHome.role.name} of this home.',
                        style: TextStyles.caption(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),
        ],
        OutlinedButton.icon(
          onPressed: () => ref.read(authProvider.notifier).signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: Spacing.s),
        OutlinedButton.icon(
          onPressed: () => _openDeleteAccount(context),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete account'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          'Opens a browser to confirm. Deletes any household where '
          'you are the sole owner, along with all its recipes, the '
          'meal plan, pantry and shopping list.',
          style: TextStyles.caption(context),
        ),
      ],
    );
  }

  Future<void> _openDeleteAccount(BuildContext context) async {
    final uri = Uri.parse(_deleteAccountUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the deletion page.')),
      );
    }
  }
}
