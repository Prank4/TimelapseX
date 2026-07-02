//
//  PhotosSaveAction.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import Foundation
import Photos
import Combine

/// Encapsulates the Photos `.addOnly` permission request and atomic batch-save for a session.
@MainActor
final class PhotosSaveAction: ObservableObject {
    enum SaveState: Equatable {
        case idle
        case saving
        case success
        case failed(String)
    }

    @Published private(set) var state: SaveState = .idle

    private let store: SessionStore

    init(store: SessionStore) {
        self.store = store
    }

    func save(session: SessionRecord) async {
        guard state != .saving else { return }
        state = .saving

        // 1. Request .addOnly permission
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            state = .failed("Photos access was denied. Go to Settings → Privacy → Photos to allow access.")
            return
        }

        // 2. Collect all frame URLs for this session
        let frameURLs = frameURLs(for: session)
        guard !frameURLs.isEmpty else {
            state = .failed("No frames found in this session.")
            return
        }

        // 3. Batch-add all frames in one performChanges block
        var albumIdentifier: String?
        var saveError: Error?

        do {
            try await PHPhotoLibrary.shared().performChanges {
                // Create album
                let albumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
                    withTitle: "TimelapseX \(session.id)"
                )
                let albumPlaceholder = albumRequest.placeholderForCreatedAssetCollection
                albumIdentifier = albumPlaceholder.localIdentifier

                // Add frames
                var assetPlaceholders: [PHObjectPlaceholder] = []
                for url in frameURLs {
                    let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                    if let placeholder = assetRequest?.placeholderForCreatedAsset {
                        assetPlaceholders.append(placeholder)
                    }
                }

                // Add assets to album
                let fetchResult = PHAssetCollection.fetchAssetCollections(
                    withLocalIdentifiers: [albumPlaceholder.localIdentifier],
                    options: nil
                )
                if let collection = fetchResult.firstObject,
                   let addRequest = PHAssetCollectionChangeRequest(for: collection) {
                    addRequest.addAssets(assetPlaceholders as NSFastEnumeration)
                }
            }
        } catch {
            saveError = error
        }

        if let saveError {
            state = .failed(saveError.localizedDescription)
            return
        }

        guard let identifier = albumIdentifier else {
            state = .failed("Could not retrieve album identifier after save.")
            return
        }

        // 4. Mark session as saved in the store
        do {
            try store.saveSession(session, albumIdentifier: identifier)
            state = .success
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
    }

    // MARK: - Private

    private func frameURLs(for session: SessionRecord) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: session.folderURL,
            includingPropertiesForKeys: nil
        )) ?? []
        return contents
            .filter { $0.lastPathComponent.hasPrefix("IMG_") && $0.pathExtension.lowercased() == "jpg" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

extension PhotosSaveAction.SaveState {
    static func ==(lhs: PhotosSaveAction.SaveState, rhs: PhotosSaveAction.SaveState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.saving, .saving), (.success, .success):
            return true
        case let (.failed(a), .failed(b)):
            return a == b
        default:
            return false
        }
    }
}
