import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/mixer_state.dart';
import '../../../domain/models/track_ref.dart';
import '../../providers/providers.dart';
import '../../widgets/app_layout.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/primary_button.dart';

class MixerForegroundUploadScreen extends ConsumerStatefulWidget {
  const MixerForegroundUploadScreen({super.key});

  @override
  ConsumerState<MixerForegroundUploadScreen> createState() =>
      _MixerForegroundUploadScreenState();
}

class _MixerForegroundUploadScreenState
    extends ConsumerState<MixerForegroundUploadScreen> {
  static const _allowed = {'mp3', 'wav', 'aac', 'm4a'};
  static const _maxBytes = 100 * 1024 * 1024;
  String? _error;
  TrackRef? _track;

  @override
  void initState() {
    super.initState();
    _track = ref.read(mixerDraftProvider)?.foreground;
  }

  Future<void> _pick() async {
    setState(() => _error = null);
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowed.toList(),
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final path = f.path;
    if (path == null) {
      setState(() => _error = 'Could not read file path.');
      return;
    }
    final ext = f.extension?.toLowerCase() ?? '';
    if (!_allowed.contains(ext)) {
      setState(() => _error = 'Unsupported format.');
      return;
    }
    if (f.size > _maxBytes) {
      setState(() => _error = 'File too large (max 100MB).');
      return;
    }
    if (!File(path).existsSync()) {
      setState(() => _error = 'Missing permissions or file missing.');
      return;
    }

    var durMs = 180000;
    final player = AudioPlayer();
    try {
      await player.setFilePath(path);
      durMs = player.duration?.inMilliseconds ?? durMs;
    } finally {
      await player.dispose();
    }

    setState(() {
      _track = TrackRef(
        id: const Uuid().v4(),
        localPath: path,
        displayName: f.name,
        durationMs: durMs,
        mimeType: ext,
      );
    });
  }

  void _continue() {
    final draft = ref.read(mixerDraftProvider);
    if (draft?.background == null) {
      context.go('/picker');
      return;
    }
    if (_track == null) {
      setState(() => _error = 'Select foreground audio first.');
      return;
    }
    final duration = draft!.background!.durationMs > _track!.durationMs
        ? draft.background!.durationMs
        : _track!.durationMs;
    ref.read(mixerDraftProvider.notifier).state = MixerDraft(
      sessionId: draft.sessionId,
      title: draft.title,
      background: draft.background,
      foreground: _track,
      notes: draft.notes,
    );
    ref.read(mixerUiProvider.notifier).state = ref
        .read(mixerUiProvider)
        .copyWith(durationMs: duration);
    ref.read(mixerReadyProvider.notifier).state = true;
    context.push('/mixer/editor');
  }

  @override
  Widget build(BuildContext context) {
    final bg = ref.watch(mixerDraftProvider)?.background;
    return Scaffold(
      appBar: AppBar(title: const Text('Step 2 · Foreground Audio')),
      body: AppContent(
        child: ListView(
          children: [
            AppSurfaceCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload foreground track',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Background: ${bg?.displayName ?? 'Not selected'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppSurfaceCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_track?.displayName ?? 'No foreground selected'),
                subtitle: Text(
                  _track != null
                      ? '${(_track!.durationMs / 1000).round()} sec'
                      : 'MP3/WAV/AAC/M4A',
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 14),
            PrimaryButton(
              label: _track == null ? 'Select Foreground' : 'Change Foreground',
              onPressed: _pick,
              outlined: true,
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Continue to Mixer Editor',
              onPressed: _continue,
            ),
          ],
        ),
      ),
    );
  }
}
