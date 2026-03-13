import AppKit

extension ScreenEnvironmentSnapshot {
    @MainActor
    static func capture() -> ScreenEnvironmentSnapshot {
        let displays = NSScreen.screens.compactMap { screen in
            screen.captureDescriptor
        }
        return ScreenEnvironmentSnapshot(displays: displays)
    }

    @MainActor
    func descriptor(for screen: NSScreen) -> ScreenDescriptor? {
        guard let descriptor = screen.captureDescriptor else {
            return nil
        }

        return displays.first(where: { $0.displayID == descriptor.displayID }) ?? descriptor
    }
}

private extension NSScreen {
    @MainActor
    var captureDescriptor: ScreenDescriptor? {
        guard let displayID = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }

        return ScreenDescriptor(
            displayID: displayID,
            frame: frame,
            backingScaleFactor: backingScaleFactor
        )
    }
}
