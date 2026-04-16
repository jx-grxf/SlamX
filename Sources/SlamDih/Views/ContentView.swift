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
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.symbol)
                    .symbolRenderingMode(.hierarchical)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        monitor.toggleMonitoring()
                    } label: {
                        Image(systemName: monitor.isMonitoring ? "stop.fill" : "play.fill")
                    }
                    .help(monitor.isMonitoring ? "Stop monitoring" : "Start monitoring")
                }
            }
        } detail: {
            switch selection {
            case .monitor:
                MonitorView(monitor: monitor)
            case .calibration:
                CalibrationView(monitor: monitor)
            case .about:
                AboutView(monitor: monitor)
            }
        }
    }
}
