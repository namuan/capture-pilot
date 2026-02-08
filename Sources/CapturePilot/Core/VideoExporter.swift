import Foundation
import AVFoundation
import AppKit

class VideoExporter: ObservableObject {
    static let shared = VideoExporter()
    
    @Published var exportProgress: Double = 0
    @Published var isExporting = false
    @Published var exportError: String?
    
    private var exportTask: Task<Void, Never>?
    
    func exportSession(sessionPath: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard !isExporting else { return }

        let url = URL(fileURLWithPath: sessionPath)
        guard FileManager.default.fileExists(atPath: sessionPath) else {
            completion(.failure(NSError(domain: "VideoExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Session path does not exist"])))
            return
        }

        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        let imageFiles = contents.filter({ $0.pathExtension.lowercased() == "png" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent })

        guard !imageFiles.isEmpty else {
            completion(.failure(NSError(domain: "VideoExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "No images found in session"])))
            return
        }

        DispatchQueue.main.async {
            self.isExporting = true
            self.exportProgress = 0
            self.exportError = nil
        }

        exportTask = Task { @MainActor in
            defer { isExporting = false }

            do {
                let outputURL = url.appendingPathComponent("session.mp4")
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try FileManager.default.removeItem(at: outputURL)
                }

                guard let firstImage = NSImage(contentsOf: imageFiles[0]),
                      let cgImage = firstImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    throw NSError(domain: "VideoExporter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to load first image"])
                }

                let width = cgImage.width
                let height = cgImage.height

                guard let videoWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
                    throw NSError(domain: "VideoExporter", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create video writer"])
                }

                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 8000000,
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                    ]
                ]

                let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoWriterInput.expectsMediaDataInRealTime = false

                let sourcePixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height
                ]
                let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)

                videoWriter.add(videoWriterInput)

                guard videoWriter.startWriting() else {
                    throw NSError(domain: "VideoExporter", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to start writing"])
                }

                videoWriter.startSession(atSourceTime: .zero)

                for (index, imageURL) in imageFiles.enumerated() {
                    guard !Task.isCancelled else { break }

                    if let image = NSImage(contentsOf: imageURL),
                       let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {

                        while !videoWriterInput.isReadyForMoreMediaData {
                            try await Task.sleep(nanoseconds: 10_000_000)
                        }

                        let presentationTime = CMTime(seconds: Double(index) * 0.1, preferredTimescale: 600)

                        if let buffer = createPixelBuffer(from: cgImage, width: width, height: height) {
                            pixelBufferAdaptor.append(buffer, withPresentationTime: presentationTime)
                        }
                    }

                    exportProgress = Double(index + 1) / Double(imageFiles.count)
                }

                videoWriterInput.markAsFinished()
                await videoWriter.finishWriting()

                if Task.isCancelled {
                    try? FileManager.default.removeItem(at: outputURL)
                } else {
                    sendNotification(title: "Export Complete", body: "Your video is ready at \(outputURL.deletingLastPathComponent().lastPathComponent)/session.mp4")
                    completion(.success(outputURL))
                }
            } catch {
                exportError = error.localizedDescription
                completion(.failure(error))
            }
        }
    }
    
    func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        isExporting = false
        exportProgress = 0
    }
    
    private func createPixelBuffer(from cgImage: CGImage, width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs as CFDictionary, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(origin: .zero, size: CGSize(width: width, height: height)))
        return buffer
    }
    
    private func sendNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        NSUserNotificationCenter.default.deliver(notification)
    }
}
