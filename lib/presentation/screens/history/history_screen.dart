import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/mix_session.dart';
import '../../navigation/route_args.dart';
import '../../providers/providers.dart';
import '../../widgets/app_loading_state.dart';
import '../../widgets/guest_sign_in_dialog.dart';
import '../../widgets/sa_glass.dart';

enum _SessionFilter { all, favorites }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _SessionFilter _filter = _SessionFilter.all;

  List<MixSession> _applyFilter(List<MixSession> list) {
    switch (_filter) {
      case _SessionFilter.all:
        return list;
      case _SessionFilter.favorites:
        return list.where((s) => s.isFavorite).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    final sessions = ref.watch(sessionsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final user = ref.read(authStateProvider).valueOrNull;
          if (user?.isGuest == true) {
            showGuestSignInDialog(context);
            return;
          }
          context.push('/picker');
        },
        backgroundColor: glass.fabBg,
        elevation: 6,
        child: Icon(Icons.add_rounded, color: glass.fabIcon, size: 30),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SaPlayerBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SessionsHeader(glass: glass),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SessionFilterTabs(
                    selected: _filter,
                    glass: glass,
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: sessions.when(
                    data: (list) {
                      final filtered = _applyFilter(list);
                      if (filtered.isEmpty) {
                        return _SessionsEmptyState(
                          filter: _filter,
                          glass: glass,
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _SessionListTile(
                          session: filtered[i],
                          glass: glass,
                          index: i,
                        ),
                      );
                    },
                    loading: () => const AppLoadingState(
                      message: 'Loading sessions...',
                    ),
                    error: (e, _) => Center(
                      child:
                          Text('$e', style: TextStyle(color: glass.textMuted)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsHeader extends StatelessWidget {
  const _SessionsHeader({required this.glass});

  final SaGlass glass;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => context.go('/home'),
              icon: Icon(
                Icons.chevron_left_rounded,
                color: glass.textPrimary,
                size: 28,
              ),
            ),
          ),
          Text(
            'Sessions',
            style: TextStyle(
              color: glass.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionFilterTabs extends StatelessWidget {
  const _SessionFilterTabs({
    required this.selected,
    required this.glass,
    required this.onChanged,
  });

  final _SessionFilter selected;
  final SaGlass glass;
  final ValueChanged<_SessionFilter> onChanged;

  static const _labels = {
    _SessionFilter.all: 'All',
    _SessionFilter.favorites: 'Favorites',
  };

  @override
  Widget build(BuildContext context) {
    final selectedBg =
        glass.isDark ? glass.accent : const Color(0xFF2A9DB0);

    return Row(
      children: _SessionFilter.values.map((filter) {
        final isSelected = filter == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: filter != _SessionFilter.values.last ? 8 : 0,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(filter),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [glass.glassTop, glass.glassBottom],
                          ),
                    color: isSelected ? selectedBg : null,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : glass.glassBorder,
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _labels[filter]!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : glass.textMuted,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SessionsEmptyState extends StatelessWidget {
  const _SessionsEmptyState({
    required this.filter,
    required this.glass,
  });

  final _SessionFilter filter;
  final SaGlass glass;

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      _SessionFilter.all => 'No sessions yet.\nTap + to start a new mix.',
      _SessionFilter.favorites => 'No favorite sessions yet.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: glass.textMuted,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _SessionListTile extends ConsumerWidget {
  const _SessionListTile({
    required this.session,
    required this.glass,
    required this.index,
  });

  final MixSession session;
  final SaGlass glass;
  final int index;

  static final _dateFmt = DateFormat('MMM d, yyyy • HH:mm');

  Future<void> _toggleFavorite(WidgetRef ref) async {
    await ref
        .read(sessionRepositoryProvider)
        .upsertSession(session.copyWith(isFavorite: !session.isFavorite));
    ref.invalidate(sessionsProvider);
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    final glass = SaGlass.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: Stack(
          children: [
            Positioned.fill(child: const SaPlayerBackground()),
            SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: glass.glassBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _OptionTile(
                    glass: glass,
                    icon: Icons.info_outline_rounded,
                    label: 'View details',
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/session/${session.sessionId}');
                    },
                  ),
                  _OptionTile(
                    glass: glass,
                    icon: Icons.play_arrow_rounded,
                    label: 'Open in mixer',
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(mixerLaunchArgsProvider.notifier).state =
                          MixerLaunchArgs(sessionId: session.sessionId);
                      context.push('/mixer');
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final created = DateTime.fromMillisecondsSinceEpoch(session.createdAtMs);

    return GestureDetector(
      onTap: () => context.push('/session/${session.sessionId}'),
      child: Container(
        decoration: glass.card(),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        child: Row(
          children: [
            SaCategoryIcon(glass: glass, index: index, size: 50),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: TextStyle(
                      color: glass.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'with ${session.backgroundDisplayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: glass.textMuted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dateFmt.format(created),
                    style: TextStyle(color: glass.textMeta, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _toggleFavorite(ref),
              icon: Icon(
                session.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: session.isFavorite
                    ? const Color(0xFFFF6B81)
                    : glass.textMuted,
                size: 22,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 36),
              visualDensity: VisualDensity.compact,
              tooltip: session.isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
            ),
            const SizedBox(width: 2),
            SaPlayRing(
              glass: glass,
              size: 40,
              onTap: () {
                ref.read(mixerLaunchArgsProvider.notifier).state =
                    MixerLaunchArgs(sessionId: session.sessionId);
                context.push('/mixer');
              },
            ),
            IconButton(
              onPressed: () => _showOptions(context, ref),
              icon: Icon(
                Icons.more_vert_rounded,
                color: glass.textMuted,
                size: 22,
              ),
              padding: const EdgeInsets.only(left: 2),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.glass,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final SaGlass glass;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: glass.accent),
      title: Text(
        label,
        style: TextStyle(
          color: glass.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
