//
//  TimelapseExporter.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import AVFoundation
import Combine
import UIKit

struct TimelapseExportSettings: Equatable {
    var frameDurationSeconds: Double = SessionRecord.defaultFrameDurationSeconds
    var resolution: TimelapseResolution = .native
    var quality: TimelapseQuality = .high

    var effectiveFPS: Double {
        1.0 / SessionRecord.clampedFrameDuration(frameDurationSeconds)
    }
}

enum TimelapseResolution: String, CaseIterable, Identifiable {
    case native
    case hd1080
    case hd720

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .native: return "Best (4K)"
        case .hd1080: return "1080p"
        case .hd720: return "720p"
        }
    }

    nonisolated var maximumPixelSize: CGSize {
        switch self {
        case .native: return CGSize(width: 3840, height: 2160)
        case .hd1080: return CGSize(width: 1920, height: 1080)
        case .hd720: return CGSize(width: 1280, height: 720)
        }
    }
}

enum TimelapseQuality: String, CaseIterable, Identifiable {
    case high
    case standard
    case compact

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .high: return "High"
        case .standard: return "Standard"
        case .compact: return "Compact"
        }
    }

    nonisolated var bitrateMultiplier: Int {
        switch self {
        case .high: return 10
        case .standard: return 6
        case .compact: return 3
        }
    }
}

final class TimelapseExporter: ObservableObject {
    enum ExportState: Equatable {
        case idle
        case exporting(Double)
        case success
        case failed(String)
    }

    @Published private(set) var state: ExportState = .idle

    @MainActor
    func export(session: SessionRecord, settings: TimelapseExportSettings) async {
        guard state == .idle || isResetableState else { return }
        state = .exporting(0.0)

        let result = await Task.detached(priority: .userInitiated) { () -> Result<URL, Error> in
            do {
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(
                    at: session.folderURL,
                    includingPropertiesForKeys: nil
                )
                let frameURLs = contents
                    .filter { $0.lastPathComponent.hasPrefix("IMG_") && $0.pathExtension.lowercased() == "jpg" }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }

                guard !frameURLs.isEmpty else {
                    return .failure(NSError(domain: "TimelapseExporter", code: 101, userInfo: [NSLocalizedDescriptionKey: "No frames to export."]))
                }

                guard let firstFrameURL = frameURLs.first,
                      let firstImage = UIImage(contentsOfFile: firstFrameURL.path) else {
                    return .failure(NSError(domain: "TimelapseExporter", code: 102, userInfo: [NSLocalizedDescriptionKey: "Failed to read first frame."]))
                }

                let outputSize = Self.outputSize(
                    sourceSize: Self.orientedPixelSize(for: firstImage),
                    resolution: settings.resolution
                )
                let width = Int(outputSize.width)
                let height = Int(outputSize.height)
                let outputURL = session.folderURL.appendingPathComponent("timelapse.mp4")

                if fileManager.fileExists(atPath: outputURL.path) {
                    try fileManager.removeItem(at: outputURL)
                }

                let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: width * height * settings.quality.bitrateMultiplier
                    ]
                ]

                let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                let bufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: writerInput,
                    sourcePixelBufferAttributes: [
                        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                        kCVPixelBufferWidthKey as String: width,
                        kCVPixelBufferHeightKey as String: height
                    ]
                )

                if assetWriter.canAdd(writerInput) {
                    assetWriter.add(writerInput)
                } else {
                    return .failure(NSError(domain: "TimelapseExporter", code: 103, userInfo: [NSLocalizedDescriptionKey: "Cannot add video writer input."]))
                }

                assetWriter.startWriting()
                assetWriter.startSession(atSourceTime: .zero)

                let frameDuration = CMTime(
                    seconds: SessionRecord.clampedFrameDuration(settings.frameDurationSeconds),
                    preferredTimescale: 60_000
                )
                var currentFrameIndex = 0

                for url in frameURLs {
                    while !writerInput.isReadyForMoreMediaData {
                        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    }

                    if Task.isCancelled {
                        assetWriter.cancelWriting()
                        return .failure(NSError(domain: "TimelapseExporter", code: 104, userInfo: [NSLocalizedDescriptionKey: "Export cancelled."]))
                    }

                    guard let img = UIImage(contentsOfFile: url.path),
                          let buffer = Self.pixelBuffer(from: img, size: CGSize(width: width, height: height)) else {
                        continue
                    }

                    let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(currentFrameIndex))
                    bufferAdaptor.append(buffer, withPresentationTime: presentationTime)

                    currentFrameIndex += 1
                    let progress = Double(currentFrameIndex) / Double(frameURLs.count)
                    await self.updateProgress(progress)
                }

                writerInput.markAsFinished()
                await assetWriter.finishWriting()

                if assetWriter.status == .failed {
                    return .failure(assetWriter.error ?? NSError(domain: "TimelapseExporter", code: 105, userInfo: [NSLocalizedDescriptionKey: "AVAssetWriter failed."]))
                }

                return .success(outputURL)
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success:
            state = .success
        case .failure(let error):
            state = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func export(session: SessionRecord, fps: Int) async {
        await export(session: session, settings: TimelapseExportSettings(frameDurationSeconds: 1.0 / Double(fps)))
    }

    func reset() {
        state = .idle
    }

    private var isResetableState: Bool {
        switch state {
        case .success, .failed: return true
        default: return false
        }
    }

    @MainActor
    private func updateProgress(_ progress: Double) {
        self.state = .exporting(progress)
    }

    nonisolated private static func outputSize(sourceSize: CGSize, resolution: TimelapseResolution) -> CGSize {
        let sourceWidth = Int(sourceSize.width)
        let sourceHeight = Int(sourceSize.height)
        let maximumSize = resolution.maximumPixelSize
        let maximumWidth = Int(sourceHeight > sourceWidth ? maximumSize.height : maximumSize.width)
        let maximumHeight = Int(sourceHeight > sourceWidth ? maximumSize.width : maximumSize.height)

        guard sourceWidth > maximumWidth || sourceHeight > maximumHeight else {
            return CGSize(width: even(sourceWidth), height: even(sourceHeight))
        }

        let scale = min(
            CGFloat(maximumWidth) / CGFloat(sourceWidth),
            CGFloat(maximumHeight) / CGFloat(sourceHeight)
        )
        return CGSize(
            width: even(Int(CGFloat(sourceWidth) * scale)),
            height: even(Int(CGFloat(sourceHeight) * scale))
        )
    }

    nonisolated private static func even(_ value: Int) -> Int {
        max(2, (value / 2) * 2)
    }

    nonisolated private static func orientedPixelSize(for image: UIImage) -> CGSize {
        guard let cgImage = image.cgImage else {
            return CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        }

        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            return CGSize(width: cgImage.height, height: cgImage.width)
        default:
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
    }

    nonisolated private static func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer? = nil
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }

        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.interpolationQuality = .high

        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        image.draw(in: CGRect(origin: .zero, size: size))
        UIGraphicsPopContext()
        return buffer
    }
}
