import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bootstrap/bootstrap.dart';
import '../../core/config/backend.dart';
import '../../services/mixer_audio_handler.dart';
import '../../data/repositories/firebase/firebase_auth_repository.dart';
import '../../data/repositories/firebase/firebase_subscription_repository.dart';
import '../../data/repositories/mock/mock_auth_repository.dart';
import '../../data/repositories/mock/mock_subscription_repository.dart';
import '../../data/repositories/mock/mock_preset_repository.dart';
import '../../data/repositories/mock/mock_session_repository.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/mix_session.dart';
import '../../domain/models/mixer_state.dart';
import '../../domain/models/preset.dart';
import '../navigation/route_args.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/preset_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/repositories/subscription_repository.dart';

/// Set via `main.dart` override.
final appBackendProvider = Provider<AppBackend>(
  (ref) => throw UnimplementedError('Override appBackendProvider in main.dart'),
);

final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override prefsProvider in main.dart'),
);

final bootstrapProvider = FutureProvider<void>((ref) async {
  await bootstrapApp(backend: ref.watch(appBackendProvider));
  await ref.watch(subscriptionRepositoryProvider).refreshEntitlements();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  switch (ref.watch(appBackendProvider)) {
    case AppBackend.mock:
      return MockAuthRepository(ref.watch(prefsProvider));
    case AppBackend.firebase:
      return FirebaseAuthRepository();
  }
});

/// Sessions live in on-device storage (SharedPreferences) for all backends.
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return MockSessionRepository(ref.watch(prefsProvider));
});

/// Presets live in on-device storage (SharedPreferences) for all backends.
final presetRepositoryProvider = Provider<PresetRepository>((ref) {
  return MockPresetRepository(ref.watch(prefsProvider));
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  switch (ref.watch(appBackendProvider)) {
    case AppBackend.mock:
      return MockSubscriptionRepository(ref.watch(prefsProvider));
    case AppBackend.firebase:
      return FirebaseSubscriptionRepository();
  }
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authState();
});

final subscriptionStreamProvider = StreamProvider<SubscriptionSnapshot>((ref) {
  return ref.watch(subscriptionRepositoryProvider).subscriptionState();
});

/// App-scoped audio handler — registered with [AudioService] in main.dart and
/// overridden there so the same instance drives both playback and the OS media
/// session (lock-screen / notification controls).
final mixerAudioHandlerProvider = Provider<MixerAudioHandler>(
  (ref) => throw UnimplementedError(
      'Override mixerAudioHandlerProvider in main.dart'),
);

final mixerDraftProvider = StateProvider<MixerDraft?>((ref) => null);

final mixerLaunchArgsProvider = StateProvider<MixerLaunchArgs?>((ref) => null);

final mixerUiProvider = StateProvider<MixerUiState>(
  (ref) => const MixerUiState(),
);

final mixerReadyProvider = StateProvider<bool>((ref) => false);

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

final sessionsProvider = FutureProvider<List<MixSession>>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return [];
  final all = await ref.watch(sessionRepositoryProvider).listSessions();
  // Isolate sessions per user — guests and different accounts never share history.
  return all.where((s) => s.uid == uid).toList();
});

/// Streams the live playing state from the audio handler.
/// Emits false when the handler is not yet ready or has never played.
final isPlayingProvider = StreamProvider<bool>((ref) {
  try {
    final handler = ref.watch(mixerAudioHandlerProvider);
    return handler.playingStream;
  } catch (_) {
    return const Stream.empty();
  }
});

/// One session by id (local store). Do not pass [Future] from `build` into [FutureBuilder].
final sessionDetailProvider =
    FutureProvider.autoDispose.family<MixSession?, String>((ref, sessionId) {
  return ref.watch(sessionRepositoryProvider).getSession(sessionId);
});

final presetsProvider = FutureProvider<List<MixerPreset>>((ref) async {
  return ref.watch(presetRepositoryProvider).listPresets();
});

final simulateSyncFailProvider = Provider<bool>((ref) {
  final sub = ref.watch(subscriptionRepositoryProvider);
  if (sub is MockSubscriptionRepository) return sub.simulateSyncFail;
  return false;
});
