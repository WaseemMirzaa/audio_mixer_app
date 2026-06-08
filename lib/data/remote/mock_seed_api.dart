import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../domain/models/mix_session.dart';
import '../../../domain/models/preset.dart';

class MockSeedApi {
  static const _albumsUrl = 'https://jsonplaceholder.typicode.com/albums';
  static const _usersUrl = 'https://jsonplaceholder.typicode.com/users';

  Future<List<MixSession>> fetchSessionSeeds({required int nowMs}) async {
    final albumsRes = await http.get(Uri.parse(_albumsUrl));
    final usersRes = await http.get(Uri.parse(_usersUrl));
    if (albumsRes.statusCode != 200 || usersRes.statusCode != 200) {
      throw StateError('Unable to fetch seed data');
    }
    final albums = (jsonDecode(albumsRes.body) as List).take(6).toList();
    final users = (jsonDecode(usersRes.body) as List).cast<Map<String, dynamic>>();
    final createdAt = nowMs - const Duration(days: 2).inMilliseconds;

    return albums.asMap().entries.map((entry) {
      final i = entry.key;
      final album = entry.value as Map<String, dynamic>;
      final user = users[i % users.length];
      return MixSession(
        sessionId: 'net_seed_$i',
        uid: 'demo_uid',
        title: (album['title'] as String).split(' ').take(3).join(' '),
        foregroundAudioId: 'fg_net_$i',
        backgroundAudioId: 'bg_net_$i',
        foregroundDisplayName: '${user['username']}_vocals.m4a',
        backgroundDisplayName: 'ambient_${i + 1}.wav',
        foregroundVolume: 0.82,
        backgroundVolume: 0.42,
        foregroundEq: [2 - i * 0.2, 1, 0.5, 0.2, -0.3],
        backgroundEq: [-1, -0.5, 0.4, 1.1, 1.6],
        masterGain: 0.94,
        balance: i.isEven ? -0.08 : 0.08,
        durationMs: 120000 + (i * 45000),
        playbackPositionMs: 0,
        createdAtMs: createdAt + (i * 3600000),
        updatedAtMs: nowMs - (i * 1300000),
        presetName: i.isEven ? 'Warm Voice' : 'Air Space',
        syncStatus: 'internet-mock',
      );
    }).toList();
  }

  Future<List<MixerPreset>> fetchPresetSeeds({required int nowMs}) async {
    final usersRes = await http.get(Uri.parse(_usersUrl));
    if (usersRes.statusCode != 200) {
      throw StateError('Unable to fetch preset seeds');
    }
    final users = (jsonDecode(usersRes.body) as List).cast<Map<String, dynamic>>();
    return users.take(5).toList().asMap().entries.map((entry) {
      final i = entry.key;
      final user = entry.value;
      return MixerPreset(
        presetId: 'net_pre_$i',
        uid: 'demo_uid',
        name: '${user['username']} Studio',
        foregroundEq: [1.2, 0.8, 0.1, -0.3, -0.2 + i * 0.2],
        backgroundEq: [-1.4, -0.7, 0.1, 0.9, 1.4],
        foregroundVolume: 0.88,
        backgroundVolume: 0.38 + (i * 0.03),
        masterGain: 0.95,
        balance: i.isEven ? -0.04 : 0.04,
        createdAtMs: nowMs - (i * 6400000),
        updatedAtMs: nowMs - (i * 4200000),
        isPremium: i > 2,
      );
    }).toList();
  }
}
