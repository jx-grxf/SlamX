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

            VStack(alignment: .leading, spacing: 6) {
                Text("Slaps")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.44))

                Text("\(monitor.slapCount)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 16)
        .frame(width: 208)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.05, green: 0.06, blue: 0.07))
    }
}
