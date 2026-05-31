import 'package:flutter/material.dart';

import '../../styles/colours.dart';

/// Shown when a recipe has no method steps to cook through.
class CookingEmptyState extends StatelessWidget {
  final String recipeName;

  const CookingEmptyState({super.key, required this.recipeName});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: c.textSecondary,
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.soup_kitchen_outlined,
                    size: 48, color: c.textSecondary),
                const SizedBox(height: 16),
                Text(
                  'No steps to cook',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$recipeName has no method steps yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: c.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
