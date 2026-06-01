import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/label.dart';
import '../styles/colours.dart';
import '../styles/label_colours.dart';
import '../styles/shapes.dart';
import '../styles/text_styles.dart';

/// Title block for the recipe details screen — sits in a top-radius "sheet"
/// that overlaps the hero by 28px. Chips → serif italic title → description →
/// source link.
class RecipeHeader extends StatelessWidget {
  final String name;
  final String description;
  final List<Label> labels;
  final String? url;

  const RecipeHeader({
    super.key,
    required this.name,
    required this.description,
    required this.labels,
    this.url,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Transform.translate(
      offset: const Offset(0, -28),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: Shapes.sheetTop,
        ),
        padding: const EdgeInsets.fromLTRB(22, 36, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (labels.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: labels.take(3).map((l) => _LabelChip(label: l)).toList(),
              ),
            if (labels.isNotEmpty) const SizedBox(height: 16),
            Text(name, style: TextStyles.recipeTitle(context)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: c.textSecondary,
                ),
              ),
            ],
            if (url != null && url!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _SourceLink(url: url!.trim()),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tappable "source" row shown when a recipe was imported from a web page.
/// Opens the original URL in the device browser.
class _SourceLink extends StatelessWidget {
  final String url;

  const _SourceLink({required this.url});

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

class _LabelChip extends StatelessWidget {
  final Label label;

  const _LabelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final tone = labelToneFor(context, label.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        labelDisplayName(label.name).toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: tone.foreground,
        ),
      ),
    );
  }
}
