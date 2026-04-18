import SwiftUI
import UniformTypeIdentifiers

struct MonitorView: View {
    @Bindable var monitor: SlapMonitor

    @State private var isAdvancedTelemetryExpanded = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.08),
                    Color(red: 0.11, green: 0.12, blue: 0.10),
                    Color(red: 0.07, green: 0.10, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    HStack(spacing: 14) {
                        MetricTile(title: "Events", value: "\(monitor.slapCount)", symbol: "hand.raised.fill", tint: .mint)
                        MetricTile(title: "Current", value: monitor.currentImpact.formatted(.number.precision(.fractionLength(2))), symbol: "bolt.fill", tint: .yellow)
                        MetricTile(title: "Peak", value: monitor.peakImpact.formatted(.number.precision(.fractionLength(2))), symbol: "chart.line.uptrend.xyaxis", tint: .orange)
                        MetricTile(title: "Rate", value: "\(monitor.samplesPerSecond) Hz", symbol: "speedometer", tint: .cyan)
                    }

                    ControlPanel(monitor: monitor)

                    AdvancedTelemetryPanel(
                        monitor: monitor,
                        isExpanded: $isAdvancedTelemetryExpanded
                    )
                }
                .padding(28)
            }
        }
        .foregroundStyle(.white)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    monitor.resetCounter()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("Reset counter")

                Button {
                    monitor.playTestSound()
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .help("Test sound")

                Button {
                    monitor.toggleMute()
                } label: {
                    Image(systemName: monitor.muteActionSymbol)
                }
                .help("Mute sounds")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text("SlamDih")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text(monitor.lastEventDescription)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer()

            HStack(spacing: 10) {
                SensorHealthBadge(availability: monitor.sensorAvailability)
                StatusPill(isActive: monitor.isMonitoring, text: monitor.status)
            }
        }
    }
}

private struct AdvancedTelemetryPanel: View {
    @Bindable var monitor: SlapMonitor
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        AxisMeter(label: "X", value: monitor.xAxis, tint: .red)
                        AxisMeter(label: "Y", value: monitor.yAxis, tint: .green)
                        AxisMeter(label: "Z", value: monitor.zAxis, tint: .blue)

                        HStack {
                            Text("Magnitude")
                                .foregroundStyle(.white.opacity(0.62))
                            Spacer()
                            Text("\(monitor.magnitude, specifier: "%.3f") g")
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Raw HID Report", systemImage: "memorychip")
                            .font(.headline)
                        Text(monitor.rawReport.isEmpty ? "Waiting for data" : monitor.rawReport)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.66))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 12)
            }
        } label: {
            PanelHeader(title: "Advanced Telemetry", symbol: "waveform.path.ecg.rectangle")
        }
        .tint(.white.opacity(0.84))
        .panelStyle()
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

struct ControlPanel: View {
    @Bindable var monitor: SlapMonitor

    @State private var isCustomSoundMenuExpanded = false
    @State private var isShowingCustomAudioDisclaimer = false
    @State private var isShowingFileImporter = false
    @State private var importErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeader(title: "Controls", symbol: "dial.low")

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Sensitivity", systemImage: "slider.horizontal.3")
                        .symbolRenderingMode(.hierarchical)
                    Spacer()
                    Text("\(monitor.threshold, specifier: "%.2f") g")
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Slider(value: $monitor.threshold, in: SlapMonitor.thresholdRange, step: SlapMonitor.thresholdStep)
                    .tint(.mint)
            }

            HStack(spacing: 10) {
                Button {
                    monitor.toggleMonitoring()
                } label: {
                    Label(monitor.monitoringActionTitle, systemImage: monitor.monitoringActionSymbol)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(monitor.isMonitoring ? .red : .mint)
                .disabled(!monitor.canMonitor && !monitor.isMonitoring)

                Button {
                    monitor.playTestSound()
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Test sound")

                Button {
                    monitor.toggleMute()
                } label: {
                    Image(systemName: monitor.muteActionSymbol)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help(monitor.muteActionTitle)

                Button {
                    monitor.resetCounter()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Reset counter")
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Label("Sound", systemImage: monitor.selectedSoundSymbol)
                        .symbolRenderingMode(.hierarchical)

                    Spacer()

                    Button {
                        addCustomSound()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Add custom MP3 sound")
                }

                Picker("Sound", selection: standardSoundSelection) {
                    ForEach(monitor.availableSounds) { sound in
                        Label(sound.title, systemImage: sound.symbol)
                            .tag(Optional(sound))
                    }
                }
                .pickerStyle(.segmented)

                CustomSoundMenu(
                    monitor: monitor,
                    isExpanded: $isCustomSoundMenuExpanded,
                    removeAction: removeCustomSound
                )
            }

            Divider().overlay(.white.opacity(0.12))

            InfoRow(title: "Sensor", value: "\(monitor.sensorName) · \(monitor.sensorStatusTitle)")
            InfoRow(title: "Sound", value: monitor.soundStatus)
            InfoRow(title: "Status", value: monitor.status)
        }
        .panelStyle()
        .sheet(isPresented: $isShowingCustomAudioDisclaimer) {
            CustomAudioDisclaimerSheet {
                monitor.hasAcceptedCustomAudioDisclaimer = true
                isShowingCustomAudioDisclaimer = false
                isShowingFileImporter = true
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [Self.mp3ContentType],
            allowsMultipleSelection: false
        ) { result in
            importCustomAudio(from: result)
        }
        .alert("Custom Sound Failed", isPresented: importErrorBinding) {
            Button("OK", role: .cancel) {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "The custom sound could not be updated.")
        }
    }

    private static var mp3ContentType: UTType {
        UTType(filenameExtension: "mp3") ?? .audio
    }

    private var standardSoundSelection: Binding<SlapSound?> {
        Binding {
            monitor.selectedCustomSoundID == nil ? monitor.selectedSound : nil
        } set: { sound in
            guard let sound else {
                return
            }

            monitor.selectStandardSound(sound)
        }
    }

    private var importErrorBinding: Binding<Bool> {
        Binding {
            importErrorMessage != nil
        } set: { isPresented in
            if !isPresented {
                importErrorMessage = nil
            }
        }
    }

    private func addCustomSound() {
        if monitor.hasAcceptedCustomAudioDisclaimer {
            isShowingFileImporter = true
        } else {
            isShowingCustomAudioDisclaimer = true
        }
    }

    private func importCustomAudio(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }

            try monitor.importCustomSound(from: url)
            isCustomSoundMenuExpanded = true
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func removeCustomSound(_ sound: CustomSlapSound) {
        do {
            try monitor.removeCustomSound(id: sound.id)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }
}

private struct CustomSoundMenu: View {
    @Bindable var monitor: SlapMonitor
    @Binding var isExpanded: Bool
    let removeAction: (CustomSlapSound) -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                if customSounds.isEmpty {
                    Text("No custom MP3s added")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    ForEach(customSounds) { sound in
                        CustomSoundRow(
                            sound: sound,
                            isSelected: monitor.selectedCustomSoundID == sound.id,
                            selectAction: {
                                monitor.selectCustomSound(id: sound.id)
                            },
                            removeAction: {
                                removeAction(sound)
                            }
                        )
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Label("Custom MP3s", systemImage: "music.note.list")
                    .symbolRenderingMode(.hierarchical)
                Spacer()
                Text("\(customSounds.count)")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .tint(.white.opacity(0.82))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var customSounds: [CustomSlapSound] {
        monitor.customSounds()
    }
}

private struct CustomSoundRow: View {
    let sound: CustomSlapSound
    let isSelected: Bool
    let selectAction: () -> Void
    let removeAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                selectAction()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isSelected ? .mint : .white.opacity(0.36))

                    Text(sound.title)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                removeAction()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red.opacity(0.82))
            .help("Remove custom sound")
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(isSelected ? .white.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct CustomAudioDisclaimerSheet: View {
    let continueAction: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hasAcceptedDisclaimer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.badge.plus")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.mint)

                Text("Custom MP3 Sounds")
                    .font(.title3.weight(.bold))
            }

            Text("SlamDih copies imported MP3 files into local app storage. Very long files can delay playback the first time they are loaded.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("I understand and want to enable custom sounds", isOn: $hasAcceptedDisclaimer)
                .toggleStyle(.checkbox)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Choose MP3") {
                    continueAction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasAcceptedDisclaimer)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

struct AxisMeter: View {
    let label: String
    let value: Double
    let tint: Color

    private var normalized: Double {
        min(max((value + 2.0) / 4.0, 0.0), 1.0)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(.body, design: .monospaced).weight(.bold))
                .frame(width: 18)
                .foregroundStyle(tint)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.10))

                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: max(8, proxy.size.width * normalized))
                        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: normalized)
                }
            }
            .frame(height: 12)

            Text("\(value, specifier: "%+.3f")")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 72, alignment: .trailing)
        }
    }
}

struct PanelHeader: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
}

struct SensorHealthBadge: View {
    let availability: SensorAvailability

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
            Text(title)
                .lineLimit(1)
        }
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .foregroundStyle(.primary)
        .help(help)
    }

    private var title: String {
        availability.compactTitle
    }

    private var symbol: String {
        availability.systemImage
    }

    private var help: String {
        availability.title
    }

    private var tint: Color {
        switch availability {
        case .checking:
            return .cyan
        case .detected:
            return .mint
        case .unsupported:
            return .red
        }
    }
}

struct StatusPill: View {
    let isActive: Bool
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? .mint : .secondary)
                .frame(width: 8, height: 8)
            Text(text)
                .lineLimit(1)
        }
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .foregroundStyle(.primary)
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.58))
            Spacer()
            Text(value)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white.opacity(0.76))
        }
        .font(.callout)
    }
}

private extension View {
    func panelStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .visualEffect { content, _ in
                content
            }
    }
}
