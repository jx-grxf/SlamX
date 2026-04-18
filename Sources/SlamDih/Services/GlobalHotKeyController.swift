@preconcurrency import Carbon
import Foundation

final class GlobalHotKeyController: @unchecked Sendable {
    private static let hotKeySignature: OSType = 0x534C444D
    private static let hotKeyID: UInt32 = 1

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var action: (@MainActor @Sendable () -> Void)?

    deinit {
        unregister()
    }

    func register(action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
        unregisterHotKey()
        installEventHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: Self.hotKeyID)
        let modifiers = UInt32(cmdKey | shiftKey)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_M),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        unregisterHotKey()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        action = nil
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handleHotKey,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func performAction() {
        Task { @MainActor in
            action?()
        }
    }

    private static let handleHotKey: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else {
            return noErr
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr,
              hotKeyID.signature == GlobalHotKeyController.hotKeySignature,
              hotKeyID.id == GlobalHotKeyController.hotKeyID else {
            return noErr
        }

        let controller = Unmanaged<GlobalHotKeyController>.fromOpaque(userData).takeUnretainedValue()
        controller.performAction()
        return noErr
    }
}
