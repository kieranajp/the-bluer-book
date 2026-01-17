import 'package:flutter/material.dart';
import '../../domain/step.dart' as domain;
import '../styles/text_styles.dart';
import '../styles/spacing.dart';
import '../styles/colours.dart';

class InstructionsList extends StatelessWidget {
  final List<domain.Step> steps;

  const InstructionsList({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          final isLast = index == steps.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step number and vertical line
                Column(
                  children: [
                    // Numbered circle badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: context.colours.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          step.order.toString(),
                          style: TextStyle(
                            color: context.colours.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Vertical connecting line (hidden for last item)
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: Spacing.xs),
                          decoration: BoxDecoration(
                            color: context.colours.border,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: Spacing.m),
                // Step description
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: isLast ? 0 : Spacing.m,
                    ),
                    child: Text(
                      step.description,
                      style: TextStyles.bodyText(context).copyWith(
                        height: 1.5, // leading-relaxed equivalent
                        fontWeight: FontWeight.w500, // font-medium
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}