import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_mixer_app.dart';
import 'core/config/backend.dart';
import 'presentation/providers/providers.dart';
import 'services/incoming_shared_audio.dart';
import 'services/mixer_audio_handler.dart';

/// Toggle backend: [AppBackend.mock] for prototype; [AppBackend.firebase] uses
/// Firebase Auth only — sessions, presets, and audio stay on local device storage.
const AppBackend kAppBackend = AppBackend.firebase;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  IncomingSharedAudio.startListening();

  // Register our dual-player audio handler with the OS media session.
  // This replaces just_audio_background and supports multiple AudioPlayers.
  MixerAudioHandler? handler;
  try {
    handler = await AudioService.init(
      builder: () => MixerAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.codetivelab.soundAxis.audio',
        androidNotificationChannelName: 'Audio Mixer Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    // Degrade gracefully: app still loads, background audio absent.
    debugPrint('[AudioService] init failed: $e');
    handler = MixerAudioHandler();
  }

  // Load SharedPreferences after audio init to avoid SQLITE_BUSY races.
  final prefs = await SharedPreferences.getInstance();

  // Cold-start share (Open With / Share) — stash until splash / picker consume it.
  final initialShared = await IncomingSharedAudio.takeInitial();

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        appBackendProvider.overrideWithValue(kAppBackend),
        mixerAudioHandlerProvider.overrideWithValue(handler),
        if (initialShared != null)
          pendingSharedForegroundProvider.overrideWith((ref) => initialShared),
      ],
      child: const AudioMixerApp(),
    ),
  );
}
