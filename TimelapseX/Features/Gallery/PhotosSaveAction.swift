//
//  PhotosSaveAction.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import Foundation
import Photos
import UIKit
import Combine

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

        // 1. Request permission on main actor.
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            state = .failed("Photos access was denied. Open Settings → Privacy → Photos.")
            return
        }

        // 2. Collect frame URLs on main actor.
        let urls = frameURLs(for: session)
        guard !urls.isEmpty else {
            state = .failed("No frames found in this session.")
            return
        }

        // 3. Save each image to Camera Roll on a background thread.
        //    Using performChangesAndWait (synchronous, non-escaping closure)
        //    avoids the @MainActor inference issue that caused the crash.
        let outcome: Result<Void, Error> = await Task.detached(priority: .userInitiated) {
            do {
                for url in urls {
                    guard let image = UIImage(contentsOfFile: url.path),
                          let data = image.jpegData(compressionQuality: 1.0) else { continue }
                    try PHPhotoLibrary.shared().performChangesAndWait {
                        let req = PHAssetCreationRequest.forAsset()
                        req.addResource(with: .photo, data: data, options: nil)
                    }
                }
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value

        switch outcome {
        case .success:
            do {
                try store.saveSession(session, albumIdentifier: "camera-roll")
                state = .success
            } catch {
                state = .failed(error.localizedDescription)
            }
        case .failure(let error):
            state = .failed(error.localizedDescription)
        }
    }

    func reset() { state = .idle }

    private func frameURLs(for session: SessionRecord) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: session.folderURL, includingPropertiesForKeys: nil)) ?? []
        return contents
            .filter { $0.lastPathComponent.hasPrefix("IMG_") && $0.pathExtension.lowercased() == "jpg" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

extension PhotosSaveAction.SaveState {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.saving, .saving), (.success, .success): return true
        case let (.failed(a), .failed(b)): return a == b
        default: return false
        }
    }
}
