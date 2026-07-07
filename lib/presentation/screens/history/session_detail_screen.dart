import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/mix_session.dart';
import '../../navigation/route_args.dart';
import '../../providers/providers.dart';
import '../../widgets/app_loading_state.dart';
import '../../widgets/sa_glass.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionDetailProvider(sessionId));
    final glass = SaGlass.of(context);

    return SaGlassScaffold(
      child: async.when(
        data: (s) {
          if (s == null) {
            return Column(
              children: [
                SaBackHeader(
                  title: 'Session',
                  subtitle: 'Audiobook session',
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: [
                      const SizedBox(height: 60),
                      Center(
                        child: Text(
                          'Session not found',
                          style:
                              TextStyle(color: glass.textMuted, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return _SessionDetailBody(session: s);
        },
        loading: () =>
            const AppLoadingState(message: 'Loading session details...'),
        error: (_, __) => Column(
          children: [
            SaBackHeader(
              title: 'Session',
              subtitle: 'Audiobook session',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  const SizedBox(height: 60),
                  Center(
                    child: Text(
                      'Could not load session',
                      style: TextStyle(color: glass.textMuted, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionDetailBody extends ConsumerWidget {
  const _SessionDetailBody({required this.session});

  final MixSession session;

  static final _dateFmt = DateFormat.yMMMd().add_jm();

  String _fmtMmSs(int ms) {
    final s = (ms / 1000).floor().clamp(0, 360000);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  String _eqString(List<double> eq) =>
      eq.map((e) => e >= 0 ? '+${e.toStringAsFixed(1)}' : e.toStringAsFixed(1)).join('  ');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = session;
    final glass = SaGlass.of(context);
    final created = DateTime.fromMillisecondsSinceEpoch(s.createdAtMs);
    final updated = DateTime.fromMillisecondsSinceEpoch(s.updatedAtMs);

    return Column(
      children: [
        SaBackHeader(
          title: s.title,
          subtitle: 'Audiobook session',
          onBack: () => context.pop(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              const SizedBox(height: 14),

              // ── Hero header ──
              Container(
          decoration: glass.hero(radius: 20),
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SaCategoryIcon(glass: glass, index: 0, size: 50),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: TextStyle(
                        color: glass.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Created ${_dateFmt.format(created)}',
                      style: TextStyle(color: glass.textMeta, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Saved ${_dateFmt.format(updated)}',
                      style: TextStyle(color: glass.textMeta, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Duration ${_fmtMmSs(s.durationMs)}  ·  ${s.playbackSpeed == 1.0 ? '1×' : '${s.playbackSpeed}×'} speed',
                      style: TextStyle(color: glass.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Tracks ──
        _GlassPanel(
          glass: glass,
          title: 'Tracks',
          child: Column(
            children: [
              _TrackRow(
                glass: glass,
                icon: Icons.menu_book_rounded,
                index: 0,
                label: 'Foreground',
                name: s.foregroundDisplayName,
              ),
              const SizedBox(height: 12),
              _TrackRow(
                glass: glass,
                icon: Icons.graphic_eq_rounded,
                index: 1,
                label: 'Background',
                name: s.backgroundDisplayName,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Volumes & master ──
        _GlassPanel(
          glass: glass,
          title: 'Volume Mix',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                glass: glass,
                label: 'Foreground',
                value: '${(s.foregroundVolume * 100).round()}%',
              ),
              _DetailRow(
                glass: glass,
                label: 'Background',
                value: '${(s.backgroundVolume * 100).round()}%',
              ),
              _DetailRow(
                glass: glass,
                label: 'Master Gain',
                value: '${(s.masterGain * 100).round()}%',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── EQ ──
        _GlassPanel(
          glass: glass,
          title: 'Equalizer  (60Hz · 230Hz · 910Hz · 3.6kHz · 14kHz)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                  glass: glass, label: 'FG EQ', value: _eqString(s.foregroundEq)),
              _DetailRow(
                  glass: glass, label: 'BG EQ', value: _eqString(s.backgroundEq)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Effects ──
        _GlassPanel(
          glass: glass,
          title: 'Audio Effects',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                glass: glass,
                label: 'FG Bass Boost',
                value: '${(s.foregroundBassBoost * 100).round()}%',
              ),
              _DetailRow(
                glass: glass,
                label: 'BG Bass Boost',
                value: '${(s.backgroundBassBoost * 100).round()}%',
              ),
              _DetailRow(
                glass: glass,
                label: 'FG Virtualizer',
                value: '${(s.foregroundVirtualizer * 100).round()}%',
              ),
              _DetailRow(
                glass: glass,
                label: 'BG Virtualizer',
                value: '${(s.backgroundVirtualizer * 100).round()}%',
              ),
              _DetailRow(
                glass: glass,
                label: 'FG Loudness',
                value: '${s.foregroundLoudness.toStringAsFixed(1)} dB',
              ),
              _DetailRow(
                glass: glass,
                label: 'BG Loudness',
                value: '${s.backgroundLoudness.toStringAsFixed(1)} dB',
              ),
            ],
          ),
        ),

        // ── Notes (only if present) ──
        if (s.notes != null && s.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _GlassPanel(
            glass: glass,
            title: 'Notes',
            child: Text(
              s.notes!,
              style: TextStyle(
                color: glass.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],

        const SizedBox(height: 22),

        // ── Open Player ──
        SaPrimaryButton(
          label: 'Open Player',
          icon: Icons.play_arrow_rounded,
          onPressed: () {
            ref.read(mixerLaunchArgsProvider.notifier).state =
                MixerLaunchArgs(sessionId: s.sessionId);
            context.push('/mixer');
          },
        ),
        const SizedBox(height: 12),

        // ── Duplicate ──
        SaSecondaryButton(
          label: 'Duplicate Session',
          icon: Icons.copy_rounded,
          onPressed: () async {
            final repo = ref.read(sessionRepositoryProvider);
            final latest = await repo.getSession(s.sessionId) ?? s;
            final copy = latest.copyWith(
              sessionId: '',
              title: '${latest.title} copy',
              createdAtMs: DateTime.now().millisecondsSinceEpoch,
              updatedAtMs: DateTime.now().millisecondsSinceEpoch,
              isFavorite: false,
            );
            await repo.upsertSession(copy);
            refreshSessionsList(ref, sessionId: s.sessionId);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Duplicated session')),
            );
          },
        ),
        const SizedBox(height: 14),

        // ── Delete ──
        Center(
          child: TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                barrierColor: Colors.black54,
                builder: (ctx) {
                  final g = SaGlass.of(ctx);
                  return Dialog(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    child: Container(
                      decoration: g.dialogCard(radius: 20),
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete session?',
                            style: TextStyle(
                              color: g.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This session will be permanently removed. This action cannot be undone.',
                            style: TextStyle(
                              color: g.textMuted,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  style: TextButton.styleFrom(
                                    foregroundColor: g.textMuted,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: g.divider),
                                    ),
                                  ),
                                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: const Color(0xFFE53935),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
              if (ok == true) {
                await ref
                    .read(sessionRepositoryProvider)
                    .deleteSession(s.sessionId);
                refreshSessionsList(ref, sessionId: s.sessionId);
                if (!context.mounted) return;
                context.pop();
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF7A9D)),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Glass card section with a cyan title header.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.glass,
    required this.title,
    required this.child,
  });

  final SaGlass glass;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: glass.card(radius: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: glass.cyan,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// A track (foreground / background) shown with a gradient icon tile.
class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.glass,
    required this.icon,
    required this.index,
    required this.label,
    required this.name,
  });

  final SaGlass glass;
  final IconData icon;
  final int index;
  final String label;
  final String name;

  @override
  Widget build(BuildContext context) {
    final gradient = glass.catGradients[index % glass.catGradients.length];
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: glass.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(color: glass.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact inline label + value row for session detail panels.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.glass,
    required this.label,
    required this.value,
  });

  final SaGlass glass;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: glass.textMuted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: glass.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
