import Foundation
import Observation
import SlamDihCore

@MainActor
@Observable
final class SlapMonitor {
    var isMonitoring = false
    var status = "Idle"
    var sensorName = "Apple SPU Accelerometer"
    var slapCount = 0
    var threshold = 0.75 {
        didSet {
            detector.threshold = threshold
        }
    }
    var currentSample = MotionSample(
        timestamp: 0,
        acceleration: MotionVector(x: 0, y: 0, z: 0),
        rawReport: []
    )
    var currentImpact = 0.0
    var peakImpact = 0.0
    var samplesPerSecond = 0
    var rawReport = ""
    var lastEventDescription = "No slap detected yet"
    var selectedSound: SlapSound = .slap

    @ObservationIgnored private let sensor = MacBookMotionSensor()
    @ObservationIgnored private let soundPlayer = SoundPlayer()
    @ObservationIgnored private var detector = SlapDetector()
    @ObservationIgnored private var sampleWindow: [TimeInterval] = []
    @ObservationIgnored private var previousSample: MotionSample?

    var soundStatus: String {
        soundPlayer.isReady(for: selectedSound) ? "\(selectedSound.title) ready" : "\(selectedSound.title) missing"
    }

    var xAxis: Double {
        currentSample.acceleration.x
    }

    var yAxis: Double {
        currentSample.acceleration.y
    }

    var zAxis: Double {
        currentSample.acceleration.z
    }

    var magnitude: Double {
        currentSample.acceleration.magnitude
    }

    func toggleMonitoring() {
        isMonitoring ? stopMonitoring() : startMonitoring()
    }

    func startMonitoring() {
        do {
            try sensor.start { [weak self] sample in
                Task { @MainActor in
                    self?.handle(sample)
                }
            }
            detector.reset()
            previousSample = nil
            sampleWindow.removeAll()
            status = "Listening"
            isMonitoring = true
        } catch {
            status = error.localizedDescription
            isMonitoring = false
        }
    }

    func stopMonitoring() {
        sensor.stop()
        status = "Stopped"
        isMonitoring = false
    }

    func resetCounter() {
        slapCount = 0
        peakImpact = 0
        currentImpact = 0
        lastEventDescription = "Counter reset"
        detector.reset()
    }

    func playTestSound() {
        soundPlayer.play(selectedSound)
        lastEventDescription = "\(selectedSound.title) sound test played"
    }

    private func handle(_ sample: MotionSample) {
        currentSample = sample
        rawReport = MotionReportParser.rawDescription(for: sample.rawReport)

        if let previousSample {
            currentImpact = sample.acceleration.distance(to: previousSample.acceleration)
            peakImpact = max(peakImpact, currentImpact)
        }
        previousSample = sample

        updateSampleRate(now: sample.timestamp)

        if let event = detector.process(sample) {
            slapCount += 1
            soundPlayer.play(selectedSound)
            lastEventDescription = "\(selectedSound.title) \(slapCount) at \(event.impact.formatted(.number.precision(.fractionLength(2)))) g"
        }
    }

    private func updateSampleRate(now: TimeInterval) {
        sampleWindow.append(now)
        sampleWindow.removeAll { now - $0 > 1.0 }
        samplesPerSecond = sampleWindow.count
    }
}
