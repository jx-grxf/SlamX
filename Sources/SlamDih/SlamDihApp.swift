import SwiftUI

@main
struct SlamDihApp: App {
    @State private var monitor = SlapMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView(monitor: monitor)
                .frame(minWidth: 920, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("SlamDih") {
                Button(monitor.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                    monitor.toggleMonitoring()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Test Slap Sound") {
                    monitor.playTestSound()
                }
                .keyboardShortcut("t", modifiers: [.command])

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
            Button(monitor.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                monitor.toggleMonitoring()
            }

            Button("Test Slap Sound") {
                monitor.playTestSound()
            }

            Divider()

            Text("Slaps: \(monitor.slapCount)")
            Text("Sound: \(monitor.selectedSound.title)")
            Text("Impact: \(monitor.currentImpact, specifier: "%.2f") g")
        }
        .menuBarExtraStyle(.menu)
    }
}
