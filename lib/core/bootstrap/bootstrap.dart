import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../firebase_options.dart';
import '../config/backend.dart';

bool _didBootstrap = false;

/// Initializes Firebase Auth (+ RevenueCat) when using [AppBackend.firebase].
/// Session/preset/audio data is not stored in Firebase.
Future<void> bootstrapApp({
  required AppBackend backend,
}) async {
  if (_didBootstrap) return;
  _didBootstrap = true;

  if (backend == AppBackend.firebase) {
    final options = DefaultFirebaseOptions.currentPlatform;

    // Guard against shipping placeholder credentials. If this fires, the CI
    // secrets (FIREBASE_OPTIONS_DART / GOOGLE_SERVICES_JSON) were not injected
    // with real values, and every auth / Firestore call will fail with what
    // looks like a network error.
    if (options.apiKey.contains('REPLACE_ME') || options.apiKey.isEmpty) {
      debugPrint(
        '[bootstrap] WARNING: Firebase is using PLACEHOLDER credentials '
        '(apiKey="${options.apiKey}"). Auth and Firestore will fail until real '
        'values are injected via the FIREBASE_OPTIONS_DART secret.',
      );
    }

    await Firebase.initializeApp(options: options);

    await Purchases.setLogLevel(LogLevel.warn);
    const apiKey = String.fromEnvironment(
      'REVENUECAT_PUBLIC_SDK_KEY',
      defaultValue: '',
    );
    if (apiKey.isNotEmpty) {
      await Purchases.configure(PurchasesConfiguration(apiKey));
    }
  }
}
