import 'dart:ui';

/// Default label color when no valid hex color is provided.
const _defaultLabelColour = Color(0xFF4E6983);

/// Parses a hex color string (e.g. "#FF5733") into a [Color].
/// Returns a default blue-grey if the input is null or invalid.
Color parseLabelColour(String? hex) {
  if (hex == null || !hex.startsWith('#')) return _defaultLabelColour;

  try {
    return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
  } catch (_) {
    return _defaultLabelColour;
  }
}
