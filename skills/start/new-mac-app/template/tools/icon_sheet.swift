import AppKit

// Puts icon renders side by side on a gray strip, at their own pixel size.
// Called by tools/icon_review.sh: swift icon_sheet.swift <out.png> <in.png>...

let args = CommandLine.arguments
let images = args.dropFirst(2).compactMap { NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: $0))) }
    .map { rep -> (rep: NSBitmapImageRep, image: NSImage) in
        let image = NSImage(size: NSSize(width: rep.pixelsWide, height: rep.pixelsHigh))
        image.addRepresentation(rep)
        return (rep, image)
    }
let gap = 48
let height = (images.map(\.rep.pixelsHigh).max() ?? 0) + gap * 2
let width = images.reduce(gap) { $0 + $1.rep.pixelsWide + gap }
let sheet = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: sheet)
NSColor(white: 0.55, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
var x = gap
for (rep, image) in images {
    // ictool writes 16-bit PNGs; drawing the NSImage keeps their transparent corners.
    let y = (height - rep.pixelsHigh) / 2
    image.draw(in: NSRect(x: x, y: y, width: rep.pixelsWide, height: rep.pixelsHigh),
               from: .zero, operation: .sourceOver, fraction: 1)
    x += rep.pixelsWide + gap
}
NSGraphicsContext.current = nil
try! sheet.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1]))
