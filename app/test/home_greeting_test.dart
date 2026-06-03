import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/application/utils/home_greeting.dart';

void main() {
  group('mealtimeForHour', () {
    test('maps each hour to the expected mealtime', () {
      // Boundaries: 5–10 breakfast, 11–14 lunch, 15–16 afternoon,
      // 17–21 dinner, everything else late night.
      expect(mealtimeForHour(5), Mealtime.breakfast);
      expect(mealtimeForHour(10), Mealtime.breakfast);
      expect(mealtimeForHour(11), Mealtime.lunch);
      expect(mealtimeForHour(14), Mealtime.lunch);
      expect(mealtimeForHour(15), Mealtime.afternoon);
      expect(mealtimeForHour(16), Mealtime.afternoon);
      expect(mealtimeForHour(17), Mealtime.dinner);
      expect(mealtimeForHour(21), Mealtime.dinner);
      expect(mealtimeForHour(22), Mealtime.lateNight);
      expect(mealtimeForHour(0), Mealtime.lateNight);
      expect(mealtimeForHour(4), Mealtime.lateNight);
    });
  });

  group('greetingFor', () {
    test('keeps the classic "what\'s cooking tonight?" in the dinner set', () {
      // Across many seeds in the evening we should eventually surface the
      // original line, and never escape the dinner-time phrasing.
      final seen = <HomeGreeting>{};
      for (var seed = 0; seed < 100; seed++) {
        seen.add(greetingFor(now: DateTime(2026, 6, 3, 19), random: Random(seed)));
      }
      expect(seen, contains((lead: "What's cooking", emphasis: 'tonight?')));
    });

    test('picks a breakfast-flavoured greeting in the morning', () {
      // Whatever the random pick, a morning greeting should never be the
      // dinner default.
      for (var seed = 0; seed < 20; seed++) {
        final g = greetingFor(
          now: DateTime(2026, 6, 3, 8),
          random: Random(seed),
        );
        expect(g.emphasis, isNot('tonight?'));
      }
    });

    test('always yields non-empty lead and emphasis text', () {
      for (var hour = 0; hour < 24; hour++) {
        for (var seed = 0; seed < 5; seed++) {
          final g = greetingFor(
            now: DateTime(2026, 6, 3, hour),
            random: Random(seed),
          );
          expect(g.lead, isNotEmpty);
          expect(g.emphasis, isNotEmpty);
        }
      }
    });
  });
}
