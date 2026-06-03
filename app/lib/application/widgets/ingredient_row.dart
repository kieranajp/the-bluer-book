import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/ingredient.dart';
import '../styles/colours.dart';
import '../styles/shapes.dart';

/// A single tap-to-check ingredient row in [IngredientsList]. Checked means
/// "in my pantry": squircle checkbox, name (with preparation), and a monospace
/// quantity pill anchored right.
class IngredientRow extends StatelessWidget {
  final Ingredient ingredient;
  final bool checked;
  final VoidCallback onTap;

  const IngredientRow({
    super.key,
    required this.ingredient,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: checked ? c.secondary : Colors.transparent,
                borderRadius: Shapes.squircle(10),
                border: checked
                    ? null
                    : Border.all(color: c.outlineVariant, width: 2),
              ),
              child: checked
                  ? Icon(Icons.check_rounded, size: 16, color: c.onSecondary)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _name(ingredient),
                style: TextStyle(
                  fontSize: 14.5,
                  color: checked ? c.textSecondary : c.textPrimary,
                  decoration:
                      checked ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: c.outlineVariant,
                ),
              ),
            ),
            if (_qty(ingredient).isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: c.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _qty(ingredient),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _qty(Ingredient i) {
    final buf = StringBuffer();
    if (i.quantity > 0) {
      if (i.quantity == i.quantity.toInt()) {
        buf.write(i.quantity.toInt());
      } else {
        buf.write(i.quantity);
      }
    }
    final unit = i.unit?.abbreviation?.isNotEmpty == true
        ? i.unit!.abbreviation!
        : (i.unit?.name.isNotEmpty == true ? i.unit!.name : null);
    if (unit != null) {
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(unit);
    }
    return buf.toString();
  }

  String _name(Ingredient i) {
    final name = i.detail.name;
    if (i.preparation != null && i.preparation!.isNotEmpty) {
      return '$name, ${i.preparation}';
    }
    return name;
  }
}
