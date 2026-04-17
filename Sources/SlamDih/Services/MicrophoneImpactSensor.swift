import AVFoundation
import Foundation

struct MicrophoneImpactSample: Sendable {
    let timestamp: TimeInterval
    let impact: Double
}

enum MicrophoneImpactSensorError: LocalizedError {
    case permissionDenied
    case inputUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Microphone access was denied."
        case .inputUnavailable:
            "No microphone input was available."
        }
    }
}

final class MicrophoneImpactSensor {
    typealias SampleHandler = @Sendable (MicrophoneImpactSample) -> Void

    private let bufferSize: AVAudioFrameCount = 512
    private let minimumImpactGap: TimeInterval = 0.28
    private var engine: AVAudioEngine?
    private var noiseFloor = 0.006
    private var lastImpactTime = Date.distantPast.timeIntervalSinceReferenceDate

    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func start(sampleHandler: @escaping SampleHandler) throws {
        stop()

        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            throw MicrophoneImpactSensorError.permissionDenied
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.channelCount > 0 else {
            throw MicrophoneImpactSensorError.inputUnavailable
        }

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            guard let sample = self?.impactSample(from: buffer) else {
                return
            }

            sampleHandler(sample)
        }

        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    func stop() {
        guard let engine else {
            return
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        noiseFloor = 0.006
        lastImpactTime = Date.distantPast.timeIntervalSinceReferenceDate
    }

    private func impactSample(from buffer: AVAudioPCMBuffer) -> MicrophoneImpactSample? {
        guard let channelData = buffer.floatChannelData?[0], buffer.frameLength > 0 else {
            return nil
        }

        let frameCount = Int(buffer.frameLength)
        var squaredSum = 0.0
        var peak = 0.0

        for index in 0..<frameCount {
            let value = Double(abs(channelData[index]))
            peak = max(peak, value)
            squaredSum += value * value
        }

        let rms = sqrt(squaredSum / Double(frameCount))
        let clampedRMS = min(rms, 0.08)
        noiseFloor = (noiseFloor * 0.96) + (clampedRMS * 0.04)

        let now = Date.timeIntervalSinceReferenceDate
        let crestFactor = peak / max(rms, 0.0001)
        let peakThreshold = max(0.16, noiseFloor * 5.5)
        let energyThreshold = max(0.03, noiseFloor * 2.0)

        guard peak >= peakThreshold,
              rms >= energyThreshold,
              crestFactor >= 2.45,
              now - lastImpactTime >= minimumImpactGap else {
            return nil
        }

        lastImpactTime = now
        let impact = min(1.5, max(0, (peak - noiseFloor) * 8.0))
        return MicrophoneImpactSample(timestamp: now, impact: impact)
    }
}
