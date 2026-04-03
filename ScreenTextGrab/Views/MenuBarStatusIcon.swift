import AppKit
import SwiftUI

struct MenuBarStatusIcon: View {
    var body: some View {
        Image(nsImage: StatusBarIconFactory.image)
            .renderingMode(.template)
            .frame(width: 18, height: 18)
            .accessibilityLabel("ScreenTextGrab")
    }
}

private enum StatusBarIconFactory {
    static let image: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let strokeColor = NSColor.labelColor
        strokeColor.setStroke()
        strokeColor.setFill()

        let lineWidth: CGFloat = 1.7
        let cornerLength: CGFloat = 3.2
        let minX: CGFloat = 3.5
        let maxX: CGFloat = 14.5
        let minY: CGFloat = 3.8
        let maxY: CGFloat = 14.2

        func drawCorner(x: CGFloat, y: CGFloat, horizontalSign: CGFloat, verticalSign: CGFloat) {
            let path = NSBezierPath()
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.move(to: NSPoint(x: x, y: y + verticalSign * cornerLength))
            path.line(to: NSPoint(x: x, y: y))
            path.line(to: NSPoint(x: x + horizontalSign * cornerLength, y: y))
            path.stroke()
        }

        drawCorner(x: minX, y: maxY, horizontalSign: 1, verticalSign: -1)
        drawCorner(x: maxX, y: maxY, horizontalSign: -1, verticalSign: -1)
        drawCorner(x: minX, y: minY, horizontalSign: 1, verticalSign: 1)
        drawCorner(x: maxX, y: minY, horizontalSign: -1, verticalSign: 1)

        NSBezierPath(roundedRect: NSRect(x: 5.0, y: 8.4, width: 8.0, height: 1.6), xRadius: 0.8, yRadius: 0.8).fill()
        NSBezierPath(roundedRect: NSRect(x: 6.1, y: 5.9, width: 5.8, height: 1.5), xRadius: 0.75, yRadius: 0.75).fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }()
}
