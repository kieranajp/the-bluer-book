import 'package:flutter/material.dart';
import '../styles/colours.dart';

/// Pill-shaped search bar.
class PillSearch extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hint;

  const PillSearch({
    super.key,
    required this.onChanged,
    this.hint = 'Search recipes…',
  });

  @override
  State<PillSearch> createState() => _PillSearchState();
}

class _PillSearchState extends State<PillSearch> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: c.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: c.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: widget.onChanged,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    color: c.textSecondary.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
                style: TextStyle(color: c.textPrimary, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
