import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/infrastructure/config/oauth_config.dart';

void main() {
  final scheme = Uri.parse(OAuthConfig.redirectUri).scheme;

  test('Android claims the redirect scheme', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final claimed = RegExp(r'"appAuthRedirectScheme" to "([^"]+)"')
        .allMatches(gradle)
        .map((m) => m[1])
        .toSet();
    expect(claimed, {scheme});
  });

  test('iOS registers the redirect scheme', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final schemes = RegExp(
      r'<key>CFBundleURLSchemes</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).allMatches(plist).expand(
          (m) => RegExp(r'<string>([^<]*)</string>')
              .allMatches(m[1]!)
              .map((s) => s[1]),
        );
    expect(schemes.toSet(), {scheme});
  });
}
