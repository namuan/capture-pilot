#if os(macOS)
import AppKit

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        let context = NSGraphicsContext.current
        context?.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}
#endif
