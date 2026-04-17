import Foundation
import Observation
import SlamDihCore

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

enum DetectionInputMode: String, CaseIterable, Identifiable {
    case accelerometer
    case microphone

    var id: Self { self }

    var title: String {
        switch self {
        case .accelerometer:
            "Accelerometer"
        case .microphone:
            "Microphone Fallback"
        }
    }

    var settingsTitle: String {
        switch self {
        case .accelerometer:
            "Accelerometer (Recommended)"
        case .microphone:
            "Microphone (Not Recommended)"
        }
    }

    var symbol: String {
        switch self {
        case .accelerometer:
            "waveform.path.ecg"
        case .microphone:
            "mic.fill"
        }
    }
}

@MainActor
@Observable
final class SlapMonitor {
    static let thresholdRange = 0.05...1.0
    static let thresholdStep = 0.05

    private enum PreferenceKey {
        static let nsfwSoundsEnabled = "nsfwSoundsEnabled"
        static let selectedSound = "selectedSound"
        static let selectedCustomSound = "selectedCustomSound"
        static let customAudioDisclaimerAccepted = "customAudioDisclaimerAccepted"
        static let detectionInputMode = "detectionInputMode"
        static let microphoneFallbackNotRecommendedAccepted = "microphoneFallbackNotRecommendedAccepted"
        static let microphoneFallbackPrivacyAccepted = "microphoneFallbackPrivacyAccepted"
        static let microphoneFallbackAccuracyAccepted = "microphoneFallbackAccuracyAccepted"
        static let microphoneFallbackBatteryAccepted = "microphoneFallbackBatteryAccepted"
    }

    private enum Timing {
        static let minimumAvailabilityCheckDuration: Duration = .seconds(3)
    }

    var isMonitoring = false
    var status = "Idle"
    var sensorAvailability: SensorAvailability = .checking
    var isSensorUnsupportedTestMode = false {
        didSet {
            refreshSensorAvailability()
        }
    }
    var detectionInputMode: DetectionInputMode = .accelerometer {
        didSet {
            userDefaults.set(detectionInputMode.rawValue, forKey: PreferenceKey.detectionInputMode)

            if oldValue != detectionInputMode {
                stopMonitoring()
                refreshSensorAvailability()
            }
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
    var samplesPerSecond = 0
    var rawReport = ""
    var lastEventDescription = "No slap detected yet"
    var isNSFWSoundsEnabled = false {
        didSet {
            userDefaults.set(isNSFWSoundsEnabled, forKey: PreferenceKey.nsfwSoundsEnabled)

            if !isNSFWSoundsEnabled && selectedSound.isNSFW {
                selectedSound = .whip
            }
        }
    }
    var selectedSound: SlapSound = .whip {
        didSet {
            if selectedSound.isNSFW && !isNSFWSoundsEnabled {
                selectedSound = oldValue.isNSFW ? .whip : oldValue
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
    var hasAcceptedMicrophoneNotRecommendedWarning = false {
        didSet {
            userDefaults.set(hasAcceptedMicrophoneNotRecommendedWarning, forKey: PreferenceKey.microphoneFallbackNotRecommendedAccepted)
        }
    }
    var hasAcceptedMicrophonePrivacyNotice = false {
        didSet {
            userDefaults.set(hasAcceptedMicrophonePrivacyNotice, forKey: PreferenceKey.microphoneFallbackPrivacyAccepted)
        }
    }
    var hasAcceptedMicrophoneAccuracyWarning = false {
        didSet {
            userDefaults.set(hasAcceptedMicrophoneAccuracyWarning, forKey: PreferenceKey.microphoneFallbackAccuracyAccepted)
        }
    }
    var hasAcceptedMicrophoneBatteryWarning = false {
        didSet {
            userDefaults.set(hasAcceptedMicrophoneBatteryWarning, forKey: PreferenceKey.microphoneFallbackBatteryAccepted)
        }
    }

    @ObservationIgnored private let sensor = MacBookMotionSensor()
    @ObservationIgnored private let microphoneSensor = MicrophoneImpactSensor()
    @ObservationIgnored private let soundPlayer = SoundPlayer()
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private var detector = SlapDetector()
    @ObservationIgnored private var sampleWindow: [TimeInterval] = []
    @ObservationIgnored private var previousSample: MotionSample?
    @ObservationIgnored private var monitoringActivity: NSObjectProtocol?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isNSFWSoundsEnabled = userDefaults.bool(forKey: PreferenceKey.nsfwSoundsEnabled)
        hasAcceptedCustomAudioDisclaimer = userDefaults.bool(forKey: PreferenceKey.customAudioDisclaimerAccepted)
        hasAcceptedMicrophoneNotRecommendedWarning = userDefaults.bool(forKey: PreferenceKey.microphoneFallbackNotRecommendedAccepted)
        hasAcceptedMicrophonePrivacyNotice = userDefaults.bool(forKey: PreferenceKey.microphoneFallbackPrivacyAccepted)
        hasAcceptedMicrophoneAccuracyWarning = userDefaults.bool(forKey: PreferenceKey.microphoneFallbackAccuracyAccepted)
        hasAcceptedMicrophoneBatteryWarning = userDefaults.bool(forKey: PreferenceKey.microphoneFallbackBatteryAccepted)

        if let storedInputMode = userDefaults.string(forKey: PreferenceKey.detectionInputMode),
           let inputMode = DetectionInputMode(rawValue: storedInputMode) {
            detectionInputMode = inputMode
        }

        if let storedSound = userDefaults.string(forKey: PreferenceKey.selectedSound),
           let sound = SlapSound(rawValue: storedSound),
           isNSFWSoundsEnabled || !sound.isNSFW {
            selectedSound = sound
        }

        if let storedCustomSoundID = userDefaults.string(forKey: PreferenceKey.selectedCustomSound),
           soundPlayer.customSoundExists(id: storedCustomSoundID) {
            selectedCustomSoundID = storedCustomSoundID
        }

        refreshSensorAvailability()
    }

    var availableSounds: [SlapSound] {
        SlapSound.availableSounds(includeNSFW: isNSFWSoundsEnabled)
    }

    var soundStatus: String {
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
        selectedCustomSoundID == nil ? selectedSound.symbol : "music.note"
    }

    var sensorName: String {
        switch detectionInputMode {
        case .accelerometer:
            "Apple SPU Accelerometer"
        case .microphone:
            "Microphone Fallback"
        }
    }

    var canMonitor: Bool {
        switch detectionInputMode {
        case .accelerometer:
            sensorAvailability.canMonitor
        case .microphone:
            hasAcceptedMicrophoneFallbackRequirements
        }
    }

    var hasAcceptedMicrophoneFallbackRequirements: Bool {
        hasAcceptedMicrophoneNotRecommendedWarning &&
            hasAcceptedMicrophonePrivacyNotice &&
            hasAcceptedMicrophoneAccuracyWarning &&
            hasAcceptedMicrophoneBatteryWarning
    }

    var unsupportedSensorExplanation: String {
        if isSensorUnsupportedTestMode {
            return "Test mode is simulating a Mac without the Apple SPU accelerometer. This is only for testing the unsupported-device flow."
        }

        return "SlamDih could not find an accessible Apple SPU accelerometer. Some Macs, including MacBook Air M1-style configurations, do not expose the sensor SlamDih needs for the recommended hardware mode."
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

    var monitoringActionTitle: String {
        isMonitoring ? "Stop Monitoring" : "Start Monitoring"
    }

    var monitoringActionSymbol: String {
        isMonitoring ? "stop.fill" : "play.fill"
    }

    var sensorStatusTitle: String {
        switch detectionInputMode {
        case .accelerometer:
            sensorAvailability.compactTitle
        case .microphone:
            hasAcceptedMicrophoneFallbackRequirements ? "Mic Fallback" : "Mic Agreement"
        }
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

        switch detectionInputMode {
        case .accelerometer:
            startAccelerometerMonitoring()
        case .microphone:
            await startMicrophoneMonitoring()
        }
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

    private func startMicrophoneMonitoring() async {
        guard hasAcceptedMicrophoneFallbackRequirements else {
            status = "Microphone agreement required"
            return
        }

        status = "Requesting microphone"

        guard await MicrophoneImpactSensor.requestAccess() else {
            status = "Microphone permission denied"
            return
        }

        do {
            try microphoneSensor.start { [weak self] sample in
                Task { @MainActor in
                    self?.handle(sample)
                }
            }
            detector.reset()
            previousSample = nil
            sampleWindow.removeAll()
            beginMonitoringActivity()
            status = "Listening via microphone"
            isMonitoring = true
        } catch {
            endMonitoringActivity()
            status = error.localizedDescription
            isMonitoring = false
        }
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
            sensorAvailability = detectionInputMode == .accelerometer ? .detected : sensorAvailability
            return
        }

        sensorAvailability = isSensorUnsupportedTestMode || !MacBookMotionSensor.isAccelerometerAvailable() ? .unsupported : .detected

        if detectionInputMode == .microphone {
            status = hasAcceptedMicrophoneFallbackRequirements ? "Microphone fallback ready" : "Microphone agreement required"
        } else {
            status = sensorAvailability.canMonitor ? "Ready" : "Unsupported Mac"
        }
    }

    func stopMonitoring() {
        sensor.stop()
        microphoneSensor.stop()
        endMonitoringActivity()
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
        soundPlayer.play(selectedSound, customSoundID: selectedCustomSoundID)
        lastEventDescription = "\(selectedSoundTitle) sound test played"
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
            soundPlayer.play(selectedSound, customSoundID: selectedCustomSoundID)
            lastEventDescription = "\(selectedSoundTitle) \(slapCount) at \(event.impact.formatted(.number.precision(.fractionLength(2)))) g"
        }
    }

    private func handle(_ sample: MicrophoneImpactSample) {
        currentImpact = sample.impact
        peakImpact = max(peakImpact, currentImpact)
        currentSample = MotionSample(
            timestamp: sample.timestamp,
            acceleration: MotionVector(x: 0, y: 0, z: sample.impact),
            rawReport: []
        )
        rawReport = "Microphone fallback analyzes live input levels only. Audio is not stored."
        updateSampleRate(now: sample.timestamp)

        slapCount += 1
        soundPlayer.play(selectedSound, customSoundID: selectedCustomSoundID)
        lastEventDescription = "\(selectedSoundTitle) \(slapCount) from microphone impact \(sample.impact.formatted(.number.precision(.fractionLength(2))))"
    }

    private func updateSampleRate(now: TimeInterval) {
        sampleWindow.append(now)
        sampleWindow.removeAll { now - $0 > 1.0 }
        samplesPerSecond = sampleWindow.count
    }

    private func beginMonitoringActivity() {
        guard monitoringActivity == nil else {
            return
        }

        monitoringActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "Keep SlamDih listening for local impact events."
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
