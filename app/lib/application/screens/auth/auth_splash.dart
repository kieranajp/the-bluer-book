import 'package:flutter/material.dart';

import '../../styles/colours.dart';

/// Splash shown while [AuthGate] tries to resume a persisted Kratos
/// session via /api/me on cold start. Just a centred spinner — the
/// resume attempt is fast, so any branding would flash and feel laggy.
class AuthSplash extends StatelessWidget {
  const AuthSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colours.background,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
