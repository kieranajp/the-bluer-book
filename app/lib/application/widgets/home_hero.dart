import 'package:flutter/material.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';

/// Hero greeting — "What's cooking // tonight?" in Instrument Serif, with
/// the second line italicised in the primary colour. One of the deliberate
/// "beeeg padding" moments — see Shape DNA spec.
class HomeHero extends StatelessWidget {
  const HomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: "What's cooking\n",
              style: TextStyles.heroDisplay(context),
            ),
            TextSpan(
              text: 'tonight?',
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
