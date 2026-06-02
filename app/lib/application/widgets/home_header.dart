import 'package:flutter/material.dart';
import '../screens/settings_screen.dart';
import '../styles/colours.dart';
import '../styles/shapes.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.tertiaryContainer,
              borderRadius: Shapes.blob(44),
            ),
            alignment: Alignment.center,
            child: const Text('🥦', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _formatDate(DateTime.now()),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
                letterSpacing: 0.1,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: c.textSecondary),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime d) {
  const weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${weekdays[d.weekday - 1]} · ${d.day} ${months[d.month - 1]}';
}
