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
    let resetOnboarding: () -> Void

    @State private var selection: AppSection? = .monitor

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.symbol)
                    .symbolRenderingMode(.hierarchical)
                    .tag(section)
            }
            .navigationTitle("SlamDih")
            .safeAreaInset(edge: .bottom) {
                SidebarStatusView(monitor: monitor)
                    .padding(16)
                    .background(.bar)
            }
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selection) { _, newSelection in
            if newSelection == nil {
                selection = .monitor
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    monitor.toggleMonitoring()
                } label: {
                    Image(systemName: monitor.isMonitoring ? "stop.fill" : "play.fill")
                }
                .disabled(!monitor.canMonitor && !monitor.isMonitoring)
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
            AboutView(resetOnboarding: resetOnboarding)
        }
    }
}

private struct SidebarStatusView: View {
    let monitor: SlapMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: sensorSymbol)
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
                    Text("Events")
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
        .foregroundStyle(.primary)
    }

    private var sensorTint: Color {
        switch monitor.sensorAvailability {
        case .checking:
            return .cyan
        case .detected:
            return .mint
        case .unsupported:
            return .red
        }
    }

    private var sensorSymbol: String {
        monitor.sensorAvailability.systemImage
    }
}
