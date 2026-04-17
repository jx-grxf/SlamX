import SwiftUI

struct SettingsView: View {
    @Bindable var monitor: SlapMonitor

    var body: some View {
        Form {
            Section("Detection") {
                Slider(value: $monitor.threshold, in: SlapMonitor.thresholdRange, step: SlapMonitor.thresholdStep) {
                    Text("Threshold")
                } minimumValueLabel: {
                    Text("Soft")
                } maximumValueLabel: {
                    Text("Hard")
                }

                Text("\(monitor.threshold, specifier: "%.2f") g")
                    .font(.system(.body, design: .monospaced))
            }

            Section("Audio") {
                Toggle("Activate NSFW Sounds", isOn: $monitor.isNSFWSoundsEnabled)
                    .toggleStyle(.switch)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 250)
        .padding()
    }
}
