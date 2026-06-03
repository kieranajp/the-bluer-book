import 'package:flutter/material.dart';
import '../../styles/colours.dart';
import '../../styles/spacing.dart';
import '../../styles/text_styles.dart';

/// Prompts for a free-text shopping list item (e.g. "washing-up liquid").
/// Pops the trimmed name on submit, or null on cancel. Show via
/// `showDialog<String>(context: ..., builder: (_) => const AddShoppingItemDialog())`.
class AddShoppingItemDialog extends StatefulWidget {
  const AddShoppingItemDialog({super.key});

  @override
  State<AddShoppingItemDialog> createState() => _AddShoppingItemDialogState();
}

class _AddShoppingItemDialogState extends State<AddShoppingItemDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text('Add an item', style: TextStyles.sectionHeading(context)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'e.g. washing-up liquid',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
          Spacing.m, 0, Spacing.m, Spacing.s),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
