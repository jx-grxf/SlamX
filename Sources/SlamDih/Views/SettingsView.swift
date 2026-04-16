import SwiftUI

struct SettingsView: View {
    @Bindable var monitor: SlapMonitor

    var body: some View {
        Form {
            Section("Detection") {
                Slider(value: $monitor.threshold, in: 0.15...2.5, step: 0.05) {
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
                Picker("Sound", selection: $monitor.selectedSound) {
                    ForEach(SlapSound.allCases) { sound in
                        Label(sound.title, systemImage: sound.symbol)
                            .tag(sound)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Selected sound")
                    Spacer()
                    Text(monitor.soundStatus)
                        .foregroundStyle(.secondary)
                }

                Button("Test Sound") {
                    monitor.playTestSound()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 310)
        .padding()
    }
}
