import SwiftUI

struct SettingsView: View {
    @Bindable var monitor: SlapMonitor

    var body: some View {
        Form {
            Section("Detection") {
                Picker("Input", selection: $monitor.detectionInputMode) {
                    ForEach(DetectionInputMode.allCases) { inputMode in
                        Label(inputMode.settingsTitle, systemImage: inputMode.symbol)
                            .tag(inputMode)
                    }
                }
                .pickerStyle(.segmented)

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

            if monitor.detectionInputMode == .microphone {
                Section("Microphone Fallback") {
                    Label("Not recommended", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)

                    Text("This mode listens only on this Mac, does not record or save audio, and never uploads microphone data. It can still trigger on speech, loud noises, and other sharp sounds, and it can increase battery usage.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Toggle("I understand this mode is less accurate and can trigger on speech or loud noises.", isOn: $monitor.hasAcceptedMicrophoneAccuracyWarning)
                    Toggle("I understand microphone access is required, but audio stays local and is not stored.", isOn: $monitor.hasAcceptedMicrophonePrivacyNotice)
                    Toggle("I understand battery usage can increase while listening through the microphone.", isOn: $monitor.hasAcceptedMicrophoneBatteryWarning)
                    Toggle("I understand the Apple SPU accelerometer mode is still recommended.", isOn: $monitor.hasAcceptedMicrophoneNotRecommendedWarning)
                }
            }

            Section("Audio") {
                Toggle("Activate NSFW Sounds", isOn: $monitor.isNSFWSoundsEnabled)
                    .toggleStyle(.switch)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 520)
        .padding()
    }
}
