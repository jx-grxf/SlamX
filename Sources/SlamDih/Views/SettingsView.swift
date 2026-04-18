import SwiftUI

struct SettingsView: View {
    @Bindable var monitor: SlapMonitor

    @State private var launchAtLoginController = LaunchAtLoginController()

    var body: some View {
        Form {
            Section("General") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { launchAtLoginController.isEnabled },
                        set: { launchAtLoginController.setEnabled($0) }
                    )
                )
                .toggleStyle(.checkbox)

                Text(launchAtLoginController.statusDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let errorMessage = launchAtLoginController.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

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
                Toggle(
                    "Mute Sounds",
                    isOn: Binding(
                        get: { monitor.isMuted },
                        set: { isMuted in
                            guard monitor.isMuted != isMuted else {
                                return
                            }

                            monitor.toggleMute()
                        }
                    )
                )
                .toggleStyle(.switch)

                Text("Global shortcut: Command-Shift-M")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Toggle("Show Bonus Sounds", isOn: $monitor.isBonusSoundsEnabled)
                    .toggleStyle(.switch)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 500)
        .padding()
        .onAppear {
            launchAtLoginController.refresh()
        }
    }
}
