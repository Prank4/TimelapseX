//
//  GalleryImageLoader.swift
//  TimelapseX
//
//  Created by Prank on 14/07/26.
//

import Foundation
import ImageIO

actor GalleryImageLoader {
    static let shared = GalleryImageLoader()

    func loadImage(at url: URL, maxPixelSize: Int) -> CGImage? {
        guard !Task.isCancelled, maxPixelSize > 0 else { return nil }

        return autoreleasepool {
            let sourceOptions: [CFString: Any] = [
                kCGImageSourceShouldCache: false
            ]
            guard let source = CGImageSourceCreateWithURL(
                url as CFURL,
                sourceOptions as CFDictionary
            ) else {
                return nil
            }

            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ]
            return CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                thumbnailOptions as CFDictionary
            )
        }
    }
}
