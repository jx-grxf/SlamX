import SwiftUI

struct AboutView: View {
    @Bindable var monitor: SlapMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("About")
                .font(.system(size: 38, weight: .bold, design: .rounded))

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
                GridRow {
                    Text("Sensor")
                        .foregroundStyle(.secondary)
                    Text(monitor.sensorName)
                }
                GridRow {
                    Text("Sound")
                        .foregroundStyle(.secondary)
                    Text("\(monitor.selectedSound.title) / \(monitor.soundStatus)")
                }
                GridRow {
                    Text("Backend")
                        .foregroundStyle(.secondary)
                    Text("IOKit HID / AppleSPU")
                }
                GridRow {
                    Text("Target")
                        .foregroundStyle(.secondary)
                    Text("macOS 14+")
                }
            }
            .font(.title3)

            Text("Core Motion is not exposed for MacBook accelerometer access on macOS. SlamDih reads the built-in Apple SPU HID stream and keeps all processing local.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
