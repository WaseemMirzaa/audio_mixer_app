import '../models/mix_session.dart';

abstract class SessionRepository {
  Future<List<MixSession>> listSessions();

  Future<MixSession?> getSession(String sessionId);

  Future<MixSession> upsertSession(MixSession session);

  Future<void> deleteSession(String sessionId);

  Future<void> renameSession({
    required String sessionId,
    required String title,
  });
}
