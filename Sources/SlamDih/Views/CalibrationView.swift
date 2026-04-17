import SwiftUI

struct CalibrationView: View {
    @Bindable var monitor: SlapMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Calibration")
                .font(.system(size: 38, weight: .bold, design: .rounded))

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
            }
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Label("Live impact", systemImage: "waveform.path.ecg")
                    .font(.headline)
                ProgressView(value: min(monitor.currentImpact / 2.5, 1.0))
                    .tint(monitor.currentImpact >= monitor.threshold ? .mint : .orange)
                Text("\(monitor.currentImpact, specifier: "%.3f") g")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Spacer()
        }
        .padding(28)
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
