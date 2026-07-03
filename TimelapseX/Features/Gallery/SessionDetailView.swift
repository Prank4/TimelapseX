//
//  SessionDetailView.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import SwiftUI
import Combine
import Photos

struct SessionDetailView: View {
    let session: SessionRecord
    @ObservedObject var store: SessionStore

    @StateObject private var saveAction: PhotosSaveAction
    @StateObject private var exporter = TimelapseExporter()

    @State private var selectedFPS = 24
    @State private var showDiscardConfirm = false
    @State private var showSaveFirstAlert = false
    @State private var showExportSuccessAlert = false
    @State private var showExportErrorAlert = false
    
    @State private var discardError: String?
    @State private var exportErrorMessage = ""
    @State private var frameURLs: [URL] = []
    @State private var exportedVideoURL: URL?
    @State private var videoSaveState: VideoSaveState = .idle

    enum VideoSaveState: Equatable {
        case idle, saving, success, failed(String)
    }

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

                // Timelapse Export Section (only shown when session has frames)
                if !frameURLs.isEmpty {
                    timelapseExportSection
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }

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
        .alert("Save Session First", isPresented: $showSaveFirstAlert) {
            Button("Save to Photos") {
                Task {
                    let liveSession = store.allSessions.first(where: { $0.id == session.id }) ?? session
                    await saveAction.save(session: liveSession)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This session must be saved to Photos before you can export a timelapse. Would you like to save it now?")
        }
        .alert("Success", isPresented: $showExportSuccessAlert) {
            Button("OK", role: .cancel) { exporter.reset() }
        } message: {
            Text("Timelapse video compiled successfully at native resolution.")
        }
        .alert("Export Failed", isPresented: $showExportErrorAlert) {
            Button("OK", role: .cancel) { exporter.reset() }
        } message: {
            Text(exportErrorMessage)
        }
        .alert("Save Failed", isPresented: Binding(
            get: {
                if case .failed = saveAction.state { return true }
                return false
            },
            set: { _ in saveAction.reset() }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if case .failed(let message) = saveAction.state {
                Text(message)
            } else {
                Text("An unknown error occurred.")
            }
        }
        .onAppear {
            loadFrameURLs()
            checkExportedVideo()
        }
        .onChange(of: store.allSessions) { _, _ in
            loadFrameURLs()
            checkExportedVideo()
        }
        .onChange(of: exporter.state) { _, newValue in
            switch newValue {
            case .success:
                checkExportedVideo()
                showExportSuccessAlert = true
            case .failed(let message):
                exportErrorMessage = message
                showExportErrorAlert = true
            default:
                break
            }
        }
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

    private var timelapseExportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timelapse Export")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("FPS (Frames Per Second)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("FPS", selection: $selectedFPS) {
                    Text("12").tag(12)
                    Text("24").tag(24)
                    Text("30").tag(30)
                    Text("60").tag(60)
                }
                .pickerStyle(.segmented)
                .disabled(isExporting)
            }

            Button(action: handleExportTap) {
                Group {
                    if case .exporting(let progress) = exporter.state {
                        HStack(spacing: 12) {
                            ProgressView(value: progress)
                                .progressViewStyle(.linear)
                                .tint(.white)
                            Text("\(Int(progress * 100))%")
                                .font(.caption.weight(.semibold))
                        }
                    } else {
                        Text("Create Timelapse")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExporting)

            if let exportedVideoURL {
                HStack(spacing: 10) {
                    // Save directly to Photos from our app (more reliable than share sheet Save Video)
                    Button {
                        Task { await saveVideoToPhotos(url: exportedVideoURL) }
                    } label: {
                        Group {
                            if videoSaveState == .saving {
                                ProgressView().tint(.white)
                            } else if videoSaveState == .success {
                                Label("Saved!", systemImage: "checkmark")
                            } else {
                                Label("Save to Photos", systemImage: "square.and.arrow.down")
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(videoSaveState == .success ? .green : .blue)
                    .disabled(videoSaveState == .saving || videoSaveState == .success)

                    ShareLink(item: exportedVideoURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 44, height: 36)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var isExporting: Bool {
        if case .exporting = exporter.state {
            return true
        }
        return false
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
                    .disabled(isExporting)

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
                    .disabled(saveAction.state == .saving || isExporting)
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

    private func handleExportTap() {
        let liveSession = store.allSessions.first(where: { $0.id == session.id }) ?? session
        if liveSession.status != .saved {
            showSaveFirstAlert = true
        } else {
            Task {
                await exporter.export(session: liveSession, fps: selectedFPS)
            }
        }
    }

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

    private func checkExportedVideo() {
        let liveSession = store.allSessions.first(where: { $0.id == session.id }) ?? session
        let sourceURL = liveSession.folderURL.appendingPathComponent("timelapse.mp4")
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let destURL = tempDir.appendingPathComponent("\(session.id)_timelapse.mp4")
            try? FileManager.default.removeItem(at: destURL)
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                exportedVideoURL = destURL
            } catch {
                exportedVideoURL = sourceURL
            }
        } else {
            exportedVideoURL = nil
        }
    }

    private func saveVideoToPhotos(url: URL) async {
        guard videoSaveState == .idle else { return }
        videoSaveState = .saving

        guard FileManager.default.fileExists(atPath: url.path) else {
            videoSaveState = .failed("Video file not found at expected path.")
            return
        }

        // Re-check permission.
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            videoSaveState = .failed("Photos access denied.")
            return
        }

        let result: Result<Void, Error> = await Task.detached(priority: .userInitiated) {
            do {
                // Use the same modern API that works for photos — addResource with .video type.
                // PHAssetChangeRequest.creationRequestForAssetFromVideo is legacy and unreliable
                // on iOS 27 beta.
                try PHPhotoLibrary.shared().performChangesAndWait {
                    let req = PHAssetCreationRequest.forAsset()
                    let opts = PHAssetResourceCreationOptions()
                    opts.shouldMoveFile = false
                    req.addResource(with: .video, fileURL: url, options: opts)
                }
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success:
            videoSaveState = .success
        case .failure(let error):
            videoSaveState = .failed(error.localizedDescription)
        }
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
