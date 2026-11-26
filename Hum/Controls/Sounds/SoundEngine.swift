import AVFoundation

/// Plays Hum's synthesized sounds. The audio engine only runs while a sound is playing,
/// so it costs nothing when sounds are off.
@MainActor
final class SoundEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat?
    private var crackleNode: AVAudioSourceNode?
    private var needleBuffer: AVAudioPCMBuffer?
    private var crackleOn = false
    private var needlePlaying = false

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: SoundSynth.sampleRate, channels: 1)
        guard let format else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func playNeedleDrop(volume: Float = 0.6) {
        guard let buffer = needleBuffer ?? makeNeedleBuffer() else { return }
        needleBuffer = buffer
        guard ensureRunning() else { return }
        player.volume = volume
        needlePlaying = true
        player.scheduleBuffer(buffer, at: nil, options: .interrupts) { [weak self] in
            Task { @MainActor in
                self?.needlePlaying = false
                self?.stopIfIdle()
            }
        }
        player.play()
    }

    func setCrackle(enabled: Bool, volume: Float) {
        if enabled {
            let node = crackleNode ?? makeCrackleNode()
            crackleNode = node
            node?.volume = volume
            if !crackleOn {
                crackleOn = true
                _ = ensureRunning()
            }
        } else if crackleOn {
            crackleOn = false
            crackleNode?.volume = 0
            stopIfIdle()
        }
    }

    private func ensureRunning() -> Bool {
        guard !engine.isRunning else { return true }
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    private func stopIfIdle() {
        if !crackleOn && !needlePlaying && engine.isRunning {
            engine.pause()
        }
    }

    private func makeNeedleBuffer() -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let samples = SoundSynth.needleDrop()
        guard
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
            let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress {
                channel.update(from: base, count: samples.count)
            }
        }
        return buffer
    }

    private func makeCrackleNode() -> AVAudioSourceNode? {
        guard let format else { return nil }
        let box = GeneratorBox()
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for frame in 0..<Int(frameCount) {
                    data[frame] = box.generator.next()
                }
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        return node
    }
}

/// Holds generator state for the real-time render thread (only that thread touches it).
private final class GeneratorBox: @unchecked Sendable {
    var generator = CrackleGenerator()
}
