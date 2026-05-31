import 'package:flutter/material.dart';

import '../../domain/label.dart';

/// Dialog for adding a typed label to a recipe being edited. Presentational —
/// it reports the chosen `(type, name)` via [onAdd] and leaves persistence to
/// the caller.
class AddLabelDialog extends StatefulWidget {
  final void Function(String type, String name) onAdd;

  const AddLabelDialog({super.key, required this.onAdd});

  @override
  State<AddLabelDialog> createState() => _AddLabelDialogState();
}

class _AddLabelDialogState extends State<AddLabelDialog> {
  final _nameController = TextEditingController();
  String _selectedType = kLabelTypes.first;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit(String name) {
    widget.onAdd(_selectedType, name);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Label'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              for (final type in kLabelTypes)
                DropdownMenuItem(value: type, child: Text(type)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _selectedType = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Name (e.g. main, indian, gluten_free)',
            ),
            autofocus: true,
            onSubmitted: _submit,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => _submit(_nameController.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
