import 'dart:math';

/// A two-line hero greeting: a plain [lead] line and an [emphasis] line that
/// the home hero italicises in the primary colour.
typedef HomeGreeting = ({String lead, String emphasis});

/// The mealtime we infer from the wall clock. Used to pick a greeting that
/// fits what someone's likely about to cook.
enum Mealtime { breakfast, lunch, afternoon, dinner, lateNight }

/// Maps an hour-of-day (0–23) to the mealtime it most likely belongs to.
Mealtime mealtimeForHour(int hour) {
  if (hour >= 5 && hour < 11) return Mealtime.breakfast;
  if (hour >= 11 && hour < 15) return Mealtime.lunch;
  if (hour >= 15 && hour < 17) return Mealtime.afternoon;
  if (hour >= 17 && hour < 22) return Mealtime.dinner;
  return Mealtime.lateNight;
}

/// Greetings grouped by mealtime. The hero renders [emphasis] italicised in the
/// primary colour on its own line, so each pair reads as a two-line phrase.
const Map<Mealtime, List<HomeGreeting>> _greetings = {
  Mealtime.breakfast: [
    (lead: "What's for", emphasis: 'breakfast?'),
    (lead: 'Rise and', emphasis: 'shine.'),
    (lead: 'First things', emphasis: 'first — coffee?'),
    (lead: 'How do you take', emphasis: 'your eggs?'),
    (lead: 'Morning. What are', emphasis: 'we making?'),
  ],
  Mealtime.lunch: [
    (lead: "What's for", emphasis: 'lunch?'),
    (lead: 'Midday', emphasis: 'munchies?'),
    (lead: 'Time for a', emphasis: 'proper feed.'),
    (lead: 'Lunch is', emphasis: 'calling.'),
    (lead: 'What are we', emphasis: 'fixing up?'),
  ],
  Mealtime.afternoon: [
    (lead: 'Fancy a', emphasis: 'little something?'),
    (lead: 'Afternoon', emphasis: 'snack?'),
    (lead: 'Time for', emphasis: 'tea and cake?'),
    (lead: 'Need a', emphasis: 'pick-me-up?'),
  ],
  Mealtime.dinner: [
    (lead: "What's cooking", emphasis: 'tonight?'),
    (lead: "What's for", emphasis: 'dinner?'),
    (lead: 'Tonight, we', emphasis: 'feast.'),
    (lead: "What's on the", emphasis: 'menu?'),
    (lead: 'Hungry', emphasis: 'yet?'),
  ],
  Mealtime.lateNight: [
    (lead: 'Late-night', emphasis: 'cravings?'),
    (lead: 'Midnight', emphasis: 'feast?'),
    (lead: 'Burning the', emphasis: 'midnight oil?'),
    (lead: 'A cheeky', emphasis: 'late one?'),
  ],
};

/// Picks a greeting for the given moment. The mealtime is inferred from the
/// hour; within that bucket a greeting is chosen at random.
///
/// [now] and [random] are injectable for deterministic tests; both default to
/// live values.
HomeGreeting greetingFor({DateTime? now, Random? random}) {
  final mealtime = mealtimeForHour((now ?? DateTime.now()).hour);
  final options = _greetings[mealtime]!;
  return options[(random ?? Random()).nextInt(options.length)];
}
