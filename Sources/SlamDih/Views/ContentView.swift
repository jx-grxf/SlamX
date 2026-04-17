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
    @State private var selection: AppSection? = .monitor

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, monitor: monitor)
        } detail: {
            detailView
                .id(selection ?? .monitor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
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
        switch selection ?? .monitor {
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
    @Binding var selection: AppSection?
    let monitor: SlapMonitor

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(AppSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.symbol)
                        .symbolRenderingMode(.hierarchical)
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarStatusView(monitor: monitor)
                .padding(16)
                .background(.ultraThinMaterial)
        }
        .navigationTitle("SlamDih")
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
