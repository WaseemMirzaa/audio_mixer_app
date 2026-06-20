import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/mixer_state.dart';
import '../../../domain/models/track_ref.dart';
import '../../providers/providers.dart';

Future<void> bootstrapMixerFlow(
  WidgetRef ref, {
  bool Function()? keepAlive,
}) async {
  bool alive() => keepAlive?.call() ?? true;

  final launch = ref.read(mixerLaunchArgsProvider);
  final sessionId = launch?.sessionId;
  final presetId = launch?.presetId;

  ref.read(mixerLaunchArgsProvider.notifier).state = null;

  final sessions = ref.read(sessionRepositoryProvider);
  final presets = ref.read(presetRepositoryProvider);

  MixerDraft? nextDraft = ref.read(mixerDraftProvider);
  MixerUiState nextUi = ref.read(mixerUiProvider);

  if (sessionId != null) {
    final existing = await sessions.getSession(sessionId);
    if (!alive()) return;
    if (existing != null) {
      final fgPath = existing.foregroundPath ?? '';
      final bgPath = existing.backgroundPath ?? '';
      final fgExists = fgPath.isNotEmpty && File(fgPath).existsSync();
      final bgExists = bgPath.isNotEmpty && File(bgPath).existsSync();
      if (fgExists && bgExists) {
        nextDraft = MixerDraft(
          sessionId: existing.sessionId,
          title: existing.title,
          foreground: TrackRef(
            id: existing.foregroundAudioId,
            localPath: fgPath,
            displayName: existing.foregroundDisplayName,
            durationMs: existing.durationMs,
          ),
          background: TrackRef(
            id: existing.backgroundAudioId,
            localPath: bgPath,
            displayName: existing.backgroundDisplayName,
            durationMs: existing.durationMs,
          ),
          notes: existing.notes,
        );
      nextUi = MixerUiState(
        fgVolume: existing.foregroundVolume,
        bgVolume: existing.backgroundVolume,
        fgMuted: false,
        bgMuted: false,
        masterGain: existing.masterGain.clamp(0.0, 1.0),
        fgEq: existing.foregroundEq,
        bgEq: existing.backgroundEq,
        durationMs: existing.durationMs <= 0 ? 180000 : existing.durationMs,
        positionMs: existing.playbackPositionMs,
        playbackSpeed: existing.playbackSpeed,
        fgBassBoost: existing.foregroundBassBoost,
        bgBassBoost: existing.backgroundBassBoost,
        fgVirtualizer: existing.foregroundVirtualizer,
        bgVirtualizer: existing.backgroundVirtualizer,
        fgLoudness: existing.foregroundLoudness,
        bgLoudness: existing.backgroundLoudness,
      );
      }
    }
  }

  if (presetId != null) {
    final p = await presets.getPreset(presetId);
    if (!alive()) return;
    if (p != null) {
      nextUi = nextUi.copyWith(
        fgVolume: p.foregroundVolume,
        bgVolume: p.backgroundVolume,
        masterGain: p.masterGain.clamp(0.0, 1.0),
        fgEq: p.foregroundEq,
        bgEq: p.backgroundEq,
      );
    }
  }

  // New session (no saved session / preset): use the volumes chosen on the
  // New Session page so they carry into the player and into the save.
  if (sessionId == null && presetId == null && nextDraft != null) {
    nextUi = nextUi.copyWith(
      fgVolume: nextDraft.fgVolume,
      bgVolume: nextDraft.bgVolume,
    );
  }

  if (nextDraft?.foreground != null && nextDraft?.background != null) {
    final fgMs = nextDraft!.foreground!.durationMs;
    final bgMs = nextDraft.background!.durationMs;
    final longest = fgMs > bgMs ? fgMs : bgMs;
    final dur = longest <= 0 ? nextUi.durationMs : longest;
    nextUi = nextUi.copyWith(durationMs: dur <= 0 ? 180000 : dur);
  }

  if (!alive()) return;
  ref.read(mixerDraftProvider.notifier).state = nextDraft;
  ref.read(mixerUiProvider.notifier).state = nextUi;
  ref.read(mixerReadyProvider.notifier).state = true;
}
