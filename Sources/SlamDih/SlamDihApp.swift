import AppKit
import SwiftUI

@main
struct SlamDihApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var monitor = SlapMonitor()
    @State private var updateController = UpdateController()

    var body: some Scene {
        WindowGroup("SlamDih", id: "main") {
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
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("SlamDih") {
                Button(monitor.monitoringActionTitle) {
                    monitor.toggleMonitoring()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!monitor.sensorAvailability.canMonitor && !monitor.isMonitoring)

                Button("Test Slap Sound") {
                    monitor.playTestSound()
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button("Check for Updates...") {
                    updateController.checkForUpdates()
                }
                .keyboardShortcut("u", modifiers: [.command])

                Divider()

                Button("Reset Counter") {
                    monitor.resetCounter()
                }
                .keyboardShortcut("0", modifiers: [.command])
            }
        }

        Settings {
            SettingsView(monitor: monitor)
        }

        MenuBarExtra("SlamDih", systemImage: "hand.raised.fill") {
            MenuBarPanel(monitor: monitor, showApp: showApp)
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

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

private struct MenuBarPanel: View {
    @Bindable var monitor: SlapMonitor
    let showApp: () -> Void

    var body: some View {
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
        .disabled(!monitor.sensorAvailability.canMonitor && !monitor.isMonitoring)

        Button {
            monitor.playTestSound()
        } label: {
            Label("Test Slap Sound", systemImage: "speaker.wave.2.fill")
        }

        Button {
            monitor.resetCounter()
        } label: {
            Label("Reset Counter", systemImage: "arrow.counterclockwise")
        }

        Divider()

        MenuBarStatButton(title: "Slaps", value: "\(monitor.slapCount)", symbol: "hand.raised.fill")
        MenuBarStatButton(title: "Peak", value: "\(monitor.peakImpact.formatted(.number.precision(.fractionLength(2)))) g", symbol: "chart.line.uptrend.xyaxis")
        MenuBarStatButton(title: "Impact", value: "\(monitor.currentImpact.formatted(.number.precision(.fractionLength(2)))) g", symbol: "bolt.fill")
        MenuBarStatButton(title: "Rate", value: "\(monitor.samplesPerSecond) Hz", symbol: "speedometer")
        MenuBarStatButton(title: "Sensor", value: monitor.sensorStatusTitle, symbol: monitor.sensorAvailability.systemImage)
        MenuBarStatButton(title: "Sound", value: monitor.selectedSound.title, symbol: monitor.selectedSound.symbol)
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
