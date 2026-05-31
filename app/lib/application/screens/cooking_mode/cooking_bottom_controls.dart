import 'package:flutter/material.dart';

import '../../styles/colours.dart';
import '../../styles/shapes.dart';
import 'cooking_prev_button.dart';

/// Bottom Prev / Next (Finish on the last step).
class CookingBottomControls extends StatelessWidget {
  final int index;
  final int total;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const CookingBottomControls({
    super.key,
    required this.index,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final isFirst = index == 0;
    final isLast = index == total - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
      child: Row(
        children: [
          Expanded(
            child: CookingPrevButton(enabled: !isFirst, onTap: onPrev),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: isLast ? onFinish : onNext,
              child: Container(
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: Shapes.tornCornerSmall,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLast ? 'Finish' : 'Next step',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLast
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      color: c.onPrimary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
