import Sparkle

@MainActor
@Observable
final class UpdateController {
    enum Status: Equatable {
        case idle
        case checking
        case updateAvailable(UpdateInfo)
        case updateReady(UpdateInfo)
    }

    struct UpdateInfo: Equatable {
        let displayVersion: String
        let buildVersion: String
        let title: String

        init(item: SUAppcastItem) {
            displayVersion = item.displayVersionString
            buildVersion = item.versionString
            title = item.title ?? "SlamDih \(item.displayVersionString)"
        }
    }

    private let updateDelegate: SparkleUpdateDelegate
    private let updaterController: SPUStandardUpdaterController

    private(set) var status: Status = .idle

    var menuItemTitle: String? {
        switch status {
        case .idle:
            return nil
        case .checking:
            return "Checking for Updates..."
        case .updateAvailable(let update):
            return "Update \(update.displayVersion) Available"
        case .updateReady(let update):
            return "Update \(update.displayVersion) Ready: Restart..."
        }
    }

    var menuItemSystemImage: String {
        switch status {
        case .idle:
            return "arrow.triangle.2.circlepath"
        case .checking:
            return "clock.arrow.circlepath"
        case .updateAvailable:
            return "arrow.down.circle.fill"
        case .updateReady:
            return "restart.circle.fill"
        }
    }

    var menuItemHelp: String {
        switch status {
        case .idle:
            return "Check for updates"
        case .checking:
            return "Sparkle is checking GitHub releases"
        case .updateAvailable(let update):
            return "Show release notes for \(update.title)"
        case .updateReady(let update):
            return "Show install window for \(update.title)"
        }
    }

    private var hasRequestedInitialCheck = false

    init() {
        let updateDelegate = SparkleUpdateDelegate()
        self.updateDelegate = updateDelegate
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: updateDelegate,
            userDriverDelegate: nil
        )

        updateDelegate.handleEvent = { [weak self] event in
            self?.handle(event)
        }
    }

    func checkForUpdates() {
        status = .checking
        updaterController.checkForUpdates(nil)
    }

    func refreshUpdateStatusIfNeeded() {
        guard !hasRequestedInitialCheck else {
            return
        }

        hasRequestedInitialCheck = true
        status = .checking
        updaterController.updater.checkForUpdateInformation()
    }

    func showUpdateDetails() {
        checkForUpdates()
    }

    private func handle(_ event: SparkleUpdateEvent) {
        switch event {
        case .found(let item):
            status = .updateAvailable(UpdateInfo(item: item))
        case .downloaded(let item):
            status = .updateReady(UpdateInfo(item: item))
        case .notFound, .failed:
            status = .idle
        }
    }
}

private enum SparkleUpdateEvent {
    case found(SUAppcastItem)
    case downloaded(SUAppcastItem)
    case notFound
    case failed
}

@MainActor
private final class SparkleUpdateDelegate: NSObject, SPUUpdaterDelegate {
    var handleEvent: ((SparkleUpdateEvent) -> Void)?

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        handleEvent?(.found(item))
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        handleEvent?(.downloaded(item))
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        handleEvent?(.notFound)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        handleEvent?(.failed)
    }
}
