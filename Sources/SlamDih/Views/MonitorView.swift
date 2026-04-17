import SwiftUI

struct MonitorView: View {
    @Bindable var monitor: SlapMonitor

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.08),
                    Color(red: 0.11, green: 0.12, blue: 0.10),
                    Color(red: 0.07, green: 0.10, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    HStack(spacing: 14) {
                        MetricTile(title: "Slaps", value: "\(monitor.slapCount)", symbol: "hand.raised.fill", tint: .mint)
                        MetricTile(title: "Impact", value: monitor.currentImpact.formatted(.number.precision(.fractionLength(2))), symbol: "bolt.fill", tint: .yellow)
                        MetricTile(title: "Peak", value: monitor.peakImpact.formatted(.number.precision(.fractionLength(2))), symbol: "chart.line.uptrend.xyaxis", tint: .orange)
                        MetricTile(title: "Hz", value: "\(monitor.samplesPerSecond)", symbol: "speedometer", tint: .cyan)
                    }

                    HStack(alignment: .top, spacing: 14) {
                        SensorPanel(monitor: monitor)
                        ControlPanel(monitor: monitor)
                    }

                    RawReportPanel(rawReport: monitor.rawReport)
                }
                .padding(28)
            }
        }
        .foregroundStyle(.white)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    monitor.resetCounter()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("Reset counter")

                Button {
                    monitor.playTestSound()
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .help("Test slap sound")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text("SlamDih")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text(monitor.lastEventDescription)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer()

            HStack(spacing: 10) {
                SensorHealthBadge(availability: monitor.sensorAvailability)
                StatusPill(isActive: monitor.isMonitoring, text: monitor.status)
            }
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

struct SensorPanel: View {
    @Bindable var monitor: SlapMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeader(title: "Sensor Values", symbol: "gyroscope")

            AxisMeter(label: "X", value: monitor.xAxis, tint: .red)
            AxisMeter(label: "Y", value: monitor.yAxis, tint: .green)
            AxisMeter(label: "Z", value: monitor.zAxis, tint: .blue)

            Divider().overlay(.white.opacity(0.12))

            HStack {
                Text("Magnitude")
                    .foregroundStyle(.white.opacity(0.62))
                Spacer()
                Text("\(monitor.magnitude, specifier: "%.3f") g")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
            }
        }
        .panelStyle()
    }
}

struct ControlPanel: View {
    @Bindable var monitor: SlapMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeader(title: "Controls", symbol: "dial.low")

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Sensitivity", systemImage: "slider.horizontal.3")
                        .symbolRenderingMode(.hierarchical)
                    Spacer()
                    Text("\(monitor.threshold, specifier: "%.2f") g")
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Slider(value: $monitor.threshold, in: SlapMonitor.thresholdRange, step: SlapMonitor.thresholdStep)
                    .tint(.mint)
            }

            HStack(spacing: 10) {
                Button {
                    monitor.toggleMonitoring()
                } label: {
                    Label(monitor.monitoringActionTitle, systemImage: monitor.monitoringActionSymbol)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(monitor.isMonitoring ? .red : .mint)
                .disabled(!monitor.sensorAvailability.canMonitor && !monitor.isMonitoring)

                Button {
                    monitor.playTestSound()
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Test sound")

                Button {
                    monitor.resetCounter()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Reset counter")
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Sound", systemImage: monitor.selectedSound.symbol)
                    .symbolRenderingMode(.hierarchical)

                Picker("Sound", selection: $monitor.selectedSound) {
                    ForEach(SlapSound.allCases) { sound in
                        Label(sound.title, systemImage: sound.symbol)
                            .tag(sound)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider().overlay(.white.opacity(0.12))

            InfoRow(title: "Sensor", value: "\(monitor.sensorName) · \(monitor.sensorStatusTitle)")
            InfoRow(title: "Sound", value: monitor.soundStatus)
            InfoRow(title: "Status", value: monitor.status)
        }
        .panelStyle()
    }
}

struct RawReportPanel: View {
    let rawReport: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: "Raw HID Report", symbol: "memorychip")
            Text(rawReport.isEmpty ? "Waiting for data" : rawReport)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.white.opacity(0.66))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .panelStyle()
    }
}

struct AxisMeter: View {
    let label: String
    let value: Double
    let tint: Color

    private var normalized: Double {
        min(max((value + 2.0) / 4.0, 0.0), 1.0)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(.body, design: .monospaced).weight(.bold))
                .frame(width: 18)
                .foregroundStyle(tint)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.10))

                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: max(8, proxy.size.width * normalized))
                        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: normalized)
                }
            }
            .frame(height: 12)

            Text("\(value, specifier: "%+.3f")")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 72, alignment: .trailing)
        }
    }
}

struct PanelHeader: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
}

struct SensorHealthBadge: View {
    let availability: SensorAvailability

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: availability.systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
            Text(availability.compactTitle)
                .lineLimit(1)
        }
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .foregroundStyle(.primary)
        .help(availability.title)
    }

    private var tint: Color {
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

struct StatusPill: View {
    let isActive: Bool
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? .mint : .secondary)
                .frame(width: 8, height: 8)
            Text(text)
                .lineLimit(1)
        }
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .foregroundStyle(.primary)
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.58))
            Spacer()
            Text(value)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white.opacity(0.76))
        }
        .font(.callout)
    }
}

private extension View {
    func panelStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .visualEffect { content, _ in
                content
            }
    }
}
