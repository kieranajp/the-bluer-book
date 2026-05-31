import 'package:flutter/material.dart';

/// The floating options list shown by the ingredient/unit autocompletes.
class AutocompleteOptionsDropdown<T extends Object> extends StatelessWidget {
  final Iterable<T> options;
  final AutocompleteOnSelected<T> onSelected;
  final String Function(T) titleBuilder;
  final String? Function(T)? subtitleBuilder;

  const AutocompleteOptionsDropdown({
    super.key,
    required this.options,
    required this.onSelected,
    required this.titleBuilder,
    this.subtitleBuilder,
  });

  @override
  Widget build(BuildContext context) {
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
}
