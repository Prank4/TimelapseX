//
//  SessionDetailView.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import SwiftUI

struct SessionDetailView: View {
    let session: SessionRecord
    @ObservedObject var store: SessionStore

    @StateObject private var saveAction: PhotosSaveAction
    @State private var showDiscardConfirm = false
    @State private var discardError: String?
    @State private var frameURLs: [URL] = []

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    init(session: SessionRecord, store: SessionStore) {
        self.session = session
        self.store = store
        self._saveAction = StateObject(wrappedValue: PhotosSaveAction(store: store))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header card
                sessionHeader
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                if frameURLs.isEmpty {
                    emptyState
                } else {
                    // Thumbnail grid
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(frameURLs, id: \.self) { url in
                            FrameThumbnail(url: url)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .navigationTitle(session.id)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .tabBar)
        .alert("Discard Session?", isPresented: $showDiscardConfirm) {
            Button("Discard", role: .destructive) { performDiscard() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All \(frameURLs.count) frame\(frameURLs.count == 1 ? "" : "s") will be permanently deleted. This cannot be undone.")
        }
        .alert("Error", isPresented: Binding(get: { discardError != nil }, set: { if !$0 { discardError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(discardError ?? "")
        }
        .onAppear { loadFrameURLs() }
        // Re-read the session from the store so status updates (e.g. after Save) reflect live
        .onChange(of: store.allSessions) { _, _ in loadFrameURLs() }
    }

    // MARK: - Subviews

    private var sessionHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Label("\(frameURLs.count) frame\(frameURLs.count == 1 ? "" : "s")", systemImage: "photo.stack")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            statusBadge
        }
    }

    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            // Read the live status from the store, fall back to the snapshot
            let live = store.allSessions.first(where: { $0.id == session.id })?.status ?? session.status
            switch live {
            case .active:    return ("Active", .blue)
            case .saved:     return ("Saved", .green)
            case .discarded: return ("Discarded", .gray)
            }
        }()

        return Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("No frames captured yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    @ViewBuilder
    private var actionBar: some View {
        let liveStatus = store.allSessions.first(where: { $0.id == session.id })?.status ?? session.status

        if liveStatus == .active && !frameURLs.isEmpty {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    // Discard
                    Button(role: .destructive) {
                        showDiscardConfirm = true
                    } label: {
                        Text("Discard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    // Save
                    Button {
                        Task { await saveAction.save(session: session) }
                    } label: {
                        Group {
                            if case .saving = saveAction.state {
                                ProgressView()
                            } else {
                                Text("Save to Photos")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(saveAction.state == .saving)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
        } else if liveStatus == .saved {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Saved to Photos")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
        }
    }

    // MARK: - Actions

    private func performDiscard() {
        do {
            try store.discardSession(session)
        } catch {
            discardError = error.localizedDescription
        }
    }

    private func loadFrameURLs() {
        let liveSession = store.allSessions.first(where: { $0.id == session.id }) ?? session
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: liveSession.folderURL,
            includingPropertiesForKeys: nil
        )) ?? []
        frameURLs = contents
            .filter { $0.lastPathComponent.hasPrefix("IMG_") && $0.pathExtension.lowercased() == "jpg" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: session.createdAt)
    }
}

// MARK: - FrameThumbnail

private struct FrameThumbnail: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.systemGray5)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task { await loadImage() }
    }

    private func loadImage() async {
        guard image == nil else { return }
        let url = url
        let loaded = await Task.detached(priority: .userInitiated) {
            UIImage(contentsOfFile: url.path)
        }.value
        await MainActor.run { image = loaded }
    }
}
