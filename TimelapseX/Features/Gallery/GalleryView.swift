//
//  GalleryView.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import SwiftUI

struct GalleryView: View {
    @ObservedObject var store: SessionStore
    @State private var isSelectingAlbums = false
    @State private var selectedAlbumIDs: Set<String> = []
    @State private var showMergeConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var operationAlert: GalleryOperationAlert?
    @State private var isPerformingAlbumOperation = false

    var body: some View {
        NavigationStack {
            List {
                if store.allSessions.isEmpty {
                    ContentUnavailableView(
                        "No Albums",
                        systemImage: "photo.stack",
                        description: Text("Captured photos will appear here.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(store.allSessions) { session in
                        if isSelectingAlbums {
                            Button {
                                toggleSelection(for: session)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedAlbumIDs.contains(session.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selectedAlbumIDs.contains(session.id) ? .blue : .secondary)
                                    GalleryRow(session: session)
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(destination: SessionDetailView(session: session, store: store)) {
                                GalleryRow(session: session)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gallery")
            .toolbar(.visible, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSelectingAlbums ? "Cancel" : "Select") {
                        if isSelectingAlbums {
                            endSelection()
                        } else {
                            isSelectingAlbums = true
                        }
                    }
                    .disabled(store.allSessions.isEmpty || isPerformingAlbumOperation)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelectingAlbums {
                    albumSelectionBar
                }
            }
            .alert("Merge Albums?", isPresented: $showMergeConfirmation) {
                Button("Merge \(selectedAlbumIDs.count) Albums") {
                    mergeSelectedAlbums()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A new chronologically sorted album will be created. The original albums will remain and receive a Merged tag.")
            }
            .alert("Delete Selected Albums?", isPresented: $showDeleteConfirmation) {
                Button("Delete \(selectedAlbumIDs.count)", role: .destructive) {
                    deleteSelectedAlbums()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The selected albums and all photos stored inside them will be permanently deleted. This cannot be undone.")
            }
            .alert(item: $operationAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var albumSelectionBar: some View {
        HStack(spacing: 12) {
            if isPerformingAlbumOperation {
                ProgressView()
                Text("Working…")
                    .font(.subheadline.weight(.medium))
            } else {
                Text("\(selectedAlbumIDs.count) selected")
                    .font(.subheadline.weight(.medium))
            }

            Spacer()

            Button {
                showMergeConfirmation = true
            } label: {
                Label("Merge", systemImage: "rectangle.stack.badge.plus")
            }
            .disabled(selectedAlbumIDs.count < 2 || isPerformingAlbumOperation)

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(selectedAlbumIDs.isEmpty || isPerformingAlbumOperation)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func toggleSelection(for album: SessionRecord) {
        if selectedAlbumIDs.contains(album.id) {
            selectedAlbumIDs.remove(album.id)
        } else {
            selectedAlbumIDs.insert(album.id)
        }
    }

    private func selectedAlbums() -> [SessionRecord] {
        store.allSessions.filter { selectedAlbumIDs.contains($0.id) }
    }

    private func mergeSelectedAlbums() {
        let albums = selectedAlbums()
        isPerformingAlbumOperation = true
        Task {
            defer { isPerformingAlbumOperation = false }
            do {
                let mergedAlbum = try await store.mergeAlbums(albums)
                endSelection()
                operationAlert = GalleryOperationAlert(
                    title: "Albums Merged",
                    message: "Created a new album containing \(mergedAlbum.frameCount) chronologically sorted photos. The originals are tagged Merged."
                )
            } catch {
                operationAlert = GalleryOperationAlert(
                    title: "Merge Failed",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func deleteSelectedAlbums() {
        isPerformingAlbumOperation = true
        defer { isPerformingAlbumOperation = false }
        do {
            try store.deleteAlbums(selectedAlbums())
            endSelection()
        } catch {
            operationAlert = GalleryOperationAlert(
                title: "Delete Failed",
                message: error.localizedDescription
            )
        }
    }

    private func endSelection() {
        isSelectingAlbums = false
        selectedAlbumIDs.removeAll()
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

                    if session.wasMerged {
                        Text("Merged")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.purple.opacity(0.12), in: Capsule())
                    }
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

private struct GalleryOperationAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
