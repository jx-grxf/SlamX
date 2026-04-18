import AppKit
import SwiftUI

@main
struct SlamDihApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var monitor = SlapMonitor()
    @State private var hotKeyController = GlobalHotKeyController()
    @State private var updateController = UpdateController()

    var body: some Scene {
        WindowGroup("SlamDih", id: "main") {
            Group {
                if hasCompletedOnboarding {
                    ContentView(monitor: monitor) {
                        resetOnboarding()
                    }
                    .frame(minWidth: 920, minHeight: 620)
                } else {
                    OnboardingView(monitor: monitor) {
                        finishOnboarding()
                    }
                    .frame(minWidth: 920, minHeight: 620)
                }
            }
            .modifier(MonitorPersistenceModifier(monitor: monitor))
            .onAppear {
                hotKeyController.register {
                    monitor.toggleMute()
                }
                updateController.refreshUpdateStatusIfNeeded()
            }
        }
        .commands {
            CommandMenu("SlamDih") {
                Button(monitor.monitoringActionTitle) {
                    monitor.toggleMonitoring()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!monitor.canMonitor && !monitor.isMonitoring)

                Button("Test Sound") {
                    monitor.playTestSound()
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button(monitor.muteActionTitle) {
                    monitor.toggleMute()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Button("Check for Updates...") {
                    updateController.checkForUpdates()
                }
                .keyboardShortcut("u", modifiers: [.command])

                Divider()

                Button("Reset Counter") {
                    monitor.resetCounter()
                }
                .keyboardShortcut("0", modifiers: [.command])

                Button("Reset Onboarding") {
                    resetOnboarding()
                }
            }
        }

        Settings {
            SettingsView(monitor: monitor)
        }

        MenuBarExtra("SlamDih", systemImage: "hand.raised.fill") {
            MenuBarPanel(
                monitor: monitor,
                updateController: updateController,
                showApp: showApp
            )
        }
        .menuBarExtraStyle(.menu)
    }

    private func showApp() {
        if let window = NSApp.windows.first(where: { $0.title == "SlamDih" }) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func finishOnboarding() {
        hasCompletedOnboarding = true
        NSApp.activate(ignoringOtherApps: true)
    }

    private func resetOnboarding() {
        hasCompletedOnboarding = false
        monitor.stopMonitoring()
        monitor.resetCounter()
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct MonitorPersistenceModifier: ViewModifier {
    @Bindable var monitor: SlapMonitor

    @AppStorage("threshold") private var persistedThreshold = 0.75
    @AppStorage("slapCount") private var persistedSlapCount = 0
    @State private var didLoadPersistedValues = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !didLoadPersistedValues else {
                    return
                }

                didLoadPersistedValues = true
                monitor.applyPersistedValues(
                    threshold: persistedThreshold,
                    slapCount: persistedSlapCount
                )
            }
            .onChange(of: monitor.threshold) { _, newValue in
                persistedThreshold = SlapMonitor.steppedThreshold(newValue)
            }
            .onChange(of: monitor.slapCount) { _, newValue in
                persistedSlapCount = max(0, newValue)
            }
            .onChange(of: persistedThreshold) { _, newValue in
                let steppedValue = SlapMonitor.steppedThreshold(newValue)

                if monitor.threshold != steppedValue {
                    monitor.threshold = steppedValue
                }
            }
            .onChange(of: persistedSlapCount) { _, newValue in
                let safeValue = max(0, newValue)

                if monitor.slapCount != safeValue {
                    monitor.slapCount = safeValue
                }
            }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

private struct MenuBarPanel: View {
    @Bindable var monitor: SlapMonitor
    let updateController: UpdateController
    let showApp: () -> Void

    var body: some View {
        if let updateTitle = updateController.menuItemTitle {
            Button {
                updateController.showUpdateDetails()
            } label: {
                Label(updateTitle, systemImage: updateController.menuItemSystemImage)
            }
            .help(updateController.menuItemHelp)

            Divider()
        }

        Button {
            showApp()
        } label: {
            Label("Show App", systemImage: "macwindow")
        }

        Divider()

        Button {
            monitor.toggleMonitoring()
        } label: {
            Label(monitor.monitoringActionTitle, systemImage: monitor.monitoringActionSymbol)
        }
        .disabled(!monitor.canMonitor && !monitor.isMonitoring)

        Button {
            monitor.playTestSound()
        } label: {
            Label("Test Sound", systemImage: "speaker.wave.2.fill")
        }

        Button {
            monitor.toggleMute()
        } label: {
            Label(monitor.muteActionTitle, systemImage: monitor.muteActionSymbol)
        }

        Button {
            monitor.resetCounter()
        } label: {
            Label("Reset Counter", systemImage: "arrow.counterclockwise")
        }

        Divider()

        MenuBarStatButton(title: "Events", value: "\(monitor.slapCount)", symbol: "hand.raised.fill")
        MenuBarStatButton(title: "Peak", value: "\(monitor.peakImpact.formatted(.number.precision(.fractionLength(2)))) g", symbol: "chart.line.uptrend.xyaxis")
        MenuBarStatButton(title: "Impact", value: "\(monitor.currentImpact.formatted(.number.precision(.fractionLength(2)))) g", symbol: "bolt.fill")
        MenuBarStatButton(title: "Rate", value: "\(monitor.samplesPerSecond) Hz", symbol: "speedometer")
        MenuBarStatButton(
            title: "Sensor",
            value: monitor.sensorStatusTitle,
            symbol: monitor.sensorAvailability.systemImage
        )
        MenuBarStatButton(title: "Sound", value: monitor.selectedSoundTitle, symbol: monitor.selectedSoundSymbol)
    }
}

private struct MenuBarStatButton: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        Button {
            copyStat()
        } label: {
            Label("\(title): \(value)", systemImage: symbol)
        }
        .help("Copy \(title.lowercased())")
    }

    private func copyStat() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(title): \(value)", forType: .string)
    }
}
