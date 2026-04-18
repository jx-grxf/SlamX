import SwiftUI

struct AboutView: View {
    let resetOnboarding: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.08, green: 0.09, blue: 0.10)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.system(size: 38, weight: .bold, design: .rounded))

                        Text("Local MacBook motion utility")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        AboutRow(title: "Sensor", value: "Apple SPU Accelerometer")
                        AboutRow(title: "Backend", value: "IOKit HID / AppleSPU")
                        AboutRow(title: "Target", value: "macOS 14+")
                        AboutRow(title: "Author", value: "Johannes Grof (MIT)")
                        AboutRow(title: "Repository", value: "https://github.com/jx-grxf/SlamDih")
                    }
                    .font(.title3)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    }

                    Text("Core Motion is not exposed for MacBook accelerometer access on macOS. SlamDih reads the built-in Apple SPU HID stream locally; motion data is not stored or uploaded.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .onTapGesture(count: 3) {
            resetOnboarding()
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
        }
    }
}
