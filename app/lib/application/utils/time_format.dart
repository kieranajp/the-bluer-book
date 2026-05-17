/// Formats a duration in minutes as a compact "15m" or "1h 20m" / "2h".
String formatMinutes(int totalMinutes) {
  if (totalMinutes <= 0) return '—';
  if (totalMinutes < 60) return '${totalMinutes}m';
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
