import 'package:flutter/material.dart';
import '../styles/colours.dart';
import '../styles/spacing.dart';

/// Reusable empty/error state placeholder with an icon, title, and optional subtitle or action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48,
                color: context.colours.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: Spacing.m),
            Text(
              title,
              style: TextStyle(color: context.colours.textSecondary),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: Spacing.xs),
              Text(
                subtitle!,
                style: TextStyle(
                  color: context.colours.textSecondary.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: Spacing.m),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
