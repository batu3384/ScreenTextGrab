import AppKit

protocol SelectionOverlayPresenting: AnyObject {
    func showOverlay()
    func closeOverlay()
}

final class SelectionOverlayWindow: NSObject, SelectionOverlayPresenting {
    private var overlayWindows: [NSWindow] = []
    private var selectionViews: [SelectionView] = []
    private let onSelectionComplete: (CGRect, NSScreen) -> Void
    private let onCancel: () -> Void
    private var escMonitor: Any?
    private var didPushCursor = false

    init(onSelectionComplete: @escaping (CGRect, NSScreen) -> Void, onCancel: @escaping () -> Void) {
        self.onSelectionComplete = onSelectionComplete
        self.onCancel = onCancel
        super.init()
    }

    func showOverlay() {
        closeOverlay()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.2)
            window.level = .statusBar + 1
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let viewFrame = CGRect(origin: .zero, size: screen.frame.size)
            let selectionView = SelectionView(frame: viewFrame)

            selectionView.onSelectionComplete = { [weak self, weak window] localRect in
                guard let self, let window else { return }
                let globalRect = window.convertToScreen(localRect)
                self.handleSelection(globalRect, on: screen)
            }

            selectionView.onCancel = { [weak self] in
                self?.cancelAndClose()
            }

            window.contentView = selectionView
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(selectionView)

            overlayWindows.append(window)
            selectionViews.append(selectionView)
        }

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.cancelAndClose()
                return nil
            }
            return event
        }

        NSCursor.crosshair.push()
        didPushCursor = true
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeOverlay() {
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
            self.escMonitor = nil
        }

        if didPushCursor {
            NSCursor.pop()
            didPushCursor = false
        }

        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        selectionViews.removeAll()
    }

    private func cancelAndClose() {
        closeOverlay()
        onCancel()
    }

    private func handleSelection(_ rect: CGRect, on screen: NSScreen) {
        closeOverlay()
        onSelectionComplete(rect, screen)
    }
}

final class SelectionView: NSView {
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentRect: NSRect?
    private var isSelecting = false

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.25).setFill()
        bounds.fill()

        guard let rect = currentRect else { return }

        NSColor.clear.setFill()
        rect.fill(using: .copy)

        let border = NSBezierPath(rect: rect)
        border.lineWidth = 2.0
        NSColor.systemBlue.withAlphaComponent(0.9).setStroke()
        border.stroke()

        drawSizeLabel(for: rect)
    }

    private func drawSizeLabel(for rect: NSRect) {
        let text = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]

        let textSize = text.size(withAttributes: attrs)
        let padding: CGFloat = 6
        let labelX = rect.midX - (textSize.width + padding * 2) / 2
        let labelY = max(rect.minY - textSize.height - 14, 4)

        let labelRect = NSRect(
            x: labelX,
            y: labelY,
            width: textSize.width + padding * 2,
            height: textSize.height + padding
        )

        let bg = NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.75).setFill()
        bg.fill()

        text.draw(at: NSPoint(x: labelX + padding, y: labelY + padding / 2), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        isSelecting = true
        currentRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint, isSelecting else { return }

        let current = convert(event.locationInWindow, from: nil)
        currentRect = NSRect(
            x: min(startPoint.x, current.x),
            y: min(startPoint.y, current.y),
            width: abs(current.x - startPoint.x),
            height: abs(current.y - startPoint.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let rect = currentRect, isSelecting else { return }

        isSelecting = false
        if rect.width > 5 && rect.height > 5 {
            onSelectionComplete?(rect)
        } else {
            onCancel?()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }
}
