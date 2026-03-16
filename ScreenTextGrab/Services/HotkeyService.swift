import AppKit
import Carbon

enum HotkeyRegistrationError: LocalizedError, Equatable {
    case invalidShortcut
    case installHandlerFailed(status: OSStatus)
    case registerHotKeyFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidShortcut:
            return L10n.pair("Geçerli bir kısayol seçin. En az bir değiştirici tuş gerekir.", "Choose a valid shortcut. At least one modifier key is required.")
        case .installHandlerFailed(let status):
            return L10n.format("Global hotkey event handler kurulamadı (%d).", "The global hotkey event handler could not be installed (%d).", status)
        case .registerHotKeyFailed(let status):
            return L10n.format("Global hotkey kaydedilemedi (%d). Muhtemelen kısayol başka bir uygulama tarafından kullanılıyor.", "The global hotkey could not be registered (%d). The shortcut is likely in use by another app.", status)
        }
    }
}

struct HotkeyConfiguration: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyDisplay: String

    static let defaultValue = HotkeyConfiguration(
        keyCode: UInt32(kVK_ANSI_S),
        modifiers: UInt32(optionKey),
        keyDisplay: "S"
    )

    var displayLabel: String {
        HotkeyFormatter.displayLabel(for: self)
    }

    var isValid: Bool {
        modifiers != 0 && !keyDisplay.isEmpty
    }

    static func from(event: NSEvent) -> HotkeyConfiguration? {
        let modifiers = HotkeyFormatter.carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0,
              let keyDisplay = HotkeyFormatter.keyDisplay(for: event),
              !keyDisplay.isEmpty else {
            return nil
        }

        return HotkeyConfiguration(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers,
            keyDisplay: keyDisplay
        )
    }
}

@MainActor
protocol HotkeyManaging: AnyObject {
    var hotkeyDisplayLabel: String { get }
    var isHotkeyRegistered: Bool { get }
    func updateHotkey(to configuration: HotkeyConfiguration) throws
    func resetHotkeyToDefault() throws
}

final class HotkeyService {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private let onHotkeyPressed: () -> Void

    private(set) var configuration: HotkeyConfiguration
    private(set) var isRegistered = false

    var hotkeyDisplayLabel: String {
        configuration.displayLabel
    }

    init(
        onHotkeyPressed: @escaping () -> Void,
        configuration: HotkeyConfiguration = HotkeyConfigurationStore.load()
    ) {
        self.onHotkeyPressed = onHotkeyPressed
        self.configuration = configuration
    }

    deinit {
        unregisterHotkey()
    }

    func registerHotkey() throws {
        guard configuration.isValid else {
            throw HotkeyRegistrationError.invalidShortcut
        }

        unregisterHotkey()

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = fourCC("STGR")
        hotKeyID.id = 1

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let handler: EventHandlerUPP = { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                service.onHotkeyPressed()
            }
            return noErr
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        guard installStatus == noErr else {
            eventHandler = nil
            isRegistered = false
            throw HotkeyRegistrationError.installHandlerFailed(status: installStatus)
        }

        let registerStatus = RegisterEventHotKey(
            configuration.keyCode,
            configuration.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            if let eventHandler {
                RemoveEventHandler(eventHandler)
                self.eventHandler = nil
            }
            isRegistered = false
            throw HotkeyRegistrationError.registerHotKeyFailed(status: registerStatus)
        }

        isRegistered = true
        STGLog.capture.info("Global hotkey registered: \(self.hotkeyDisplayLabel, privacy: .public)")
    }

    func unregisterHotkey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
        isRegistered = false
    }

    func updateHotkey(to newConfiguration: HotkeyConfiguration) throws {
        guard newConfiguration.isValid else {
            throw HotkeyRegistrationError.invalidShortcut
        }

        let previousConfiguration = configuration
        let hadRegistered = isRegistered

        configuration = newConfiguration
        do {
            try registerHotkey()
            HotkeyConfigurationStore.save(newConfiguration)
        } catch {
            configuration = previousConfiguration
            if hadRegistered {
                try? registerHotkey()
            }
            throw error
        }
    }

}

private enum HotkeyConfigurationStore {
    static let key = "screenTextGrab.hotkeyConfiguration"

    static func load(defaults: UserDefaults = .standard) -> HotkeyConfiguration {
        guard let data = defaults.data(forKey: key),
              let configuration = try? JSONDecoder().decode(HotkeyConfiguration.self, from: data),
              configuration.isValid else {
            return .defaultValue
        }

        return configuration
    }

    static func save(_ configuration: HotkeyConfiguration, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

private enum HotkeyFormatter {
    static func displayLabel(for configuration: HotkeyConfiguration) -> String {
        modifierLabel(for: configuration.modifiers) + configuration.keyDisplay.uppercased()
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let filtered = flags.intersection([.command, .option, .control, .shift])
        var modifiers: UInt32 = 0

        if filtered.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if filtered.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if filtered.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if filtered.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        return modifiers
    }

    static func keyDisplay(for event: NSEvent) -> String? {
        switch Int(event.keyCode) {
        case kVK_Return:
            return "Return"
        case kVK_Space:
            return "Space"
        case kVK_Tab:
            return "Tab"
        case kVK_Delete:
            return "Delete"
        case kVK_ForwardDelete:
            return "FnDelete"
        case kVK_LeftArrow:
            return "←"
        case kVK_RightArrow:
            return "→"
        case kVK_UpArrow:
            return "↑"
        case kVK_DownArrow:
            return "↓"
        case kVK_F1:
            return "F1"
        case kVK_F2:
            return "F2"
        case kVK_F3:
            return "F3"
        case kVK_F4:
            return "F4"
        case kVK_F5:
            return "F5"
        case kVK_F6:
            return "F6"
        case kVK_F7:
            return "F7"
        case kVK_F8:
            return "F8"
        case kVK_F9:
            return "F9"
        case kVK_F10:
            return "F10"
        case kVK_F11:
            return "F11"
        case kVK_F12:
            return "F12"
        default:
            break
        }

        guard let raw = event.charactersIgnoringModifiers?
            .trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines)),
              let first = raw.first else {
            return nil
        }

        return String(first).uppercased()
    }

    static func modifierLabel(for modifiers: UInt32) -> String {
        var label = ""

        if modifiers & UInt32(controlKey) != 0 {
            label += "⌃"
        }
        if modifiers & UInt32(optionKey) != 0 {
            label += "⌥"
        }
        if modifiers & UInt32(shiftKey) != 0 {
            label += "⇧"
        }
        if modifiers & UInt32(cmdKey) != 0 {
            label += "⌘"
        }

        return label
    }
}

private func fourCC(_ s: String) -> FourCharCode {
    var result: FourCharCode = 0
    if let data = s.data(using: .macOSRoman) {
        data.withUnsafeBytes { result = $0.load(as: UInt32.self).bigEndian }
    }
    return result
}
