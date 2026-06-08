import '../../domain/models/track_ref.dart';

/// Remote demo MP3s for mock backend (Pixabay CDN).
abstract final class MockDemoAudio {
  static const foregroundUrl =
      'https://cdn.pixabay.com/download/audio/2022/03/15/audio_c8c8a73467.mp3';
  static const backgroundUrl =
      'https://cdn.pixabay.com/download/audio/2022/03/10/audio_c63f2d4ac0.mp3';

  static const foreground = TrackRef(
    id: 'demo-fg-track',
    localPath: foregroundUrl,
    displayName: 'Demo Foreground Narration',
    durationMs: 181000,
    mimeType: 'mp3',
  );

  static const background = TrackRef(
    id: 'demo-bg-track',
    localPath: backgroundUrl,
    displayName: 'Demo Background Ambience',
    durationMs: 210000,
    mimeType: 'mp3',
  );

  static int combinedDurationMs() =>
      foreground.durationMs > background.durationMs
      ? foreground.durationMs
      : background.durationMs;
}
