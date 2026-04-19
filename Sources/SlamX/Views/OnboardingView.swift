import AppKit
import SwiftUI

struct OnboardingView: View {
    @Bindable var monitor: SlapMonitor
    let startApp: () -> Void

    @State private var didStartCheck = false
    @State private var scannerRotation = 0.0
    @State private var scannerPulse = false
    @State private var isSoundTestActive = false
    @State private var hasCompletedSoundTest = false
    @State private var isShowingCalibration = false
    @State private var hasCompletedCalibration = false
    @State private var soundTestSlapBaseline = 0
    @State private var thresholdBeforeSoundTest: Double?
    @State private var showsUnsupportedTestModeNotice = false

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(alignment: .leading, spacing: 0) {
                header

                Spacer(minLength: 28)

                HStack(alignment: .center, spacing: 56) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SlamX")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.mint)

                            Text(title)
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)

                            Text(description)
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.white.opacity(0.68))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: 500, alignment: .leading)

                        actionRow
                    }

                    Spacer(minLength: 12)

                    SensorScannerView(
                        availability: monitor.sensorAvailability,
                        isSoundTestActive: isSoundTestActive,
                        hasCompletedSoundTest: hasCompletedSoundTest,
                        rotation: scannerRotation,
                        isPulsing: scannerPulse
                    )
                }

                Spacer(minLength: 30)

                ProgressStepsView(
                    sensorAvailability: monitor.sensorAvailability,
                    hasCompletedSoundTest: hasCompletedSoundTest,
                    hasCompletedCalibration: hasCompletedCalibration,
                    canStart: canStartApp
                )
            }
            .padding(.horizontal, 48)
            .padding(.top, 38)
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .task {
            guard !didStartCheck else {
                return
            }

            didStartCheck = true
            scannerPulse = true

            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                scannerRotation = 360
            }

            await runAvailabilityCheck()
        }
        .alert("Unsupported-device test mode", isPresented: $showsUnsupportedTestModeNotice) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("SlamX is now simulating a Mac without the Apple SPU accelerometer. This is only for testing the unsupported-device flow; it does not mean this Mac is actually unsupported.")
        }
        .sheet(isPresented: $isShowingCalibration) {
            CalibrationView(monitor: monitor) {
                hasCompletedCalibration = true
            }
            .frame(width: 720, height: 620)
        }
        .onChange(of: monitor.slapCount) { _, newValue in
            guard isSoundTestActive, !hasCompletedSoundTest, newValue > soundTestSlapBaseline else {
                return
            }

            completeSoundTest()
        }
        .onDisappear {
            stopSoundTestIfNeeded()
        }
    }

    private var header: some View {
        HStack {
            Label("SlamX", systemImage: "hand.raised.fill")
                .font(.headline.weight(.bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .onTapGesture(count: 3) {
                    enableUnsupportedTestMode()
                }

            Spacer()

            SensorHealthBadge(availability: monitor.sensorAvailability)
        }
    }

    private var actionRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if monitor.sensorAvailability == .unsupported {
                    Button {
                        Task {
                            await runAvailabilityCheck()
                        }
                    } label: {
                        Label("Check Again", systemImage: "arrow.clockwise")
                            .frame(width: 144)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.mint)
                    .disabled(monitor.sensorAvailability == .checking)

                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Label("Quit", systemImage: "xmark.circle.fill")
                            .frame(width: 112)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else {
                    Button {
                        finishOnboarding()
                        startApp()
                    } label: {
                        Label("Start using SlamX", systemImage: "arrow.right.circle.fill")
                            .frame(width: 230)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.mint)
                    .disabled(!canStartApp)

                    Button {
                        Task {
                            await runAvailabilityCheck()
                        }
                    } label: {
                        Label("Check Again", systemImage: "arrow.clockwise")
                            .frame(width: 144)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(monitor.sensorAvailability == .checking)
                }
            }

            Button {
                isShowingCalibration = true
            } label: {
                HStack(spacing: 10) {
                    Label("Calibrate Threshold", systemImage: "slider.horizontal.3")
                    BetaBadge()
                }
                .frame(width: 230)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!hasCompletedSoundTest || !monitor.canMonitor)
        }
    }

    private var canStartApp: Bool {
        monitor.canMonitor && hasCompletedSoundTest
    }

    private var title: String {
        switch monitor.sensorAvailability {
        case .checking:
            return "Checking accelerometer"
        case .detected where hasCompletedSoundTest:
            return "Ready to monitor"
        case .detected:
            return "Verify detection"
        case .unsupported:
            return "This Mac is not supported"
        }
    }

    private var description: String {
        switch monitor.sensorAvailability {
        case .checking:
            return "SlamX is checking whether this Mac exposes the Apple SPU motion sensor."
        case .detected where hasCompletedSoundTest && hasCompletedCalibration:
            return "Detection is verified and the beta calibration has tuned the trigger threshold."
        case .detected where hasCompletedSoundTest:
            return "The local sensor and audio path are working. You can continue to the monitor."
        case .detected where isSoundTestActive && monitor.samplesPerSecond == 0:
            return "Approve the sensor helper when macOS asks, then apply one light tap to verify live motion data."
        case .detected where isSoundTestActive:
            return "Apply one light tap to verify that the sensor can detect a clear impact."
        case .detected:
            return "The motion sensor is available. SlamX will run one quick local detection check."
        case .unsupported:
            return "\(monitor.unsupportedSensorExplanation) You can check again after moving to a supported MacBook or quit SlamX safely."
        }
    }

    private var soundTestStatusTitle: String {
        if hasCompletedSoundTest {
            return "Passed"
        }

        if isSoundTestActive {
            return "Tap now"
        }

        return monitor.sensorAvailability == .checking ? "Waiting" : "Pending"
    }

    private var soundTestSymbol: String {
        hasCompletedSoundTest ? "checkmark.circle.fill" : "speaker.wave.2.fill"
    }

    private var soundTestTint: Color {
        if hasCompletedSoundTest {
            return .mint
        }

        return isSoundTestActive ? .yellow : .white.opacity(0.56)
    }

    private func runAvailabilityCheck() async {
        resetOnboardingGate()
        await monitor.checkSensorAvailability()

        await startSoundTestIfPossible()
    }

    private func startSoundTestIfPossible() async {
        guard monitor.canMonitor else {
            return
        }

        scannerPulse = true
        thresholdBeforeSoundTest = monitor.threshold
        monitor.threshold = SlapMonitor.thresholdRange.lowerBound

        soundTestSlapBaseline = monitor.slapCount
        isSoundTestActive = true
        await monitor.startMonitoring()

        if monitor.isMonitoring {
            monitor.status = "Sound test listening"
        } else {
            isSoundTestActive = false
            restoreThresholdIfNeeded()
        }
    }

    private func completeSoundTest() {
        isSoundTestActive = false
        hasCompletedSoundTest = true
        scannerPulse = false
        scannerRotation = 0
        monitor.stopMonitoring()
        restoreThresholdIfNeeded()
        monitor.status = "Sound test passed"

        withAnimation(.easeInOut(duration: 0.85)) {
            scannerRotation = 360
        }
    }

    private func enableUnsupportedTestMode() {
        stopSoundTestIfNeeded()
        hasCompletedSoundTest = false
        monitor.isSensorUnsupportedTestMode = true
        showsUnsupportedTestModeNotice = true
    }

    private func resetOnboardingGate() {
        hasCompletedSoundTest = false
        hasCompletedCalibration = false
        stopSoundTestIfNeeded()
    }

    private func finishOnboarding() {
        stopSoundTestIfNeeded()
        monitor.resetCounter()
    }

    private func stopSoundTestIfNeeded() {
        if isSoundTestActive || monitor.isMonitoring {
            monitor.stopMonitoring()
        }

        isSoundTestActive = false
        restoreThresholdIfNeeded()
    }

    private func restoreThresholdIfNeeded() {
        guard let thresholdBeforeSoundTest else {
            return
        }

        monitor.threshold = thresholdBeforeSoundTest
        self.thresholdBeforeSoundTest = nil
    }
}

private struct SensorScannerView: View {
    let availability: SensorAvailability
    let isSoundTestActive: Bool
    let hasCompletedSoundTest: Bool
    let rotation: Double
    let isPulsing: Bool

    @State private var breathesOut = false
    @State private var successScale = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: innerCircleSize, height: innerCircleSize)
                .shadow(color: glowTint.opacity(glowOpacity), radius: glowRadius)
                .overlay {
                    Circle()
                        .stroke(glowTint.opacity(innerStrokeOpacity), lineWidth: 1.4)
                }
                .animation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true), value: isSoundTestActive ? breathesOut : false)

            Circle()
                .trim(from: 0.08, to: 0.72)
                .stroke(arcTint.gradient, style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round))
                .frame(width: arcSize, height: arcSize)
                .shadow(color: arcTint.opacity(glowOpacity), radius: glowRadius)
                .rotationEffect(.degrees(shouldRotateArc ? rotation : 0))
                .opacity(arcOpacity)
                .animation(.spring(response: 0.42, dampingFraction: 0.8), value: hasCompletedSoundTest)
                .animation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true), value: isSoundTestActive ? breathesOut : false)

            Circle()
                .stroke(pulseTint.opacity(0.2), lineWidth: 22)
                .frame(width: pulseSize, height: pulseSize)
                .opacity(pulseOpacity)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isPulsing)

            Image(systemName: scannerSymbol)
                .font(.system(size: 76, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(scannerTint)
                .scaleEffect(successScale)
                .animation(.spring(response: 0.26, dampingFraction: 0.52), value: successScale)
        }
        .frame(width: 330, height: 330)
        .accessibilityLabel(availability.title)
        .onAppear {
            breathesOut = true
        }
        .onChange(of: hasCompletedSoundTest) { _, didComplete in
            guard didComplete else {
                successScale = 1
                return
            }

            successScale = 1.18

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(260))
                successScale = 1
            }
        }
    }

    private var scannerTint: Color {
        if hasCompletedSoundTest {
            .mint
        } else if availability == .unsupported {
            .red
        } else {
            .cyan
        }
    }

    private var scannerSymbol: String {
        if hasCompletedSoundTest {
            "checkmark.seal.fill"
        } else if availability == .unsupported {
            availability.systemImage
        } else {
            "waveform.path.ecg"
        }
    }

    private var glowTint: Color {
        if hasCompletedSoundTest {
            return .mint
        }

        return isSoundTestActive ? .cyan : .white
    }

    private var pulseTint: Color {
        return isSoundTestActive ? .cyan : scannerTint
    }

    private var arcTint: Color {
        hasCompletedSoundTest ? .mint : scannerTint
    }

    private var shouldRotateArc: Bool {
        availability == .checking || hasCompletedSoundTest
    }

    private var innerCircleSize: CGFloat {
        guard isSoundTestActive && !hasCompletedSoundTest else {
            return 236
        }

        return breathesOut ? 250 : 226
    }

    private var arcSize: CGFloat {
        guard isSoundTestActive && !hasCompletedSoundTest else {
            return 282
        }

        return breathesOut ? 302 : 270
    }

    private var arcLineWidth: CGFloat {
        isSoundTestActive || hasCompletedSoundTest ? 8 : 7
    }

    private var arcOpacity: Double {
        if availability == .checking {
            return 1
        }

        if isSoundTestActive || hasCompletedSoundTest {
            return 0.96
        }

        return 0.52
    }

    private var pulseSize: CGFloat {
        if isSoundTestActive && !hasCompletedSoundTest {
            return breathesOut ? 326 : 260
        }

        return isPulsing ? 314 : 244
    }

    private var pulseOpacity: Double {
        if isSoundTestActive && !hasCompletedSoundTest {
            return 0.82
        }

        return availability == .checking ? 0.8 : 0
    }

    private var glowOpacity: Double {
        if isSoundTestActive && !hasCompletedSoundTest {
            return breathesOut ? 0.72 : 0.34
        }

        return hasCompletedSoundTest ? 0.54 : 0
    }

    private var glowRadius: CGFloat {
        if isSoundTestActive && !hasCompletedSoundTest {
            return breathesOut ? 28 : 14
        }

        return hasCompletedSoundTest ? 20 : 0
    }

    private var innerStrokeOpacity: Double {
        if isSoundTestActive && !hasCompletedSoundTest {
            return breathesOut ? 0.34 : 0.18
        }

        return hasCompletedSoundTest ? 0.28 : 0.14
    }
}

private struct ProgressStepsView: View {
    let sensorAvailability: SensorAvailability
    let hasCompletedSoundTest: Bool
    let hasCompletedCalibration: Bool
    let canStart: Bool

    var body: some View {
        HStack(spacing: 12) {
            OnboardingStepItem(
                title: "Sensor",
                value: sensorStatus,
                symbol: sensorSymbol,
                tint: sensorTint
            )

            OnboardingStepItem(
                title: "Detection",
                value: detectionStatus,
                symbol: detectionSymbol,
                tint: detectionTint
            )

            OnboardingStepItem(
                title: "Calibration",
                value: hasCompletedCalibration ? "Adjusted" : "Optional",
                symbol: hasCompletedCalibration ? "checkmark.circle.fill" : "slider.horizontal.3",
                tint: hasCompletedCalibration ? .mint : .yellow.opacity(0.82),
                isBeta: true
            )

            OnboardingStepItem(
                title: "Ready",
                value: readyStatus,
                symbol: readySymbol,
                tint: readyTint
            )
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.09), lineWidth: 1)
        }
    }

    private var sensorStatus: String {
        switch sensorAvailability {
        case .checking:
            "Checking"
        case .detected:
            "Available"
        case .unsupported:
            "Unavailable"
        }
    }

    private var sensorSymbol: String {
        sensorAvailability.systemImage
    }

    private var sensorTint: Color {
        switch sensorAvailability {
        case .checking:
            return .cyan
        case .detected:
            return .mint
        case .unsupported:
            return .red
        }
    }

    private var detectionStatus: String {
        if hasCompletedSoundTest {
            return "Verified"
        }

        return sensorAvailability == .unsupported ? "Unavailable" : "Pending"
    }

    private var detectionSymbol: String {
        if hasCompletedSoundTest {
            return "checkmark.circle.fill"
        }

        return sensorAvailability == .unsupported ? "minus.circle.fill" : "hand.tap.fill"
    }

    private var detectionTint: Color {
        if hasCompletedSoundTest {
            return .mint
        }

        return sensorAvailability == .unsupported ? .red.opacity(0.82) : .white.opacity(0.56)
    }

    private var readyStatus: String {
        if canStart {
            return "Continue"
        }

        return sensorAvailability == .unsupported ? "Blocked" : "Waiting"
    }

    private var readySymbol: String {
        if canStart {
            return "arrow.right.circle.fill"
        }

        return sensorAvailability == .unsupported ? "lock.fill" : "clock.fill"
    }

    private var readyTint: Color {
        if canStart {
            return .mint
        }

        return sensorAvailability == .unsupported ? .red.opacity(0.82) : .white.opacity(0.56)
    }
}

private struct OnboardingStepItem: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color
    var isBeta = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.48))

                    if isBeta {
                        BetaBadge()
                    }
                }

                Text(value)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
    }
}

private struct BetaBadge: View {
    var body: some View {
        Text("BETA")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.yellow.opacity(0.92))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.yellow.opacity(0.14), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.yellow.opacity(0.28), lineWidth: 1)
            }
    }
}

private struct OnboardingBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.05, blue: 0.06),
                Color(red: 0.07, green: 0.11, blue: 0.10),
                Color(red: 0.15, green: 0.10, blue: 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
