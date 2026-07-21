import AVFoundation
import Flutter

// Shared AVAudioEngine — both tracks mix into one output (dual engines were silent on device).
// Per track: PlayerNode → EQ → BassBoost → TimePitch → Reverb → TrackMixer → MainMixer → Output
private class TrackEngine {
    let playerNode = AVAudioPlayerNode()
    let eqNode: AVAudioUnitEQ
    let bassNode: AVAudioUnitEQ
    let timePitchNode = AVAudioUnitTimePitch()
    let reverbNode = AVAudioUnitReverb()
    let trackMixer = AVAudioMixerNode()

    weak var engine: AVAudioEngine?
    var isAttached = false

    var audioFile: AVAudioFile?
    var filePath: String?
    var durationFrames: AVAudioFramePosition = 0
    var sampleRate: Double = 44100
    var seekOffsetFrames: AVAudioFramePosition = 0
    var isRunning = false
    var looping = false
    var loopBuffer: AVAudioPCMBuffer?
    var playbackFormat: AVAudioFormat?

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
        eqNode.globalGain = 0

        bassNode = AVAudioUnitEQ(numberOfBands: 1)
        if let lowShelf = bassNode.bands.first {
            lowShelf.filterType = .lowShelf
            lowShelf.frequency = 80
            lowShelf.gain = 0
            lowShelf.bypass = false
        }

        reverbNode.loadFactoryPreset(.largeHall2)
        reverbNode.wetDryMix = 0
        trackMixer.outputVolume = 1.0
    }

    func attach(to engine: AVAudioEngine) {
        guard !isAttached else { return }
        self.engine = engine
        engine.attach(playerNode)
        engine.attach(eqNode)
        engine.attach(bassNode)
        engine.attach(timePitchNode)
        engine.attach(reverbNode)
        engine.attach(trackMixer)
        isAttached = true
    }

    func reconnectGraph(format: AVAudioFormat) {
        guard let engine = engine else { return }
        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeInput(eqNode)
        engine.disconnectNodeOutput(eqNode)
        engine.disconnectNodeInput(bassNode)
        engine.disconnectNodeOutput(bassNode)
        engine.disconnectNodeInput(timePitchNode)
        engine.disconnectNodeOutput(timePitchNode)
        engine.disconnectNodeInput(reverbNode)
        engine.disconnectNodeOutput(reverbNode)
        engine.disconnectNodeInput(trackMixer)

        engine.connect(playerNode, to: eqNode, format: format)
        engine.connect(eqNode, to: bassNode, format: format)
        engine.connect(bassNode, to: timePitchNode, format: format)
        engine.connect(timePitchNode, to: reverbNode, format: format)
        engine.connect(reverbNode, to: trackMixer, format: format)
        engine.connect(trackMixer, to: engine.mainMixerNode, format: nil)
        playbackFormat = format
    }

    func setVolume(_ volume: Float) {
        trackMixer.outputVolume = volume
    }

    func currentPositionMs() -> Int {
        if isRunning,
           let lastRenderTime = playerNode.lastRenderTime,
           lastRenderTime.isSampleTimeValid,
           let playerTime = playerNode.playerTime(forNodeTime: lastRenderTime),
           playerTime.sampleTime >= 0 {
            var frames = seekOffsetFrames + playerTime.sampleTime
            if looping, durationFrames > 0 {
                frames %= durationFrames
            } else {
                frames = min(frames, durationFrames)
            }
            return Int(Double(frames) / sampleRate * 1000)
        }
        return Int(Double(seekOffsetFrames) / sampleRate * 1000)
    }

    func stopScheduling() {
        if playerNode.isPlaying { playerNode.stop() }
        isRunning = false
    }

    func stopAndDetach() {
        stopScheduling()
        guard let engine = engine, isAttached else { return }
        engine.disconnectNodeInput(trackMixer)
        engine.disconnectNodeOutput(reverbNode)
        engine.disconnectNodeOutput(timePitchNode)
        engine.disconnectNodeOutput(bassNode)
        engine.disconnectNodeOutput(eqNode)
        engine.disconnectNodeOutput(playerNode)
        engine.detach(playerNode)
        engine.detach(eqNode)
        engine.detach(bassNode)
        engine.detach(timePitchNode)
        engine.detach(reverbNode)
        engine.detach(trackMixer)
        isAttached = false
        self.engine = nil
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

    private let engine = AVAudioEngine()
    private var tracks: [String: TrackEngine] = [:]
    private var interruptionObserver: NSObjectProtocol?
    /// Mirrors Flutter "Play alongside other apps" — keep session mixable and
    /// do not pause native engines when other media apps take the route.
    private var mixWithOthers = false

    override init() {
        super.init()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleSessionInterruption(notification)
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    private func handleSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeRaw = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
        switch type {
        case .began:
            // Companion mode: keep ambient audio running with YouTube / Audible / etc.
            if mixWithOthers { return }
            for track in tracks.values {
                pauseTrackSilently(track)
            }
        case .ended:
            // Dart owns resume after camera/calls — never auto-play here.
            break
        @unknown default:
            break
        }
    }

    private func pauseTrackSilently(_ track: TrackEngine) {
        if track.playerNode.isPlaying {
            if let lastRenderTime = track.playerNode.lastRenderTime,
               let playerTime = track.playerNode.playerTime(forNodeTime: lastRenderTime),
               playerTime.sampleTime > 0 {
                track.seekOffsetFrames += playerTime.sampleTime
                track.seekOffsetFrames = min(track.seekOffsetFrames, track.durationFrames)
            }
            track.playerNode.stop()
        }
        track.isRunning = false
    }

    private func makeLoopBuffer(from file: AVAudioFile) throws -> AVAudioPCMBuffer {
        let format = file.processingFormat
        guard file.length > 0,
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(file.length)) else {
            throw NSError(domain: "AudioEffects", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not allocate loop buffer",
            ])
        }
        file.framePosition = 0
        try file.read(into: buffer)
        return buffer
    }

    private func prepareEngineIfNeeded() throws {
        engine.mainMixerNode.outputVolume = 1.0
        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let trackId = args["trackId"] as? String ?? ""

        switch call.method {
        case "openEffects":
            openEffects(trackId: trackId, result: result)
        case "setTrackFile":
            let path = args["path"] as? String ?? ""
            setTrackFile(
                trackId: trackId,
                path: path,
                looping: args["looping"] as? Bool ?? false,
                result: result
            )
        case "playTrack":
            playTrack(trackId: trackId, result: result)
        case "pauseTrack":
            pauseTrack(trackId: trackId, result: result)
        case "seekTrack":
            let ms = args["positionMs"] as? Int ?? 0
            seekTrack(trackId: trackId, positionMs: ms, result: result)
        case "getPosition":
            result(tracks[trackId]?.currentPositionMs() ?? 0)
        case "setVolume":
            let vol = args["volume"] as? Double ?? 1.0
            tracks[trackId]?.setVolume(Float(vol))
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
        case "setMixWithOthers":
            mixWithOthers = args["enabled"] as? Bool ?? false
            configureAudioSession()
            result(nil)
        case "closeEffects":
            closeEffects(trackId: trackId, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func openEffects(trackId: String, result: FlutterResult) {
        if tracks[trackId] == nil {
            let track = TrackEngine()
            track.attach(to: engine)
            tracks[trackId] = track
        }
        configureAudioSession()
        result(5)
    }

    private func setTrackFile(trackId: String, path: String, looping: Bool, result: FlutterResult) {
        guard let track = tracks[trackId] else {
            result(FlutterError(code: "NO_TRACK", message: "Track not opened", details: nil))
            return
        }
        track.stopScheduling()

        let url: URL
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            guard let u = URL(string: path) else {
                result(FlutterError(code: "BAD_URL", message: "Invalid URL", details: nil))
                return
            }
            url = u
        } else {
            url = URL(fileURLWithPath: path)
        }

        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            track.audioFile = file
            track.filePath = path
            track.durationFrames = file.length
            track.sampleRate = format.sampleRate
            track.seekOffsetFrames = 0
            track.looping = looping
            track.loopBuffer = nil

            let wasRunning = engine.isRunning
            if wasRunning { engine.stop() }
            track.reconnectGraph(format: format)
            if looping, file.length > 0 {
                track.loopBuffer = try makeLoopBuffer(from: file)
            }
            if wasRunning {
                try prepareEngineIfNeeded()
            }
            result(nil)
        } catch {
            result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func playTrack(trackId: String, result: FlutterResult) {
        guard let track = tracks[trackId], let file = track.audioFile else {
            result(FlutterError(code: "NO_FILE", message: "No audio loaded", details: nil))
            return
        }
        do {
            configureAudioSession()
            if track.playerNode.isPlaying {
                track.playerNode.stop()
            }
            try prepareEngineIfNeeded()
            if track.looping, let buffer = track.loopBuffer {
                track.playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            } else {
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
            if let lastRenderTime = track.playerNode.lastRenderTime,
               let playerTime = track.playerNode.playerTime(forNodeTime: lastRenderTime),
               playerTime.sampleTime > 0 {
                track.seekOffsetFrames += playerTime.sampleTime
                track.seekOffsetFrames = min(track.seekOffsetFrames, track.durationFrames)
            }
            track.playerNode.stop()
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

    private func setEqBands(trackId: String, levels: [Double], result: FlutterResult) {
        guard let track = tracks[trackId] else { result(nil); return }
        for (i, band) in track.eqNode.bands.enumerated() where i < levels.count {
            // Slightly stronger mapping — iOS parametric EQ can sound subtle on device.
            let boosted = Float(levels[i]) * 1.2
            band.gain = boosted.clamped(to: -12...12)
        }
        result(nil)
    }

    private func setBassBoost(trackId: String, strength: Double, result: FlutterResult) {
        guard let track = tracks[trackId] else { result(nil); return }
        if let lowShelf = track.bassNode.bands.first {
            let curved = pow(Float(strength.clamped(to: 0...1)), 0.55)
            lowShelf.gain = (curved * 12.0).clamped(to: 0...12)
        }
        result(nil)
    }

    private func setVirtualizer(trackId: String, strength: Double, result: FlutterResult) {
        guard let track = tracks[trackId] else { result(nil); return }
        let curved = pow(Float(strength.clamped(to: 0...1)), 0.55)
        track.reverbNode.wetDryMix = (curved * 85.0).clamped(to: 0...100)
        result(nil)
    }

    private func setLoudness(trackId: String, gainDb: Double, result: FlutterResult) {
        guard let track = tracks[trackId] else { result(nil); return }
        track.eqNode.globalGain = Float(gainDb).clamped(to: 0...12)
        result(nil)
    }

    private func closeEffects(trackId: String, result: FlutterResult) {
        tracks[trackId]?.stopAndDetach()
        tracks.removeValue(forKey: trackId)
        if tracks.isEmpty, engine.isRunning {
            engine.stop()
        }
        result(nil)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        let options: AVAudioSession.CategoryOptions = mixWithOthers ? [.mixWithOthers] : []
        try? session.setCategory(.playback, mode: .default, options: options)
        try? session.setActive(true, options: [])
        engine.mainMixerNode.outputVolume = 1.0
    }

    func releaseAll() {
        for track in tracks.values { track.stopAndDetach() }
        tracks.removeAll()
        if engine.isRunning { engine.stop() }
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
