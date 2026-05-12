import AppKit

enum AppIconFactory {
    static func appIcon(size: CGFloat = 512) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let scale = rect.width / 512
            let background = NSBezierPath(
                roundedRect: rect.insetBy(dx: 38 * scale, dy: 38 * scale),
                xRadius: 112 * scale,
                yRadius: 112 * scale
            )
            NSColor.black.setFill()
            background.fill()

            drawSwitchMark(in: rect.insetBy(dx: 114 * scale, dy: 132 * scale), color: .white)
            return true
        }
    }

    static func menuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            drawSwitchMark(in: rect.insetBy(dx: 2, dy: 3), color: .black)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawSwitchMark(in rect: NSRect, color: NSColor) {
        let strokeWidth = max(1.8, rect.width * 0.095)
        let arrowInset = strokeWidth / 2
        let topY = rect.minY + rect.height * 0.68
        let bottomY = rect.minY + rect.height * 0.32
        let leftX = rect.minX + arrowInset
        let rightX = rect.maxX - arrowInset
        let head = rect.width * 0.18

        color.setStroke()

        let path = NSBezierPath()
        path.lineWidth = strokeWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        path.move(to: NSPoint(x: leftX, y: topY))
        path.line(to: NSPoint(x: rightX - head, y: topY))
        path.move(to: NSPoint(x: rightX - head, y: topY + head))
        path.line(to: NSPoint(x: rightX, y: topY))
        path.line(to: NSPoint(x: rightX - head, y: topY - head))

        path.move(to: NSPoint(x: rightX, y: bottomY))
        path.line(to: NSPoint(x: leftX + head, y: bottomY))
        path.move(to: NSPoint(x: leftX + head, y: bottomY + head))
        path.line(to: NSPoint(x: leftX, y: bottomY))
        path.line(to: NSPoint(x: leftX + head, y: bottomY - head))

        path.stroke()
    }
}
