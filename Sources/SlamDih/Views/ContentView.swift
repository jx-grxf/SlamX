import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case monitor = "Monitor"
    case calibration = "Calibration"
    case about = "About"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .monitor:
            "waveform.path.ecg"
        case .calibration:
            "slider.horizontal.3"
        case .about:
            "info.circle"
        }
    }
}

struct ContentView: View {
    @Bindable var monitor: SlapMonitor
    @State private var selection: AppSection = .monitor

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection, monitor: monitor)

            Divider()
                .overlay(Color.white.opacity(0.08))

            detailView
                .id(selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(red: 0.07, green: 0.08, blue: 0.09))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    monitor.toggleMonitoring()
                } label: {
                    Image(systemName: monitor.isMonitoring ? "stop.fill" : "play.fill")
                }
                .disabled(!monitor.sensorAvailability.canMonitor && !monitor.isMonitoring)
                .help(monitor.isMonitoring ? "Stop monitoring" : "Start monitoring")
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .monitor:
            MonitorView(monitor: monitor)
        case .calibration:
            CalibrationView(monitor: monitor)
        case .about:
            AboutView()
        }
    }
}

private struct SidebarView: View {
    @Binding var selection: AppSection
    let monitor: SlapMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer()
                .frame(height: 58)

            ForEach(AppSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: section.symbol)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 18)

                        Text(section.rawValue)
                            .font(.callout.weight(.semibold))

                        Spacer()
                    }
                    .foregroundStyle(selection == section ? .white : .white.opacity(0.64))
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(selection == section ? Color.white.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(section.rawValue)
            }

            Spacer()

            SidebarStatusView(monitor: monitor)
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 16)
        .frame(width: 208)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.05, green: 0.06, blue: 0.07))
    }
}

private struct SidebarStatusView: View {
    let monitor: SlapMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: monitor.sensorAvailability.systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(sensorTint)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sensor")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(monitor.sensorStatusTitle)
                        .font(.callout.weight(.semibold))
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Slaps")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(monitor.slapCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                Spacer()

                StatusPill(isActive: monitor.isMonitoring, text: monitor.status)
            }
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
