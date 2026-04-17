import SwiftUI

struct OnboardingView: View {
    @Bindable var monitor: SlapMonitor
    let startApp: () -> Void

    @State private var didStartCheck = false
    @State private var scannerRotation = 0.0
    @State private var scannerPulse = false
    @State private var hasAcceptedDamageDisclaimer = false

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(alignment: .leading, spacing: 0) {
                header

                Spacer(minLength: 28)

                HStack(alignment: .center, spacing: 56) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SlamDih")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.mint)

                            Text(monitor.sensorAvailability.title)
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
                        rotation: scannerRotation,
                        isPulsing: scannerPulse
                    )
                }

                Spacer(minLength: 30)

                damageDisclaimer
                    .padding(.bottom, 12)

                diagnosticsRow
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

            await monitor.checkSensorAvailability()
        }
    }

    private var header: some View {
        HStack {
            Label("SlamDih", systemImage: "hand.raised.fill")
                .font(.headline.weight(.bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)

            Spacer()

            SensorHealthBadge(availability: monitor.sensorAvailability)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                startApp()
            } label: {
                Label("Start using SlamDih", systemImage: "arrow.right.circle.fill")
                    .frame(width: 230)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.mint)
            .disabled(!monitor.sensorAvailability.canMonitor || !hasAcceptedDamageDisclaimer)

            Button {
                Task {
                    await monitor.checkSensorAvailability()
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

    private var diagnosticsRow: some View {
        HStack(spacing: 12) {
            OnboardingStatusItem(
                title: "Sensor",
                value: monitor.sensorStatusTitle,
                symbol: monitor.sensorAvailability.systemImage,
                tint: sensorTint
            )

            OnboardingStatusItem(
                title: "Audio",
                value: monitor.soundStatus,
                symbol: monitor.selectedSoundSymbol,
                tint: .orange
            )

            OnboardingStatusItem(
                title: "Engine",
                value: "Local HID",
                symbol: "memorychip",
                tint: .cyan
            )
        }
    }

    private var damageDisclaimer: some View {
        Toggle(isOn: $hasAcceptedDamageDisclaimer) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Important legal-ish wisdom:")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)

                Text("I accept that SlamDih is not a MacBook insurance policy and Johannes is not liable if I hit this thing like I am trying to mine diamonds.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.checkbox)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.mint.opacity(hasAcceptedDamageDisclaimer ? 0.46 : 0.18), lineWidth: 1)
        }
    }

    private var description: String {
        switch monitor.sensorAvailability {
        case .checking:
            "SlamDih is checking the Apple SPU accelerometer required for live impact monitoring."
        case .detected:
            "Everything needed for live slap detection is available on this Mac."
        case .unsupported:
            "SlamDih needs a MacBook with an Apple SPU accelerometer. This Mac cannot run live monitoring."
        }
    }

    private var sensorTint: Color {
        switch monitor.sensorAvailability {
        case .checking:
            .cyan
        case .detected:
            .mint
        case .unsupported:
            .orange
        }
    }
}

private struct SensorScannerView: View {
    let availability: SensorAvailability
    let rotation: Double
    let isPulsing: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 236, height: 236)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }

            Circle()
                .trim(from: 0.08, to: 0.72)
                .stroke(scannerTint.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .frame(width: 282, height: 282)
                .rotationEffect(.degrees(availability == .checking ? rotation : 0))
                .opacity(availability == .checking ? 1 : 0.52)

            Circle()
                .stroke(scannerTint.opacity(0.2), lineWidth: 22)
                .frame(width: isPulsing ? 314 : 244, height: isPulsing ? 314 : 244)
                .opacity(availability == .checking ? 0.8 : 0)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isPulsing)

            Image(systemName: availability.systemImage)
                .font(.system(size: 76, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(scannerTint)
        }
        .frame(width: 330, height: 330)
        .accessibilityLabel(availability.title)
    }

    private var scannerTint: Color {
        switch availability {
        case .checking:
            .cyan
        case .detected:
            .mint
        case .unsupported:
            .orange
        }
    }
}

private struct OnboardingStatusItem: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.48))
                Text(value)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.09), lineWidth: 1)
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
