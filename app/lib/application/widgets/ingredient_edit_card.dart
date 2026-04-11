import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/edit_recipe_provider.dart';
import '../styles/colours.dart';
import '../styles/decorations.dart';
import '../styles/spacing.dart';
import '../styles/text_styles.dart';

class IngredientEditCard extends StatelessWidget {
  final int index;
  final EditableIngredient ingredient;
  final ValueChanged<EditableIngredient> onChanged;
  final VoidCallback onDelete;

  const IngredientEditCard({
    super.key,
    required this.index,
    required this.ingredient,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.s),
      padding: const EdgeInsets.all(Spacing.m),
      decoration: Decorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Ingredient ${index + 1}',
                  style: TextStyles.caption(context)),
              const Spacer(),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline,
                    color: context.colours.textSecondary, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: Spacing.s),
          _buildTextField(
            context,
            label: 'Name',
            value: ingredient.name,
            onChanged: (v) => onChanged(ingredient.clone()..name = v),
          ),
          const SizedBox(height: Spacing.s),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  context,
                  label: 'Qty',
                  value: _formatQuantity(ingredient.quantity),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  onChanged: (v) => onChanged(
                      ingredient.clone()..quantity = double.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(
                flex: 3,
                child: _buildTextField(
                  context,
                  label: 'Unit',
                  value: ingredient.unitName,
                  onChanged: (v) =>
                      onChanged(ingredient.clone()..unitName = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.s),
          _buildTextField(
            context,
            label: 'Preparation (optional)',
            value: ingredient.preparation,
            onChanged: (v) =>
                onChanged(ingredient.clone()..preparation = v),
          ),
          const SizedBox(height: Spacing.s),
          _buildTextField(
            context,
            label: 'Component (optional)',
            value: ingredient.component,
            onChanged: (v) => onChanged(ingredient.clone()..component = v),
          ),
        ],
      ),
    );
  }

  String _formatQuantity(double qty) {
    if (qty == qty.toInt()) return qty.toInt().toString();
    return qty.toString();
  }

  Widget _buildTextField(
    BuildContext context, {
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      initialValue: value,
      decoration: Decorations.textField(context, labelText: label),
      style: TextStyles.body(context),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
    );
  }
}
