import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../styles/colours.dart';

/// Tappable "source" row shown when a recipe was imported from a web page.
/// Opens the original URL in the device browser.
class RecipeSourceLink extends StatelessWidget {
  final String url;

  const RecipeSourceLink({super.key, required this.url});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final host = Uri.tryParse(url)?.host;
    final label = (host != null && host.isNotEmpty) ? host : 'View source';

    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_rounded, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: c.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: c.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
