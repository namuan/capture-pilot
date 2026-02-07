import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, AnyObject>()
    private let queue = DispatchQueue(label: "capturepilot.imagecache", qos: .userInitiated, attributes: .concurrent)

    private init() {
        cache.countLimit = 500
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func image(forKey key: String) -> NSImage? {
        return cache.object(forKey: key as NSString) as? NSImage
    }

    func store(_ image: NSImage, forKey key: String) {
        let cost = Int((image.representations.first?.pixelsHigh ?? 0) * (image.representations.first?.pixelsWide ?? 0) / 1024)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func loadImage(from url: URL, targetSize: NSSize? = nil, completion: @escaping (NSImage?) -> Void) {
        let key = cacheKey(for: url, size: targetSize)
        if let cached = image(forKey: key) {
            completion(cached)
            return
        }

        queue.async {
            guard let img = NSImage(contentsOf: url) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let out: NSImage
            if let size = targetSize {
                out = img.resized(to: size)
            } else {
                out = img
            }

            self.store(out, forKey: key)
            DispatchQueue.main.async { completion(out) }
        }
    }

    func loadFirstImage(in directory: URL, targetSize: NSSize? = nil, completion: @escaping (Int, NSImage?) -> Void) {
        queue.async {
            let fm = FileManager.default
            guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
                DispatchQueue.main.async { completion(0, nil) }
                return
            }

            let images = contents.filter { ["png", "jpg", "jpeg", "bmp", "gif"].contains($0.pathExtension.lowercased()) }
            let count = images.count
            guard let first = images.first else {
                DispatchQueue.main.async { completion(count, nil) }
                return
            }

            let key = self.cacheKey(for: first, size: targetSize)
            if let cached = self.image(forKey: key) {
                DispatchQueue.main.async { completion(count, cached) }
                return
            }

            if let img = NSImage(contentsOf: first) {
                let out = targetSize != nil ? img.resized(to: targetSize!) : img
                self.store(out, forKey: key)
                DispatchQueue.main.async { completion(count, out) }
            } else {
                DispatchQueue.main.async { completion(count, nil) }
            }
        }
    }

    private func cacheKey(for url: URL, size: NSSize?) -> String {
        if let s = size {
            return "\(url.absoluteString)-\(Int(s.width))x\(Int(s.height))"
        }
        return url.absoluteString
    }
}
