import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/ingredient.dart';
import '../providers/edit_recipe_provider.dart';
import '../styles/colours.dart';
import '../styles/decorations.dart';
import '../styles/spacing.dart';
import '../styles/text_styles.dart';

class IngredientEditCard extends StatefulWidget {
  final int index;
  final EditableIngredient ingredient;
  final List<IngredientUnit> availableUnits;
  final List<IngredientDetail> availableIngredients;
  final ValueChanged<EditableIngredient> onChanged;
  final VoidCallback onDelete;

  const IngredientEditCard({
    super.key,
    required this.index,
    required this.ingredient,
    required this.availableUnits,
    required this.availableIngredients,
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
      widget.ingredient.name.isNotEmpty
          ? widget.ingredient.name
          : 'New ingredient',
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
                  _buildIngredientAutocomplete(context),
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
                        child: _buildUnitAutocomplete(context),
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

  Widget _buildIngredientAutocomplete(BuildContext context) {
    return Autocomplete<IngredientDetail>(
      initialValue: TextEditingValue(text: widget.ingredient.name),
      displayStringForOption: (ing) => ing.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase().trim();
        if (query.isEmpty) {
          return widget.availableIngredients;
        }
        return widget.availableIngredients
            .where((ing) => ing.name.toLowerCase().contains(query));
      },
      onSelected: (ing) {
        widget.onChanged(widget.ingredient.clone()..name = ing.name);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: _inputDecoration(context, 'Name'),
          style: TextStyles.body(context),
          onChanged: (v) =>
              widget.onChanged(widget.ingredient.clone()..name = v),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return _buildOptionsDropdown<IngredientDetail>(
          options: options,
          onSelected: onSelected,
          titleBuilder: (ing) => ing.name,
        );
      },
    );
  }

  Widget _buildUnitAutocomplete(BuildContext context) {
    return Autocomplete<IngredientUnit>(
      initialValue: TextEditingValue(text: widget.ingredient.unitName),
      displayStringForOption: (unit) => unit.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase().trim();
        if (query.isEmpty) {
          return widget.availableUnits;
        }
        return widget.availableUnits
            .where((unit) => unit.name.toLowerCase().contains(query));
      },
      onSelected: (unit) {
        widget.onChanged(widget.ingredient.clone()
          ..unitName = unit.name
          ..unitAbbreviation = unit.abbreviation ?? '');
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: _inputDecoration(context, 'Unit (optional)'),
          style: TextStyles.body(context),
          onChanged: (v) =>
              widget.onChanged(widget.ingredient.clone()..unitName = v),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return _buildOptionsDropdown<IngredientUnit>(
          options: options,
          onSelected: onSelected,
          titleBuilder: (unit) => unit.name,
          subtitleBuilder: (unit) =>
              unit.abbreviation != null && unit.abbreviation!.isNotEmpty
                  ? unit.abbreviation
                  : null,
        );
      },
    );
  }

  Widget _buildOptionsDropdown<T extends Object>({
    required Iterable<T> options,
    required AutocompleteOnSelected<T> onSelected,
    required String Function(T) titleBuilder,
    String? Function(T)? subtitleBuilder,
  }) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final item = options.elementAt(index);
              final subtitle = subtitleBuilder?.call(item);
              return ListTile(
                dense: true,
                title: Text(titleBuilder(item)),
                subtitle: subtitle != null ? Text(subtitle) : null,
                onTap: () => onSelected(item),
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String label) {
    return InputDecoration(
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
      decoration: _inputDecoration(context, label),
      style: TextStyles.body(context),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
    );
  }
}
