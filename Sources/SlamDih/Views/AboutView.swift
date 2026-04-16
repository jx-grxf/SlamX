import SwiftUI

struct AboutView: View {
    @Bindable var monitor: SlapMonitor
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("About")
                    .font(.system(size: 38, weight: .bold, design: .rounded))

                Text("Local MacBook impact detector")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.68))
            }

            VStack(alignment: .leading, spacing: 14) {
                AboutRow(title: "Sensor", value: monitor.sensorName)
                AboutRow(title: "Sound", value: "\(monitor.selectedSound.title) / \(monitor.soundStatus)")
                AboutRow(title: "Backend", value: "IOKit HID / AppleSPU")
                AboutRow(title: "Target", value: "macOS 14+")
                AboutRow(title: "Author", value: "Johannes Grof (MIT)")

                HStack(alignment: .firstTextBaseline) {
                    Text("Repository")
                        .foregroundStyle(.white.opacity(0.56))
                        .frame(width: 110, alignment: .leading)

                    Button {
                        openURL(URL(string: "https://github.com/jx-grxf/SlamDih")!)
                    } label: {
                        Label("github.com/jx-grxf/SlamDih", systemImage: "arrow.up.right.square")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.link)
                }
            }
            .font(.title3)
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }

            Text("Core Motion is not exposed for MacBook accelerometer access on macOS. SlamDih reads the built-in Apple SPU HID stream and keeps all processing local.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.white)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.09),
                    Color(red: 0.10, green: 0.13, blue: 0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

private struct AboutRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.white.opacity(0.56))
                .frame(width: 110, alignment: .leading)

            Text(value)
                .foregroundStyle(.white.opacity(0.86))
                .textSelection(.enabled)
        }
    }
}
