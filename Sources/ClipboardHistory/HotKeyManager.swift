import Foundation
import Carbon
import AppKit

class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID = EventHotKeyID(signature: 0x434C4950, id: 1) // "CLIP"

    private var eventHandler: EventHandlerRef?

    /// Callback invoked when the hotkey is pressed
    var onHotKey: (() -> Void)?

    private init() {}

    /// Register Cmd+Shift+V as the global hotkey
    func register() -> Bool {
        // Install event handler for hotkey events
        let eventSpec = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        ]

        // Use the callback-based API
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else {
                    return OSStatus(eventNotHandledErr)
                }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.onHotKey?()
                return noErr
            },
            1,
            eventSpec,
            selfPtr,
            &eventHandler
        )

        guard status == noErr else {
            NSLog("Clipboard: Failed to install event handler: \(status)")
            return false
        }

        // Register Cmd+Shift+V
        // kVK_ANSI_V = 0x09
        // cmdKey = cmdKey (0x0100), shiftKey = shiftKey (0x0200)
        let keyCode: UInt32 = 0x09 // 'V'
        let modifiers: UInt32 = UInt32(cmdKey) | UInt32(shiftKey)

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            NSLog("Clipboard: Failed to register hotkey: \(registerStatus)")
            return false
        }

        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}