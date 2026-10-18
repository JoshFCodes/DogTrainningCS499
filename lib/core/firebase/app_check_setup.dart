import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

Future<void> initializeAppCheck() async {
  if (kIsWeb) {
    const siteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

    if (siteKey.isEmpty) {
      throw StateError(
        'Missing RECAPTCHA_SITE_KEY. Provide the App Check '
        'reCAPTCHA site key when running the web app.',
      );
    }

    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaV3Provider(siteKey),
    );

    return;
  }

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleDeviceCheckProvider(),
  );
}
