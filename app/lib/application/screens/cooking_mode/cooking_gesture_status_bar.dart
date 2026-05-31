import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../styles/colours.dart';

/// Live gesture status: tiny camera preview + a "swap direction" control so
/// the mirrored/rotated front camera can be corrected per device.
class CookingGestureStatusBar extends StatelessWidget {
  final CameraController? controller;
  final bool inverted;
  final VoidCallback onSwap;

  const CookingGestureStatusBar({
    super.key,
    required this.controller,
    required this.inverted,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final ready = controller != null && controller!.value.isInitialized;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 44,
                child: ready
                    ? FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: controller!.value.previewSize?.height ?? 44,
                          height: controller!.value.previewSize?.width ?? 44,
                          child: CameraPreview(controller!),
                        ),
                      )
                    : Container(
                        color: c.surfaceContainerHighest,
                        child: Icon(
                          Icons.videocam_outlined,
                          size: 20,
                          color: c.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ready
                    ? 'Wave your hand left → right for next'
                    : 'Starting camera…',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.textSecondary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onSwap,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text(inverted ? 'Swapped' : 'Swap'),
              style: TextButton.styleFrom(foregroundColor: c.primary),
            ),
          ],
        ),
      ),
    );
  }
}
