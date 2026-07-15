//
//  GalleryView.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import SwiftUI

struct GalleryView: View {
    @ObservedObject var store: SessionStore

    var body: some View {
        NavigationStack {
            List {
                if store.allSessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "photo.stack",
                        description: Text("Captured photos will appear here.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(store.allSessions) { session in
                        NavigationLink(destination: SessionDetailView(session: session, store: store)) {
                            GalleryRow(session: session)
                        }
                    }
                }
            }
            .navigationTitle("Gallery")
            .toolbar(.visible, for: .tabBar)
        }
    }
}

// MARK: - GalleryRow

private struct GalleryRow: View {
    let session: SessionRecord

    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(formattedDate)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text("\(session.frameCount) frame\(session.frameCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    statusBadge
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .task { await loadThumbnail() }
        .onDisappear { thumbnail = nil }
    }

    // MARK: Subviews

    private var thumbnailView: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "photo.stack")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                    }
            }
        }
    }

    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            switch session.status {
            case .active:    return ("Active", .blue)
            case .closed:    return ("Closed", .orange)
            case .saved:     return ("Saved", .green)
            case .discarded: return ("Discarded", .gray)
            }
        }()

        return Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: session.createdAt)
    }

    private func loadThumbnail() async {
        guard thumbnail == nil else { return }
        let folderURL = session.folderURL
        let firstFrameURL = await Task.detached(priority: .utility) {
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            return contents
                .filter { $0.lastPathComponent.hasPrefix("IMG_") && $0.pathExtension.lowercased() == "jpg" }
                .min { $0.lastPathComponent < $1.lastPathComponent }
        }.value
        guard !Task.isCancelled, let firstFrameURL,
              let loaded = await GalleryImageLoader.shared.loadImage(
                at: firstFrameURL,
                maxPixelSize: 180
              ),
              !Task.isCancelled else { return }
        thumbnail = UIImage(cgImage: loaded)
    }
}
