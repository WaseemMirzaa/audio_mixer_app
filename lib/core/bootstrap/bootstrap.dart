import 'package:firebase_core/firebase_core.dart';
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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

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
