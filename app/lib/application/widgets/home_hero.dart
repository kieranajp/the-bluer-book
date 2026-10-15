import 'package:flutter/material.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../utils/home_greeting.dart';

class HomeHero extends StatelessWidget {
  const HomeHero({super.key, HomeGreeting? greeting}) : _greeting = greeting;

  /// Overridable for tests / previews; defaults to a mealtime-aware pick.
  final HomeGreeting? _greeting;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final greeting = _greeting ?? greetingFor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${greeting.lead}\n',
              style: TextStyles.heroDisplay(context),
            ),
            TextSpan(
              text: greeting.emphasis,
              style: TextStyles.heroDisplay(context).copyWith(
                fontStyle: FontStyle.italic,
                color: c.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
