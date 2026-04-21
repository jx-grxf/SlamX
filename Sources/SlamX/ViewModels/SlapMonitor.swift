import Foundation
import Observation
import SlamXCore

enum SensorAvailability: Equatable {
    case checking
    case detected
    case unsupported

    var canMonitor: Bool {
        self == .detected
    }

    var title: String {
        switch self {
        case .checking:
            "Checking accelerometer"
        case .detected:
            "Accelerometer detected"
        case .unsupported:
            "Your Mac is not supported"
        }
    }

    var compactTitle: String {
        switch self {
        case .checking:
            "Checking"
        case .detected:
            "Detected"
        case .unsupported:
            "Unsupported"
        }
    }

    var systemImage: String {
        switch self {
        case .checking:
            "waveform.path.ecg"
        case .detected:
            "checkmark.seal.fill"
        case .unsupported:
            "exclamationmark.triangle.fill"
        }
    }
}

@MainActor
@Observable
final class SlapMonitor {
    static let thresholdRange = 0.05...1.0
    static let thresholdStep = 0.05

    private enum PreferenceKey {
        static let bonusSoundsEnabled = "bonusSoundsEnabled"
        static let selectedSound = "selectedSound"
        static let selectedCustomSound = "selectedCustomSound"
        static let customAudioDisclaimerAccepted = "customAudioDisclaimerAccepted"
    }

    private enum Timing {
        static let minimumAvailabilityCheckDuration: Duration = .seconds(3)
    }

    var isMonitoring = false
    var isMuted = false
    var status = "Idle"
    var sensorAvailability: SensorAvailability = .checking
    var isSensorUnsupportedTestMode = false {
        didSet {
            refreshSensorAvailability()
        }
    }
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
    var calibrationImpactPeak = 0.0
    var samplesPerSecond = 0
    var rawReport = ""
    var lastEventDescription = "No impact detected yet"
    var isBonusSoundsEnabled = false {
        didSet {
            userDefaults.set(isBonusSoundsEnabled, forKey: PreferenceKey.bonusSoundsEnabled)

            if !isBonusSoundsEnabled && selectedSound.isBonus {
                selectedSound = .whip
            }
        }
    }
    var selectedSound: SlapSound = .whip {
        didSet {
            if selectedSound.isBonus && !isBonusSoundsEnabled {
                selectedSound = oldValue.isBonus ? .whip : oldValue
                return
            }

            userDefaults.set(selectedSound.rawValue, forKey: PreferenceKey.selectedSound)
        }
    }
    var selectedCustomSoundID: String? {
        didSet {
            if let selectedCustomSoundID {
                userDefaults.set(selectedCustomSoundID, forKey: PreferenceKey.selectedCustomSound)
            } else {
                userDefaults.removeObject(forKey: PreferenceKey.selectedCustomSound)
            }
        }
    }
    var hasAcceptedCustomAudioDisclaimer = false {
        didSet {
            userDefaults.set(hasAcceptedCustomAudioDisclaimer, forKey: PreferenceKey.customAudioDisclaimerAccepted)
        }
    }

    @ObservationIgnored private let sensor: MotionSensorStreaming = MacBookMotionSensor()
    @ObservationIgnored private let soundPlayer = SoundPlayer()
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private var detector = SlapDetector()
    @ObservationIgnored private var sampleWindow: [TimeInterval] = []
    @ObservationIgnored private var previousSample: MotionSample?
    @ObservationIgnored private var monitoringActivity: NSObjectProtocol?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isBonusSoundsEnabled = userDefaults.bool(forKey: PreferenceKey.bonusSoundsEnabled)
        hasAcceptedCustomAudioDisclaimer = userDefaults.bool(forKey: PreferenceKey.customAudioDisclaimerAccepted)

        if let storedSound = userDefaults.string(forKey: PreferenceKey.selectedSound),
           let sound = SlapSound(rawValue: storedSound),
           isBonusSoundsEnabled || !sound.isBonus {
            selectedSound = sound
        }

        if let storedCustomSoundID = userDefaults.string(forKey: PreferenceKey.selectedCustomSound),
           soundPlayer.customSoundExists(id: storedCustomSoundID) {
            selectedCustomSoundID = storedCustomSoundID
        }

        refreshSensorAvailability()
    }

    var availableSounds: [SlapSound] {
        SlapSound.availableSounds(includeBonus: isBonusSoundsEnabled)
    }

    var soundStatus: String {
        if isMuted {
            return "Muted"
        }

        let title = selectedSoundTitle
        return soundPlayer.isReady(for: selectedSound, customSoundID: selectedCustomSoundID) ? "\(title) ready" : "\(title) missing"
    }

    var selectedSoundTitle: String {
        guard let selectedCustomSoundID else {
            return selectedSound.title
        }

        return customSounds().first { $0.id == selectedCustomSoundID }?.title ?? selectedSound.title
    }

    var selectedSoundSymbol: String {
        if isMuted {
            return "speaker.slash.fill"
        }

        return selectedCustomSoundID == nil ? selectedSound.symbol : "music.note"
    }

    var sensorName: String {
        "Apple SPU Accelerometer"
    }

    var canMonitor: Bool {
        sensorAvailability.canMonitor
    }

    var monitoringActionTitle: String {
        isMonitoring ? "Stop Monitoring" : "Start Monitoring"
    }

    var monitoringActionSymbol: String {
        isMonitoring ? "stop.fill" : "play.fill"
    }

    var muteActionTitle: String {
        isMuted ? "Unmute Sounds" : "Mute Sounds"
    }

    var muteActionSymbol: String {
        isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill"
    }

    var sensorStatusTitle: String {
        sensorAvailability.compactTitle
    }

    var unsupportedSensorExplanation: String {
        if isSensorUnsupportedTestMode {
            return "Test mode is simulating a Mac without the Apple SPU accelerometer. This is only for testing the unsupported-device flow."
        }

        return "SlamX could not find an accessible Apple SPU accelerometer. This Mac does not expose the motion sensor SlamX needs."
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

    func applyPersistedValues(threshold persistedThreshold: Double, slapCount persistedSlapCount: Int) {
        threshold = Self.clampedThreshold(persistedThreshold)
        slapCount = max(0, persistedSlapCount)
    }

    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            Task {
                await startMonitoring()
            }
        }
    }

    func startMonitoring() async {
        guard !isMonitoring else {
            status = "Listening"
            return
        }

        startAccelerometerMonitoring()
    }

    func checkSensorAvailability() async {
        sensorAvailability = .checking
        status = "Checking sensor"

        do {
            try await Task.sleep(for: Timing.minimumAvailabilityCheckDuration)
        } catch {
            return
        }

        refreshSensorAvailability()
    }

    func refreshSensorAvailability() {
        guard !isMonitoring else {
            sensorAvailability = .detected
            return
        }

        sensorAvailability = isSensorUnsupportedTestMode || !MacBookMotionSensor.isAccelerometerAvailable() ? .unsupported : .detected
        status = sensorAvailability.canMonitor ? "Ready" : "Unsupported Mac"
    }

    func stopMonitoring() {
        sensor.stop()
        endMonitoringActivity()
        status = "Stopped"
        isMonitoring = false
    }

    func resetCounter() {
        slapCount = 0
        peakImpact = 0
        currentImpact = 0
        calibrationImpactPeak = 0
        lastEventDescription = "Counter reset"
        detector.reset()
    }

    func resetCalibrationImpactPeak() {
        calibrationImpactPeak = 0
    }

    func playTestSound() {
        guard playSelectedSound() else {
            lastEventDescription = "\(selectedSoundTitle) sound test muted"
            return
        }

        lastEventDescription = "\(selectedSoundTitle) sound test played"
    }

    func toggleMute() {
        isMuted.toggle()
        status = isMuted ? "Muted" : (isMonitoring ? "Listening" : "Ready")
        lastEventDescription = isMuted ? "Sounds muted" : "Sounds unmuted"
    }

    func selectStandardSound(_ sound: SlapSound) {
        selectedCustomSoundID = nil
        selectedSound = sound
    }

    func selectCustomSound(id: String) {
        guard soundPlayer.customSoundExists(id: id) else {
            return
        }

        selectedCustomSoundID = id
    }

    func customSounds() -> [CustomSlapSound] {
        soundPlayer.customSounds()
    }

    func importCustomSound(from url: URL) throws {
        let importedSound = try soundPlayer.importCustomSound(from: url)
        selectedCustomSoundID = importedSound.id
    }

    func removeCustomSound(id: String) throws {
        try soundPlayer.removeCustomSound(id: id)

        if selectedCustomSoundID == id {
            selectedCustomSoundID = nil
        }
    }

    static func clampedThreshold(_ value: Double) -> Double {
        min(max(value, thresholdRange.lowerBound), thresholdRange.upperBound)
    }

    static func steppedThreshold(_ value: Double) -> Double {
        let clampedValue = clampedThreshold(value)
        let steps = (clampedValue / thresholdStep).rounded()
        return clampedThreshold(steps * thresholdStep)
    }

    private func startAccelerometerMonitoring() {
        refreshSensorAvailability()

        guard canMonitor else {
            status = "Unsupported Mac"
            return
        }

        do {
            try sensor.start { [weak self] sample in
                Task { @MainActor in
                    self?.handle(sample)
                }
            }
            detector.reset()
            previousSample = nil
            sampleWindow.removeAll()
            beginMonitoringActivity()
            status = "Listening"
            isMonitoring = true
        } catch {
            endMonitoringActivity()
            status = error.localizedDescription
            isMonitoring = false
        }
    }

    private func handle(_ sample: MotionSample) {
        currentSample = sample
        rawReport = MotionReportParser.rawDescription(for: sample.rawReport)

        if let previousSample {
            currentImpact = sample.acceleration.distance(to: previousSample.acceleration)
            peakImpact = max(peakImpact, currentImpact)
            calibrationImpactPeak = max(calibrationImpactPeak, currentImpact)
        }
        previousSample = sample

        updateSampleRate(now: sample.timestamp)

        guard let event = detector.process(sample) else {
            return
        }

        slapCount += 1

        if playSelectedSound() {
            lastEventDescription = "\(selectedSoundTitle) \(slapCount) at \(event.impact.formatted(.number.precision(.fractionLength(2)))) g"
        } else {
            lastEventDescription = "\(selectedSoundTitle) \(slapCount) muted at \(event.impact.formatted(.number.precision(.fractionLength(2)))) g"
        }
    }

    private func updateSampleRate(now: TimeInterval) {
        sampleWindow.append(now)
        sampleWindow.removeAll { now - $0 > 1.0 }
        samplesPerSecond = sampleWindow.count
    }

    private func playSelectedSound() -> Bool {
        guard !isMuted else {
            return false
        }

        soundPlayer.play(selectedSound, customSoundID: selectedCustomSoundID)
        return true
    }

    private func beginMonitoringActivity() {
        guard monitoringActivity == nil else {
            return
        }

        monitoringActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "Keep SlamX listening for local impact events."
        )
    }

    private func endMonitoringActivity() {
        guard let monitoringActivity else {
            return
        }

        ProcessInfo.processInfo.endActivity(monitoringActivity)
        self.monitoringActivity = nil
    }
}
