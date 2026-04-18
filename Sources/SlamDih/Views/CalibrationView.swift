import SwiftUI

struct CalibrationView: View {
    @Bindable var monitor: SlapMonitor
    var onFinish: (() -> Void)? = nil

    @State private var phase: CalibrationPhase = .idle
    @State private var baselinePeak = 0.0
    @State private var lightSlapPeak = 0.0
    @State private var displayedImpact = 0.0
    @State private var phaseStartedAt = Date.distantPast
    @State private var isWaitingForQuietImpact = false
    @State private var quietSampleCount = 0
    @State private var wasMonitoringBeforeCalibration = false
    @State private var impactSamplingTask: Task<Void, Never>?
    @State private var calibrationTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Calibration")
                    .font(.system(size: 38, weight: .bold, design: .rounded))

                wizardPanel
                thresholdPanel
                liveImpactPanel
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.white)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.09),
                    Color(red: 0.10, green: 0.13, blue: 0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .onAppear {
            startImpactSampling()
        }
        .onDisappear {
            cancelCalibration()
            stopImpactSampling()
        }
    }

    private var wizardPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Calibration Wizard", systemImage: phase.symbol)
                    .font(.headline)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(phase.tint)

                Spacer()

                Text(phase.badge)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(phase.tint)
            }

            Text(wizardInstruction)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                PeakReadout(title: "Desk peak", value: baselinePeak, tint: .orange)
                PeakReadout(title: "Light tap", value: lightSlapPeak, tint: .mint)
                PeakReadout(title: "Threshold", value: monitor.threshold, tint: .cyan)
            }
            .frame(minHeight: 74)

            HStack(spacing: 12) {
                Button {
                    startCalibration()
                } label: {
                    Label(phase == .idle || phase == .finished ? "Start Wizard" : "Restart", systemImage: "wand.and.stars")
                        .frame(width: 150)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.mint)
                .disabled(!monitor.canMonitor)

                Button {
                    cancelCalibration()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                        .frame(width: 110)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!phase.isActive)

                if !monitor.canMonitor {
                    Text("Sensor unavailable")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.red.opacity(0.86))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var thresholdPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Trigger threshold", systemImage: "slider.horizontal.below.rectangle")
                Spacer()
                Text("\(monitor.threshold, specifier: "%.2f") g")
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
            }

            Slider(value: $monitor.threshold, in: SlapMonitor.thresholdRange, step: SlapMonitor.thresholdStep)
                .tint(.mint)

            HStack(spacing: 12) {
                CalibrationPreset(title: "Soft", value: 0.45, monitor: monitor)
                CalibrationPreset(title: "Balanced", value: 0.75, monitor: monitor)
                CalibrationPreset(title: "Hard", value: 1.00, monitor: monitor)
            }
            .frame(minHeight: 62)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var liveImpactPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Live impact", systemImage: "waveform.path.ecg")
                .font(.headline)
            ProgressView(value: min(displayedImpact / 2.5, 1.0))
                .tint(displayedImpact >= monitor.threshold ? .mint : .orange)
            Text("\(displayedImpact, specifier: "%.3f") g")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func startCalibration() {
        cancelCalibration(restoreMonitoring: false)

        baselinePeak = 0
        lightSlapPeak = 0
        displayedImpact = 0
        isWaitingForQuietImpact = true
        quietSampleCount = 0
        wasMonitoringBeforeCalibration = monitor.isMonitoring
        monitor.resetCalibrationImpactPeak()
        phase = .deskTap
        phaseStartedAt = Date()

        calibrationTask = Task { @MainActor in
            if !monitor.isMonitoring {
                await monitor.startMonitoring()
            }

            guard monitor.isMonitoring else {
                phase = .idle
                return
            }

            monitor.status = "Calibration: desk tap"
        }
    }

    private func cancelCalibration(restoreMonitoring: Bool = true) {
        calibrationTask?.cancel()
        calibrationTask = nil

        if restoreMonitoring && phase.isActive && !wasMonitoringBeforeCalibration {
            monitor.stopMonitoring()
        }

        if phase.isActive {
            phase = .idle
        }

        isWaitingForQuietImpact = false
        quietSampleCount = 0
    }

    private func finishCalibration() {
        guard baselinePeak >= CalibrationDetection.minimumImpact,
              lightSlapPeak >= lightTapRequiredImpact else {
            return
        }

        calibrationTask = nil

        let minimumGap = 0.01
        let noiseFloor = max(baselinePeak, SlapMonitor.thresholdRange.lowerBound)
        let slapPeak = max(lightSlapPeak, noiseFloor)
        let suggestedThreshold = max(noiseFloor + minimumGap, slapPeak * 0.72)
        monitor.threshold = SlapMonitor.steppedThreshold(suggestedThreshold)
        phase = .finished
        monitor.status = "Calibration finished"
        onFinish?()

        if !wasMonitoringBeforeCalibration {
            monitor.stopMonitoring()
            monitor.status = "Calibration finished"
        }
    }

    private func startImpactSampling() {
        guard impactSamplingTask == nil else {
            return
        }

        impactSamplingTask = Task { @MainActor in
            while !Task.isCancelled {
                let impact = monitor.currentImpact
                displayedImpact = impact
                processCalibrationImpact(impact)

                try? await Task.sleep(for: CalibrationDetection.samplingInterval)
            }
        }
    }

    private func stopImpactSampling() {
        impactSamplingTask?.cancel()
        impactSamplingTask = nil
    }

    private func processCalibrationImpact(_ impact: Double) {
        guard phase.isActive,
              monitor.isMonitoring else {
            return
        }

        if isWaitingForQuietImpact {
            waitForQuietImpact(impact)
            return
        }

        guard Date().timeIntervalSince(phaseStartedAt) >= CalibrationDetection.phaseArmDelay else {
            return
        }

        switch phase {
        case .deskTap:
            let phasePeak = max(impact, monitor.calibrationImpactPeak)
            baselinePeak = max(baselinePeak, phasePeak)

            guard phasePeak >= CalibrationDetection.minimumImpact else {
                return
            }

            moveToLightSlap()
        case .lightSlap:
            let phasePeak = max(impact, monitor.calibrationImpactPeak)
            lightSlapPeak = max(lightSlapPeak, phasePeak)

            guard phasePeak >= lightTapRequiredImpact else {
                return
            }

            finishCalibration()
        case .idle, .finished:
            return
        }
    }

    private func moveToLightSlap() {
        phase = .lightSlap
        phaseStartedAt = Date()
        isWaitingForQuietImpact = true
        quietSampleCount = 0
        monitor.resetCalibrationImpactPeak()
        monitor.status = "Calibration: settling"
    }

    private var lightTapRequiredImpact: Double {
        CalibrationDetection.minimumImpact
    }

    private func waitForQuietImpact(_ impact: Double) {
        if impact <= CalibrationDetection.quietImpact {
            quietSampleCount += 1
        } else {
            quietSampleCount = 0
        }

        monitor.resetCalibrationImpactPeak()

        guard quietSampleCount >= CalibrationDetection.requiredQuietSamples else {
            return
        }

        isWaitingForQuietImpact = false
        quietSampleCount = 0
        phaseStartedAt = Date()
        monitor.resetCalibrationImpactPeak()

        switch phase {
        case .deskTap:
            monitor.status = "Calibration: desk tap"
        case .lightSlap:
            monitor.status = "Calibration: light tap"
        case .idle, .finished:
            break
        }
    }

    private var wizardInstruction: String {
        guard isWaitingForQuietImpact else {
            return phase.instruction
        }

        switch phase {
        case .deskTap:
            return "Hold still for a moment, then tap the desk once."
        case .lightSlap:
            return "Good. Let the sensor settle, then apply one light tap to the MacBook."
        case .idle, .finished:
            return phase.instruction
        }
    }
}

private enum CalibrationDetection {
    static let samplingInterval: Duration = .milliseconds(25)
    static let phaseArmDelay = 0.25
    static let minimumImpact = 0.025
    static let quietImpact = 0.012
    static let requiredQuietSamples = 4
}

private enum CalibrationPhase {
    case idle
    case deskTap
    case lightSlap
    case finished

    var isActive: Bool {
        self == .deskTap || self == .lightSlap
    }

    var badge: String {
        switch self {
        case .idle:
            "Ready"
        case .deskTap:
            "Step 1"
        case .lightSlap:
            "Step 2"
        case .finished:
            "Done"
        }
    }

    var instruction: String {
        switch self {
        case .idle:
            "Run the wizard to measure desk noise first, then a light MacBook tap."
        case .deskTap:
            "Tap the desk once, away from the MacBook. The wizard waits for a valid peak."
        case .lightSlap:
            "Now apply one light tap to the MacBook. Calibration finishes only after a valid tap."
        case .finished:
            "Threshold updated from the measured peaks. Fine-tune with the slider if needed."
        }
    }

    var symbol: String {
        switch self {
        case .idle:
            "wand.and.stars"
        case .deskTap:
            "deskclock.fill"
        case .lightSlap:
            "hand.tap.fill"
        case .finished:
            "checkmark.seal.fill"
        }
    }

    var tint: Color {
        switch self {
        case .idle:
            .cyan
        case .deskTap:
            .orange
        case .lightSlap:
            .mint
        case .finished:
            .green
        }
    }
}

private struct PeakReadout: View {
    let title: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.52))

            Text("\(value, specifier: "%.3f") g")
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct CalibrationPreset: View {
    let title: String
    let value: Double
    @Bindable var monitor: SlapMonitor

    var body: some View {
        Button {
            monitor.threshold = value
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                Text("\(value, specifier: "%.2f") g")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}
