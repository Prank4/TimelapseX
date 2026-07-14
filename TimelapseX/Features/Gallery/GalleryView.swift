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
        ForEach(store.allSessions) { session in
            NavigationLink(destination: SessionDetailView(session: session, store: store)) {
                GalleryRow(session: session)
            }
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
        let firstFrameURL = session.folderURL.appendingPathComponent("IMG_000001.jpg")
        let loaded = await Task.detached(priority: .userInitiated) {
            UIImage(contentsOfFile: firstFrameURL.path)
        }.value
        await MainActor.run { thumbnail = loaded }
    }
}
