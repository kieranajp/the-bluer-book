import 'dart:ui';

/// Default label color when no valid hex color is provided.
const _defaultLabelColour = Color(0xFF4E6983);

/// Attempts to parse a hex colour string (e.g. "#FF5733") into a [Color].
/// Returns null if the input is null, empty, or not a valid 6-digit hex.
Color? tryParseLabelColour(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return null;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

/// Parses a hex color string (e.g. "#FF5733") into a [Color].
/// Returns a default blue-grey if the input is null or invalid.
Color parseLabelColour(String? hex) {
  return tryParseLabelColour(hex) ?? _defaultLabelColour;
}
