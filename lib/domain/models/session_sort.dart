import 'mix_session.dart';

/// Newest activity first — shared by Home "Recent" and Sessions tabs.
List<MixSession> sortSessionsByRecent(List<MixSession> sessions) {
  final copy = List<MixSession>.from(sessions);
  copy.sort((a, b) {
    final byUpdated = b.updatedAtMs.compareTo(a.updatedAtMs);
    if (byUpdated != 0) return byUpdated;
    return b.createdAtMs.compareTo(a.createdAtMs);
  });
  return copy;
}
