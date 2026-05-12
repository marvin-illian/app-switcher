import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = root.appendingPathComponent("AppSwitcher/Resources/AppIcon.iconset")
let outputURL = root.appendingPathComponent("AppSwitcher/Resources/AppIcon.icns")

try? FileManager.default.removeItem(at: iconsetURL)
try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconFiles: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in iconFiles {
    let image = iconImage(size: size)
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not render \(filename)")
    }

    try pngData.write(to: iconsetURL.appendingPathComponent(filename))
}

func iconImage(size: CGFloat) -> NSImage {
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

func drawSwitchMark(in rect: NSRect, color: NSColor) {
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
