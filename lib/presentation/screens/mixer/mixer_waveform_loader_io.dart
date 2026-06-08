import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:just_waveform/just_waveform.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Waveform?> loadMixerWaveform(String source) async {
  if (source.isEmpty) return null;
  try {
    late final File audioFile;
    if (source.startsWith('http')) {
      final dir = await getTemporaryDirectory();
      final out = File(
        p.join(dir.path, 'mix_in_${source.hashCode.abs()}.audio'),
      );
      if (!await out.exists()) {
        final r = await http.get(Uri.parse(source));
        if (r.statusCode < 200 || r.statusCode >= 300) return null;
        await out.writeAsBytes(r.bodyBytes);
      }
      audioFile = out;
    } else {
      final f = File(source);
      if (!await f.exists()) return null;
      audioFile = f;
    }

    final dir = await getTemporaryDirectory();
    final waveFile = File(
      p.join(dir.path, 'mix_wave_${source.hashCode.abs()}.wave'),
    );

    if (await waveFile.exists()) {
      try {
        return await JustWaveform.parse(waveFile);
      } catch (_) {
        await waveFile.delete();
      }
    }

    Waveform? result;
    await for (final wp in JustWaveform.extract(
      audioInFile: audioFile,
      waveOutFile: waveFile,
      zoom: const WaveformZoom.samplesPerPixel(4096),
    )) {
      if (wp.waveform != null) {
        result = wp.waveform;
        break;
      }
    }
    return result;
  } catch (_) {
    return null;
  }
}
