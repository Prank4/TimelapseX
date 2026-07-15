import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import TimelapseXGalleryLogic

struct GalleryImageLoaderTests {
    @Test func largeImageIsDecodedWithinRequestedPixelBound() async throws {
        let url = try makeJPEG(width: 1_600, height: 1_200)
        defer { try? FileManager.default.removeItem(at: url) }

        let image = await GalleryImageLoader.shared.loadImage(at: url, maxPixelSize: 320)

        let loaded = try #require(image)
        #expect(max(loaded.width, loaded.height) <= 320)
        #expect(loaded.width == 320)
        #expect(loaded.height == 240)
    }

    @Test func smallImageIsNotUpscaled() async throws {
        let url = try makeJPEG(width: 120, height: 80)
        defer { try? FileManager.default.removeItem(at: url) }

        let image = await GalleryImageLoader.shared.loadImage(at: url, maxPixelSize: 320)

        let loaded = try #require(image)
        #expect(loaded.width <= 120)
        #expect(loaded.height <= 80)
    }

    @Test func invalidImageReturnsNil() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try Data("not an image".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let image = await GalleryImageLoader.shared.loadImage(at: url, maxPixelSize: 320)

        #expect(image == nil)
    }

    private func makeJPEG(width: Int, height: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TestImageError.creationFailed
        }

        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.jpeg.identifier as CFString,
                1,
                nil
              ) else {
            throw TestImageError.creationFailed
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw TestImageError.creationFailed
        }
        return url
    }
}

private enum TestImageError: Error {
    case creationFailed
}
