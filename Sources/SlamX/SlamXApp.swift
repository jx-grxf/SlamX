import AppKit
import SwiftUI

struct SlamXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @State private var hasCompletedOnboarding: Bool
    @State private var monitor: SlapMonitor
    @State private var hotKeyController = GlobalHotKeyController()
    @State private var updateController = UpdateController()

    private let preferences: SlamXPreferences

    init() {
        let preferences = SlamXPreferences.standard
        preferences.migrateLegacyDefaults()

        self.preferences = preferences
        _hasCompletedOnboarding = State(initialValue: preferences.hasCompletedOnboarding)
        _monitor = State(initialValue: SlapMonitor(userDefaults: preferences.userDefaults))
    }

    var body: some Scene {
        WindowGroup("SlamX", id: "main") {
            Group {
                if hasCompletedOnboarding {
                    ContentView(monitor: monitor, updateController: updateController) {
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
            .modifier(MonitorPersistenceModifier(monitor: monitor, preferences: preferences))
            .onAppear {
                hotKeyController.register {
                    monitor.toggleMute()
                }
                updateController.checkForUpdatesOnLaunchIfNeeded()
            }
        }
        .commands {
            CommandMenu("SlamX") {
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

        MenuBarExtra("SlamX", systemImage: "hand.raised.fill") {
            MenuBarPanel(
                monitor: monitor,
                updateController: updateController,
                showApp: showApp
            )
        }
        .menuBarExtraStyle(.menu)
    }

    private func showApp() {
        if let window = NSApp.windows.first(where: { $0.title == "SlamX" }) {
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
        preferences.setHasCompletedOnboarding(true)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func resetOnboarding() {
        hasCompletedOnboarding = false
        preferences.setHasCompletedOnboarding(false)
        monitor.stopMonitoring()
        monitor.resetCounter()
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct MonitorPersistenceModifier: ViewModifier {
    @Bindable var monitor: SlapMonitor
    let preferences: SlamXPreferences

    @State private var didLoadPersistedValues = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !didLoadPersistedValues else {
                    return
                }

                didLoadPersistedValues = true
                monitor.applyPersistedValues(
                    threshold: preferences.threshold,
                    slapCount: preferences.slapCount
                )
            }
            .onChange(of: monitor.threshold) { _, newValue in
                preferences.setThreshold(newValue)
            }
            .onChange(of: monitor.slapCount) { _, newValue in
                preferences.setSlapCount(newValue)
            }
    }
}

@MainActor
private final class SlamXPreferences {
    static let standard = SlamXPreferences(
        userDefaults: .standard,
        legacyDefaults: UserDefaults(suiteName: Legacy.domain)
    )

    let userDefaults: UserDefaults
    private let legacyDefaults: UserDefaults?

    private init(userDefaults: UserDefaults, legacyDefaults: UserDefaults?) {
        self.userDefaults = userDefaults
        self.legacyDefaults = legacyDefaults
    }

    var hasCompletedOnboarding: Bool {
        userDefaults.bool(forKey: Key.hasCompletedOnboarding)
    }

    var threshold: Double {
        guard let storedValue = userDefaults.doubleObject(forKey: Key.threshold) else {
            return 0.75
        }

        return SlapMonitor.steppedThreshold(storedValue)
    }

    var slapCount: Int {
        max(0, userDefaults.integer(forKey: Key.slapCount))
    }

    func setHasCompletedOnboarding(_ value: Bool) {
        userDefaults.set(value, forKey: Key.hasCompletedOnboarding)
    }

    func setThreshold(_ value: Double) {
        userDefaults.set(SlapMonitor.steppedThreshold(value), forKey: Key.threshold)
    }

    func setSlapCount(_ value: Int) {
        userDefaults.set(max(0, value), forKey: Key.slapCount)
    }

    func migrateLegacyDefaults() {
        guard let legacyDefaults else {
            return
        }

        for key in Key.migratedKeys where userDefaults.object(forKey: key) == nil {
            guard let legacyValue = legacyDefaults.object(forKey: key) else {
                continue
            }

            userDefaults.set(legacyValue, forKey: key)
        }
    }

    private enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let threshold = "threshold"
        static let slapCount = "slapCount"
        static let bonusSoundsEnabled = "bonusSoundsEnabled"
        static let selectedSound = "selectedSound"
        static let selectedCustomSound = "selectedCustomSound"
        static let customAudioDisclaimerAccepted = "customAudioDisclaimerAccepted"

        static let migratedKeys = [
            hasCompletedOnboarding,
            threshold,
            slapCount,
            bonusSoundsEnabled,
            selectedSound,
            selectedCustomSound,
            customAudioDisclaimerAccepted
        ]
    }

    private enum Legacy {
        static let domain = "com.johannesgrof.slamdih"
    }
}

private extension UserDefaults {
    func doubleObject(forKey key: String) -> Double? {
        switch object(forKey: key) {
        case let value as Double:
            value
        case let value as NSNumber:
            value.doubleValue
        default:
            nil
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
