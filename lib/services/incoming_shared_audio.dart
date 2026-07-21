import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_import_service.dart';

/// Native bridge for audio shared into Sound Axis (Android SEND/VIEW, iOS Open In).
class IncomingSharedAudio {
  IncomingSharedAudio._();

  static const _method =
      MethodChannel('com.codetivelab.soundAxis/incoming_audio');
  static const _events =
      EventChannel('com.codetivelab.soundAxis/incoming_audio_events');

  static StreamSubscription<dynamic>? _sub;
  static final _controller = StreamController<SharedAudioPayload>.broadcast();

  /// Broadcast of newly shared files while the app is running (warm start).
  static Stream<SharedAudioPayload> get stream => _controller.stream;

  /// Call once after [WidgetsFlutterBinding.ensureInitialized].
  static void startListening() {
    if (_sub != null) return;
    _sub = _events.receiveBroadcastStream().listen((event) {
      final payload = _parse(event);
      if (payload != null) _controller.add(payload);
    }, onError: (e) {
      debugPrint('[IncomingSharedAudio] event error: $e');
    });
  }

  /// Cold-start share that launched the app (consumed once by native).
  static Future<SharedAudioPayload?> takeInitial() async {
    try {
      final raw = await _method.invokeMethod<dynamic>('getInitialSharedAudio');
      return _parse(raw);
    } catch (e) {
      debugPrint('[IncomingSharedAudio] getInitial failed: $e');
      return null;
    }
  }

  static SharedAudioPayload? _parse(dynamic raw) {
    if (raw is! Map) return null;
    try {
      final payload = SharedAudioPayload.fromMap(raw);
      if (payload.path.isEmpty) return null;
      return payload;
    } catch (_) {
      return null;
    }
  }
}

/// Pending shared foreground track waiting for the new-session picker.
final pendingSharedForegroundProvider =
    StateProvider<SharedAudioPayload?>((ref) => null);
