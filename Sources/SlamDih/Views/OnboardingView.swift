import SwiftUI

struct OnboardingView: View {
    @Bindable var monitor: SlapMonitor
    let startApp: () -> Void

    @State private var didStartCheck = false
    @State private var scannerRotation = 0.0
    @State private var scannerPulse = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            SensorScannerView(
                availability: monitor.sensorAvailability,
                rotation: scannerRotation,
                isPulsing: scannerPulse
            )

            VStack(spacing: 8) {
                Text(monitor.sensorAvailability.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 30)

            VStack(spacing: 10) {
                Button {
                    startApp()
                } label: {
                    Label("Start using SlamDih", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.mint)
                .disabled(!monitor.sensorAvailability.canMonitor)

                Button {
                    Task {
                        await monitor.checkSensorAvailability()
                    }
                } label: {
                    Label("Check Again", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(monitor.sensorAvailability == .checking)
            }
            .padding(.horizontal, 42)

            Spacer(minLength: 10)
        }
        .foregroundStyle(.white)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.07),
                    Color(red: 0.08, green: 0.12, blue: 0.11),
                    Color(red: 0.12, green: 0.09, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
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
}

private struct SensorScannerView: View {
    let availability: SensorAvailability
    let rotation: Double
    let isPulsing: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 148, height: 148)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }

            Circle()
                .trim(from: 0.08, to: 0.72)
                .stroke(scannerTint.gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 170, height: 170)
                .rotationEffect(.degrees(availability == .checking ? rotation : 0))
                .opacity(availability == .checking ? 1 : 0.52)

            Circle()
                .stroke(scannerTint.opacity(0.2), lineWidth: 16)
                .frame(width: isPulsing ? 186 : 154, height: isPulsing ? 186 : 154)
                .opacity(availability == .checking ? 0.8 : 0)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isPulsing)

            Image(systemName: availability.systemImage)
                .font(.system(size: 54, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(scannerTint)
        }
        .frame(width: 210, height: 210)
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
