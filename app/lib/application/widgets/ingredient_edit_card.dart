import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/edit_recipe_provider.dart';
import '../styles/colours.dart';
import '../styles/decorations.dart';
import '../styles/spacing.dart';
import '../styles/text_styles.dart';

class IngredientEditCard extends StatefulWidget {
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
  State<IngredientEditCard> createState() => _IngredientEditCardState();
}

class _IngredientEditCardState extends State<IngredientEditCard> {
  bool _expanded = false;

  String _buildSummary() {
    final parts = <String>[];
    if (widget.ingredient.quantity > 0) {
      parts.add(_formatQuantity(widget.ingredient.quantity));
    }
    if (widget.ingredient.unitName.isNotEmpty) {
      parts.add(widget.ingredient.unitName);
    }
    parts.add(
      widget.ingredient.name.isNotEmpty ? widget.ingredient.name : 'New ingredient',
    );
    String summary = parts.join(' ');
    if (widget.ingredient.preparation.isNotEmpty) {
      summary += ', ${widget.ingredient.preparation}';
    }
    return summary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.s),
      decoration: Decorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.m, vertical: Spacing.s),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: widget.index,
                  child: Icon(Icons.drag_handle,
                      color: context.colours.textSecondary, size: 20),
                ),
                const SizedBox(width: Spacing.s),
                Expanded(
                  child: Text(
                    _buildSummary(),
                    style: TextStyles.body(context),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: context.colours.textSecondary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: Spacing.s),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: Icon(Icons.delete_outline,
                      color: context.colours.textSecondary, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.m, 0, Spacing.m, Spacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    context,
                    label: 'Name',
                    value: widget.ingredient.name,
                    onChanged: (v) =>
                        widget.onChanged(widget.ingredient.clone()..name = v),
                  ),
                  const SizedBox(height: Spacing.s),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          context,
                          label: 'Qty',
                          value: _formatQuantity(widget.ingredient.quantity),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                          ],
                          onChanged: (v) => widget.onChanged(
                              widget.ingredient.clone()
                                ..quantity = double.tryParse(v) ?? 0),
                        ),
                      ),
                      const SizedBox(width: Spacing.xs),
                      Expanded(
                        flex: 3,
                        child: _buildTextField(
                          context,
                          label: 'Unit (optional)',
                          value: widget.ingredient.unitName,
                          onChanged: (v) => widget.onChanged(
                              widget.ingredient.clone()..unitName = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.s),
                  _buildTextField(
                    context,
                    label: 'Preparation (optional)',
                    value: widget.ingredient.preparation,
                    onChanged: (v) => widget.onChanged(
                        widget.ingredient.clone()..preparation = v),
                  ),
                  const SizedBox(height: Spacing.s),
                  _buildTextField(
                    context,
                    label: 'Component (optional)',
                    value: widget.ingredient.component,
                    onChanged: (v) => widget.onChanged(
                        widget.ingredient.clone()..component = v),
                  ),
                ],
              ),
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
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyles.caption(context),
        filled: true,
        fillColor: context.colours.background,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.s, vertical: Spacing.xs),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colours.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colours.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colours.primary),
        ),
      ),
      style: TextStyles.body(context),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
    );
  }
}
