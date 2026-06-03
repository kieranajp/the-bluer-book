import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global test configuration, auto-discovered by `flutter test` and applied to
/// every test in this directory tree.
///
/// We run alchemist with **only** CI goldens enabled. CI goldens render text in
/// the Ahem block font (`obscureText`) with shadows off, so the resulting PNGs
/// are byte-identical on any machine — an Arch dev box, this container, and the
/// Ubuntu CI runner all produce the same image. That sidesteps the usual golden
/// footgun where fonts/anti-aliasing differ per platform. Reference images live
/// in `goldens/ci/` next to each test; regenerate with:
///
///   flutter test --update-goldens
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // The app styles text with google_fonts, which by default fetches font files
  // over the network — blocked by the test binding (all HTTP returns 400), so a
  // fetch would throw. Disable fetching: google_fonts then loads the families
  // bundled under app/fonts/ from the asset bundle instead, fully offline and
  // deterministic. (CI goldens obscure glyphs into Ahem blocks regardless.)
  GoogleFonts.config.allowRuntimeFetching = false;

  await AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: false),
    ),
    run: testMain,
  );
}
