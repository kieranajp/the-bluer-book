import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global test configuration, auto-discovered by `flutter test` and applied to
/// every test in this directory tree.
///
/// We run alchemist with a single, **readable** golden set (the `goldens/ci/`
/// folder, regardless of host). Real text is rendered with the fonts bundled
/// under app/fonts/, and Flutter draws goldens through its own engine (Skia +
/// those bundled fonts), so the PNGs are deterministic across machines on the
/// same Flutter version — a dev box and the Ubuntu CI runner agree. We disable
/// alchemist's separate per-OS "platform" goldens so there's only one set to
/// maintain. Regenerate after an intended UI change with:
///
///   flutter test --update-goldens
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The app styles text with google_fonts, which by default fetches font files
  // over the network — blocked by the test binding (all HTTP returns 400), so a
  // fetch would throw. Disable fetching: google_fonts loads the families bundled
  // under app/fonts/ from the asset bundle instead.
  GoogleFonts.config.allowRuntimeFetching = false;

  // google_fonts loads fonts asynchronously and fire-and-forget. A family that
  // is still mid-load when a golden frame is captured renders as .notdef boxes
  // (and doesn't fall back), so text comes out as blocks. Trigger a load of
  // every family/variant the app renders here, then await pendingFonts(): this
  // registers each one up front so every later GoogleFonts.*() call — including
  // those made inside a widget's build() — resolves to real glyphs immediately.
  // Keep this in sync with the variants bundled in pubspec.yaml's assets.
  GoogleFonts.workSans();
  GoogleFonts.workSans(fontWeight: FontWeight.w500);
  GoogleFonts.workSans(fontWeight: FontWeight.w600);
  GoogleFonts.workSans(fontWeight: FontWeight.w700);
  GoogleFonts.workSans(fontWeight: FontWeight.w800);
  GoogleFonts.instrumentSerif();
  GoogleFonts.instrumentSerif(fontStyle: FontStyle.italic);
  GoogleFonts.jetBrainsMono();
  GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w500);
  GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w600);
  await GoogleFonts.pendingFonts();

  await AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      // One shared, readable golden set in goldens/ci/. obscureText:false draws
      // real glyphs (not redaction blocks); renderShadows:true keeps shadows so
      // the image matches what ships.
      ciGoldensConfig: CiGoldensConfig(obscureText: false, renderShadows: true),
      // No per-OS "platform" goldens — avoids a second, host-specific image set.
      platformGoldensConfig: PlatformGoldensConfig(enabled: false),
    ),
    run: testMain,
  );
}
