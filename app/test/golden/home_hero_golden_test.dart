import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';

import 'package:app/application/widgets/home_hero.dart';

import 'golden_support.dart';

// A fixed greeting keeps the hero deterministic — the production default rotates
// with the time of day and a random pick.
const _greeting = (lead: "What's cooking", emphasis: 'tonight?');

// The hero is a full-width block; constrain it to a phone-ish width.
Widget _sized(Widget child) => SizedBox(width: 360, child: child);

void main() {
  goldenTest(
    'HomeHero renders the serif greeting in light and dark themes',
    fileName: 'home_hero',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        themedScenario(
          name: 'light',
          brightness: Brightness.light,
          child: _sized(const HomeHero(greeting: _greeting)),
        ),
        themedScenario(
          name: 'dark',
          brightness: Brightness.dark,
          child: _sized(const HomeHero(greeting: _greeting)),
        ),
      ],
    ),
  );
}
