import AVFoundation
import Flutter

// Per-track AVAudioEngine pipeline:
//   PlayerNode → EQ (5-band + globalGain) → BassBoost (low-shelf) → TimePitch → Reverb → Mixer → Output
//
// Each effect owns a distinct node/property so they compose independently and
// never overwrite one another — matching Android's separate AudioEffect objects
// (Equalizer / BassBoost / Virtualizer / LoudnessEnhancer):
//   • setEqBands    → eqNode.bands[i].gain   (user 5-band EQ)
//   • setLoudness   → eqNode.globalGain      (overall perceptual gain, separate from bands)
//   • setBassBoost  → bassNode.bands[0].gain (dedicated low-shelf filter)
//   • setVirtualizer→ reverbNode.wetDryMix   (spatial widening approximation)
private class TrackEngine {
    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    let eqNode: AVAudioUnitEQ                   // 5-band parametric (user EQ) + globalGain (loudness)
    let bassNode: AVAudioUnitEQ                 // single low-shelf band (bass boost)
    let timePitchNode = AVAudioUnitTimePitch()  // playback speed
    let reverbNode = AVAudioUnitReverb()        // virtualizer approximation

    var audioFile: AVAudioFile?
    var filePath: String?
    var durationFrames: AVAudioFramePosition = 0
    var sampleRate: Double = 44100
    var seekOffsetFrames: AVAudioFramePosition = 0
    var startHostTime: UInt64 = 0
    var isRunning = false

    // Looping (background ambient): the whole clip is preloaded into a buffer and
    // scheduled with the `.loops` option so it repeats seamlessly.
    var looping = false
    var loopBuffer: AVAudioPCMBuffer?

    init() {
        eqNode = AVAudioUnitEQ(numberOfBands: 5)
        let frequencies: [Float] = [60, 230, 910, 3600, 14000]
        for (i, band) in eqNode.bands.enumerated() {
            band.filterType = .parametric
            band.frequency = frequencies[i]
            band.bandwidth = 1.0
            band.gain = 0
            band.bypass = false
        }
        eqNode.globalGain = 0 // loudness; independent of per-band gains

        // Dedicated low-shelf band for bass boost so it never collides with the EQ.
        bassNode = AVAudioUnitEQ(numberOfBands: 1)
        if let lowShelf = bassNode.bands.first {
            lowShelf.filterType = .lowShelf
            lowShelf.frequency = 80
            lowShelf.gain = 0
            lowShelf.bypass = false
        }

        reverbNode.loadFactoryPreset(.mediumHall)
        reverbNode.wetDryMix = 0

        engine.attach(playerNode)
        engine.attach(eqNode)
        engine.attach(bassNode)
        engine.attach(timePitchNode)
        engine.attach(reverbNode)

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(playerNode, to: eqNode, format: format)
        engine.connect(eqNode, to: bassNode, format: format)
        engine.connect(bassNode, to: timePitchNode, format: format)
        engine.connect(timePitchNode, to: reverbNode, format: format)
        engine.connect(reverbNode, to: engine.mainMixerNode, format: format)
    }

    func currentPositionMs() -> Int {
        if isRunning,
           let lastRenderTime = playerNode.lastRenderTime,
           lastRenderTime.isSampleTimeValid,
           let playerTime = playerNode.playerTime(forNodeTime: lastRenderTime),
           playerTime.sampleTime >= 0 {
            var frames = seekOffsetFrames + playerTime.sampleTime
            // A looping track wraps within the clip; a one-shot clamps to the end.
            if looping, durationFrames > 0 {
                frames %= durationFrames
            } else {
                frames = min(frames, durationFrames)
            }
            return Int(Double(frames) / sampleRate * 1000)
        }
        return Int(Double(seekOffsetFrames) / sampleRate * 1000)
    }

    func stop() {
        if playerNode.isPlaying { playerNode.stop() }
        if engine.isRunning { engine.stop() }
        isRunning = false
    }
}

class AudioEffectsPlugin: NSObject, FlutterPlugin {

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.codetivelab.soundAxis/audio_effects",
            binaryMessenger: registrar.messenger()
        )
        let instance = AudioEffectsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private var tracks: [String: TrackEngine] = [:]

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let trackId = args["trackId"] as? String ?? ""

        switch call.method {
        case "openEffects":
            openEffects(trackId: trackId, result: result)

        case "setTrackFile":
            let path = args["path"] as? String ?? ""
            setTrackFile(trackId: trackId, path: path, looping: args["looping"] as? Bool ?? false, result: result)

        case "playTrack":
            playTrack(trackId: trackId, result: result)

        case "pauseTrack":
            pauseTrack(trackId: trackId, result: result)

        case "seekTrack":
            let ms = args["positionMs"] as? Int ?? 0
            seekTrack(trackId: trackId, positionMs: ms, result: result)

        case "getPosition":
            let ms = tracks[trackId]?.currentPositionMs() ?? 0
            result(ms)

        case "setVolume":
            let vol = args["volume"] as? Double ?? 1.0
            tracks[trackId]?.engine.mainMixerNode.outputVolume = Float(vol)
            result(nil)

        case "setSpeed":
            let speed = args["speed"] as? Double ?? 1.0
            tracks[trackId]?.timePitchNode.rate = Float(speed)
            result(nil)

        case "setEqBands":
            setEqBands(trackId: trackId, levels: args["levels"] as? [Double] ?? [], result: result)

        case "setBassBoost":
            setBassBoost(trackId: trackId, strength: args["strength"] as? Double ?? 0, result: result)

        case "setVirtualizer":
            setVirtualizer(trackId: trackId, strength: args["strength"] as? Double ?? 0, result: result)

        case "setLoudness":
            setLoudness(trackId: trackId, gainDb: args["gainDb"] as? Double ?? 0, result: result)

        case "setEnabled":
            result(nil)

        case "closeEffects":
            closeEffects(trackId: trackId, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ── Open ────────────────────────────────────────────────────────────────────

    private func openEffects(trackId: String, result: FlutterResult) {
        if tracks[trackId] == nil {
            tracks[trackId] = TrackEngine()
        }
        configureAudioSession()
        result(5) // 5-band EQ
    }

    // ── File / playback ─────────────────────────────────────────────────────────

    private func setTrackFile(trackId: String, path: String, looping: Bool, result: FlutterResult) {
        guard let track = tracks[trackId] else { result(nil); return }
        track.stop()
        let url: URL
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            guard let u = URL(string: path) else { result(nil); return }
            url = u
        } else {
            url = URL(fileURLWithPath: path)
        }
        do {
            let file = try AVAudioFile(forReading: url)
            track.audioFile = file
            track.filePath = path
            track.durationFrames = file.length
            track.sampleRate = file.processingFormat.sampleRate
            track.seekOffsetFrames = 0
            track.looping = looping
            track.loopBuffer = nil
            // Preload the whole clip into a PCM buffer so it can be scheduled
            // with the `.loops` option for seamless, gapless repetition.
            if looping, file.length > 0,
               let buffer = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: AVAudioFrameCount(file.length)) {
                file.framePosition = 0
                try file.read(into: buffer)
                track.loopBuffer = buffer
            }
            result(nil)
        } catch {
            result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func playTrack(trackId: String, result: FlutterResult) {
        guard let track = tracks[trackId], let file = track.audioFile else {
            result(nil); return
        }
        do {
            if !track.engine.isRunning {
                try track.engine.start()
            }
            if track.looping, let buffer = track.loopBuffer {
                // Looping clip: schedule the preloaded buffer to repeat forever.
                track.playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            } else {
                // One-shot: stream the file from the saved seek offset.
                file.framePosition = track.seekOffsetFrames
                track.playerNode.scheduleFile(file, at: nil, completionHandler: nil)
            }
            track.playerNode.play()
            track.isRunning = true
            result(nil)
        } catch {
            result(FlutterError(code: "PLAY_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func pauseTrack(trackId: String, result: FlutterResult) {
        guard let track = tracks[trackId] else { result(nil); return }
        if track.playerNode.isPlaying {
            // Capture frame position before stopping.
            if let lastRenderTime = track.playerNode.lastRenderTime,
               let playerTime = track.playerNode.playerTime(forNodeTime: lastRenderTime),
               playerTime.sampleTime > 0 {
                track.seekOffsetFrames += playerTime.sampleTime
                // Clamp to file length.
                track.seekOffsetFrames = min(track.seekOffsetFrames, track.durationFrames)
            }
            track.playerNode.stop() // stop clears the scheduled file; pause is not reliable here
        }
        track.isRunning = false
        result(nil)
    }

    private func seekTrack(trackId: String, positionMs: Int, result: FlutterResult) {
        guard let track = tracks[trackId] else { result(nil); return }
        let wasPlaying = track.playerNode.isPlaying || track.isRunning
        if track.playerNode.isPlaying { track.playerNode.stop() }

        let targetFrame = AVAudioFramePosition(Double(positionMs) / 1000.0 * track.sampleRate)
        track.seekOffsetFrames = max(0, min(targetFrame, max(0, track.durationFrames - 1)))

        if wasPlaying {
            playTrack(trackId: trackId, result: result)
        } else {
            result(nil)
        }
    }

    // ── Effects ─────────────────────────────────────────────────────────────────

    private func setEqBands(trackId: String, levels: [Double], result: FlutterResult) {
        guard let track = tracks[trackId] else { result(nil); return }
        for (i, band) in track.eqNode.bands.enumerated() where i < levels.count {
            band.gain = Float(levels[i]).clamped(to: -12...12)
        }
        result(nil)
    }

    private func setBassBoost(trackId: String, strength: Double, result: FlutterResult) {
        guard let track = tracks[trackId] else { result(nil); return }
        // Dedicated low-shelf band — independent of the user EQ. 0–1 maps to 0–12 dB.
        if let lowShelf = track.bassNode.bands.first {
            lowShelf.gain = (Float(strength) * 12.0).clamped(to: 0...12)
        }
        result(nil)
    }

    private func setVirtualizer(trackId: String, strength: Double, result: FlutterResult) {
        guard let track = tracks[trackId] else { result(nil); return }
        track.reverbNode.wetDryMix = Float(strength).clamped(to: 0...1) * 40.0 // 0–40% reverb as 3D approximation
        result(nil)
    }

    private func setLoudness(trackId: String, gainDb: Double, result: FlutterResult) {
        guard let track = tracks[trackId] else { result(nil); return }
        // Overall gain via the EQ node's globalGain — a single property that is
        // independent of the per-band gains, so it never clobbers the user EQ.
        track.eqNode.globalGain = Float(gainDb).clamped(to: 0...12)
        result(nil)
    }

    private func closeEffects(trackId: String, result: FlutterResult) {
        tracks[trackId]?.stop()
        tracks.removeValue(forKey: trackId)
        result(nil)
    }

    // ── Audio session ────────────────────────────────────────────────────────────

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    func releaseAll() {
        for track in tracks.values { track.stop() }
        tracks.removeAll()
    }
}

// Clamp helper for Float
private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
