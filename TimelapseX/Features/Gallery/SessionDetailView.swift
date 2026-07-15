//
//  SessionDetailView.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import SwiftUI
import Combine
import Photos
import AVKit
import UIKit

struct SessionDetailView: View {
    let session: SessionRecord
    @ObservedObject var store: SessionStore

    @Environment(\.dismiss) private var dismiss
    @StateObject private var saveAction: PhotosSaveAction
    @StateObject private var exporter = TimelapseExporter()

    @State private var exportSettings = TimelapseExportSettings()
    @State private var showDiscardConfirm = false
    @State private var showFrameDeleteConfirm = false
    @State private var operationAlert: SessionOperationAlert?
    
    @State private var discardError: String?
    @State private var frameDeleteError: String?
    @State private var frameURLs: [URL] = []
    @State private var exportedVideoURL: URL?
    @State private var videoSaveState: VideoSaveState = .idle
    @State private var selectedFrameIndex: Int?
    @State private var isSelectingFrames = false
    @State private var selectedFrameURLs: Set<URL> = []
    @State private var deletedFrame: DeletedFrame?
    @State private var frameDurationText = ""
    @State private var showTimelapseSettings = false
    @FocusState private var durationFieldFocused: Bool

    enum VideoSaveState: Equatable {
        case idle, saving, success, failed(String)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    init(session: SessionRecord, store: SessionStore) {
        self.session = session
        self.store = store
        self._saveAction = StateObject(wrappedValue: PhotosSaveAction(store: store))
    }

    var body: some View {
        mainContent
            .navigationTitle(session.id)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .tabBar)
            .toolbar {
                sessionToolbar
            }
            .alert("Delete Session?", isPresented: $showDiscardConfirm) {
                Button("Delete", role: .destructive) { performDiscard() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All \(frameURLs.count) frame\(frameURLs.count == 1 ? "" : "s") will be permanently deleted. This cannot be undone.")
            }
            .alert("Delete Selected Photos?", isPresented: $showFrameDeleteConfirm) {
                Button("Delete \(selectedFrameURLs.count)", role: .destructive) {
                    deleteSelectedFrames()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The selected \(selectedFrameURLs.count) photo\(selectedFrameURLs.count == 1 ? "" : "s") will be permanently deleted. This cannot be undone.")
            }
            .alert("Error", isPresented: Binding(get: { discardError != nil }, set: { if !$0 { discardError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(discardError ?? "")
            }
            .alert("Delete Failed", isPresented: Binding(get: { frameDeleteError != nil }, set: { if !$0 { frameDeleteError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(frameDeleteError ?? "")
            }
            .alert(item: $operationAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                syncExportSettingsFromSession()
                loadFrameURLs()
                checkExportedVideo()
            }
            .onChange(of: store.allSessions) { _, _ in
                syncExportSettingsFromSession(updateText: !durationFieldFocused)
                loadFrameURLs()
                checkExportedVideo()
            }
            .onChange(of: exporter.state) { _, newValue in
                handleExporterStateChange(newValue)
            }
            .onChange(of: saveAction.state) { _, newValue in
                handleSessionSaveStateChange(newValue)
            }
            .sheet(isPresented: $showTimelapseSettings) {
                timelapseSettingsSheet
            }
            .fullScreenCover(isPresented: framePagerPresentedBinding) {
                FramePagerView(
                    frameURLs: $frameURLs,
                    initialIndex: selectedFrameIndex ?? 0,
                    deletedFrame: $deletedFrame,
                    deleteErrorMessage: $frameDeleteError,
                    onDelete: deleteFrame,
                    onUndoDelete: undoDeletedFrame
                )
            }
            .overlay(alignment: .bottom) {
                undoBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            .safeAreaInset(edge: .bottom) {
                selectionActionBar
            }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                sessionHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 6)

                if let exportProgress {
                    ExportProgressCard(progress: exportProgress)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }

                if let exportedVideoURL {
                    TimelapseVideoCard(
                        url: exportedVideoURL,
                        videoSaveState: videoSaveState,
                        onSave: {
                            Task { await saveVideoToPhotos(url: exportedVideoURL) }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                }

                if frameURLs.isEmpty {
                    emptyState
                } else {
                    framesGrid
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var sessionToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(isSelectingFrames ? "Cancel" : "Select") {
                if isSelectingFrames {
                    endFrameSelection()
                } else {
                    isSelectingFrames = true
                    deletedFrame = nil
                }
            }
            .disabled(frameURLs.isEmpty || isExporting)
        }

        if !isSelectingFrames {
            ToolbarItem(placement: .topBarTrailing) {
                sessionActionsMenu
            }
        }
    }

    private var framePagerPresentedBinding: Binding<Bool> {
        Binding(
            get: { selectedFrameIndex != nil },
            set: { isPresented in
                if !isPresented {
                    selectedFrameIndex = nil
                }
            }
        )
    }

    private var sessionActionsMenu: some View {
        let liveStatus = store.allSessions.first(where: { $0.id == session.id })?.status ?? session.status

        return Menu {
            Button {
                showTimelapseSettings = true
            } label: {
                Label("Timelapse Settings", systemImage: "slider.horizontal.3")
            }
            .disabled(frameURLs.isEmpty || isExporting)

            Divider()

            if liveStatus == .active || liveStatus == .closed {
                Button {
                    Task { await saveAction.save(session: store.allSessions.first(where: { $0.id == session.id }) ?? session) }
                } label: {
                    Label("Save Session to Photos", systemImage: "photo.stack")
                }
                .disabled(frameURLs.isEmpty || saveAction.state == .saving || isExporting)
            }

            Button(role: .destructive) {
                showDiscardConfirm = true
            } label: {
                Label(liveStatus == .active ? "Discard Session" : "Delete Session", systemImage: "trash")
            }
            .disabled(isExporting)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Subviews

    private var framesGrid: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(frameURLs.enumerated()), id: \.element.absoluteString) { index, url in
                Button {
                    if isSelectingFrames {
                        toggleFrameSelection(url)
                    } else {
                        selectedFrameIndex = index
                    }
                } label: {
                    FrameThumbnail(url: url)
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            if selectedFrameURLs.contains(url) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.black.opacity(0.28))
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if isSelectingFrames {
                                Image(systemName: selectedFrameURLs.contains(url) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, selectedFrameURLs.contains(url) ? Color.blue : Color.black.opacity(0.45))
                                    .padding(5)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }

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
            case .closed:    return ("Closed", .orange)
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

    private var timelapseSettingsSheet: some View {
        NavigationStack {
            Form {
                Section("Timing") {
                    frameDurationControl
                }

                Section("Export") {
                    dropdownPicker(
                        title: "Resolution",
                        value: exportSettings.resolution.displayName
                    ) {
                        ForEach(TimelapseResolution.allCases) { option in
                            Button(option.displayName) {
                                exportSettings.resolution = option
                            }
                        }
                    }

                    dropdownPicker(
                        title: "Quality",
                        value: exportSettings.quality.displayName
                    ) {
                        ForEach(TimelapseQuality.allCases) { option in
                            Button(option.displayName) {
                                exportSettings.quality = option
                            }
                        }
                    }
                }

                Section {
                    Button("Create Timelapse") {
                        showTimelapseSettings = false
                        handleExportTap()
                    }
                    .disabled(frameURLs.isEmpty || isExporting)
                }
            }
            .navigationTitle("Timelapse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showTimelapseSettings = false
                    }
                }
            }
        }
    }

    private var frameDurationControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time Per Image")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(formattedFrameDuration(exportSettings.frameDurationSeconds)) • \(formattedFPS(exportSettings.effectiveFPS)) fps")
                        .font(.subheadline.weight(.medium))
                }
                Spacer()
                TextField("0.01", text: $frameDurationText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 86)
                    .focused($durationFieldFocused)
                    .onSubmit(commitFrameDurationText)
                    .onChange(of: frameDurationText) { _, newValue in
                        updateFrameDurationFromText(newValue)
                    }
                    .onChange(of: durationFieldFocused) { _, isFocused in
                        if !isFocused {
                            commitFrameDurationText()
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                durationFieldFocused = false
                            }
                        }
                    }
            }

            Slider(
                value: Binding(
                    get: { exportSettings.frameDurationSeconds },
                    set: { updateFrameDuration($0, updateText: true) }
                ),
                in: SessionRecord.minimumFrameDurationSeconds...SessionRecord.maximumFrameDurationSeconds,
                step: 0.01
            )
        }
    }

    private func dropdownPicker<Content: View>(
        title: String,
        value: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Menu {
                content()
            } label: {
                HStack(spacing: 6) {
                    Text(value)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private var undoBanner: some View {
        if let deletedFrame {
            HStack(spacing: 12) {
                Text("Frame deleted")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button("Undo") {
                    undoDeletedFrame(deletedFrame)
                }
                .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.black.opacity(0.88), in: Capsule())
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var selectionActionBar: some View {
        if isSelectingFrames {
            HStack {
                Text("\(selectedFrameURLs.count) selected")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button(role: .destructive) {
                    showFrameDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedFrameURLs.isEmpty)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    private var isExporting: Bool {
        if case .exporting = exporter.state {
            return true
        }
        return false
    }

    private var exportProgress: Double? {
        if case .exporting(let progress) = exporter.state {
            return progress
        }
        return nil
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

    // MARK: - Actions

    private func handleExportTap() {
        let liveSession = store.allSessions.first(where: { $0.id == session.id }) ?? session
        exportedVideoURL = nil
        videoSaveState = .idle
        Task {
            await exporter.export(session: liveSession, settings: exportSettings)
        }
    }

    private func syncExportSettingsFromSession(updateText: Bool = true) {
        let liveSession = store.allSessions.first(where: { $0.id == session.id }) ?? session
        let duration = SessionRecord.clampedFrameDuration(liveSession.frameDurationSeconds)
        exportSettings.frameDurationSeconds = duration
        if updateText {
            frameDurationText = formattedDurationInput(duration)
        }
    }

    private func updateFrameDuration(_ duration: Double, updateText: Bool) {
        let clamped = SessionRecord.clampedFrameDuration(duration)
        exportSettings.frameDurationSeconds = clamped
        if updateText {
            frameDurationText = formattedDurationInput(clamped)
        }

        let liveSession = store.allSessions.first(where: { $0.id == session.id }) ?? session
        try? store.updateFrameDurationSeconds(clamped, for: liveSession)
    }

    private func commitFrameDurationText() {
        let sanitized = frameDurationText.replacingOccurrences(of: ",", with: ".")
        guard let duration = Double(sanitized) else {
            frameDurationText = formattedDurationInput(exportSettings.frameDurationSeconds)
            return
        }
        updateFrameDuration(duration, updateText: true)
    }

    private func updateFrameDurationFromText(_ text: String) {
        guard durationFieldFocused else { return }
        let sanitized = text.replacingOccurrences(of: ",", with: ".")
        guard let duration = Double(sanitized) else { return }
        updateFrameDuration(duration, updateText: false)
    }

    private func deleteFrame(_ url: URL) -> DeletedFrame? {
        guard let index = frameURLs.firstIndex(of: url) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let liveSession = store.allSessions.first(where: { $0.id == session.id }) ?? session
            try store.deleteFrame(at: url, in: liveSession)
            guard !FileManager.default.fileExists(atPath: url.path) else {
                throw NSError(
                    domain: "TimelapseX.SessionDetailView",
                    code: 301,
                    userInfo: [NSLocalizedDescriptionKey: "The frame could not be removed from disk."]
                )
            }
            let deleted = DeletedFrame(url: url, data: data, index: index)
            deletedFrame = deleted
            invalidateExportedVideo(for: liveSession)
            loadFrameURLs()
            checkExportedVideo()
            return deleted
        } catch {
            frameDeleteError = error.localizedDescription
            return nil
        }
    }

    private func toggleFrameSelection(_ url: URL) {
        if selectedFrameURLs.contains(url) {
            selectedFrameURLs.remove(url)
        } else {
            selectedFrameURLs.insert(url)
        }
    }

    private func endFrameSelection() {
        isSelectingFrames = false
        selectedFrameURLs.removeAll()
    }

    private func deleteSelectedFrames() {
        let urls = Array(selectedFrameURLs)
        guard !urls.isEmpty else { return }

        do {
            let liveSession = store.allSessions.first(where: { $0.id == session.id }) ?? session
            try store.deleteFrames(at: urls, in: liveSession)
            deletedFrame = nil
            endFrameSelection()
            invalidateExportedVideo(for: liveSession)
            loadFrameURLs()
            checkExportedVideo()
        } catch {
            frameDeleteError = error.localizedDescription
        }
    }

    private func undoDeletedFrame(_ frame: DeletedFrame) {
        do {
            try frame.data.write(to: frame.url, options: .atomic)
            let liveSession = store.allSessions.first(where: { $0.id == session.id }) ?? session
            invalidateExportedVideo(for: liveSession)
            deletedFrame = nil
            loadFrameURLs()
            checkExportedVideo()
        } catch {
            frameDeleteError = error.localizedDescription
        }
    }

    private func handleExporterStateChange(_ state: TimelapseExporter.ExportState) {
        switch state {
        case .success:
            checkExportedVideo()
            exporter.reset()
            operationAlert = SessionOperationAlert(
                title: "Success",
                message: "Timelapse video compiled successfully and is ready to save."
            )
        case .failed(let message):
            exporter.reset()
            operationAlert = SessionOperationAlert(
                title: "Export Failed",
                message: message
            )
        default:
            break
        }
    }

    private func handleSessionSaveStateChange(_ state: PhotosSaveAction.SaveState) {
        if case .failed(let message) = state {
            saveAction.reset()
            operationAlert = SessionOperationAlert(
                title: "Save Failed",
                message: message
            )
        }
    }

    private func performDiscard() {
        do {
            let liveSession = store.allSessions.first(where: { $0.id == session.id }) ?? session
            try store.discardSession(liveSession)
            dismiss()
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
        selectedFrameURLs.formIntersection(frameURLs)
        if frameURLs.isEmpty {
            endFrameSelection()
        }
    }

    private func checkExportedVideo() {
        let liveSession = store.allSessions.first(where: { $0.id == session.id }) ?? session
        let sourceURL = liveSession.folderURL.appendingPathComponent("timelapse.mp4")
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            exportedVideoURL = sourceURL
        } else {
            exportedVideoURL = nil
        }
    }

    private func invalidateExportedVideo(for session: SessionRecord) {
        let sourceURL = session.folderURL.appendingPathComponent("timelapse.mp4")
        try? FileManager.default.removeItem(at: sourceURL)
        exportedVideoURL = nil
        videoSaveState = .idle
        exporter.reset()
    }

    private func saveVideoToPhotos(url: URL) async {
        guard videoSaveState == .idle else { return }
        videoSaveState = .saving

        guard FileManager.default.fileExists(atPath: url.path) else {
            failVideoSave("Video file not found at expected path.")
            return
        }

        // Re-check permission.
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            failVideoSave("Photos access denied.")
            return
        }

        let result = await CameraRollVideoSaver.saveVideo(at: url)

        switch result {
        case .success:
            videoSaveState = .success
            operationAlert = SessionOperationAlert(
                title: "Timelapse Saved",
                message: "The timelapse video was saved to Photos."
            )
        case .failure(let error):
            failVideoSave(error.localizedDescription)
        }
    }

    private func failVideoSave(_ message: String) {
        videoSaveState = .failed(message)
        operationAlert = SessionOperationAlert(
            title: "Save Timelapse Failed",
            message: message
        )
    }
 
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: session.createdAt)
    }

    private func formattedDurationInput(_ duration: Double) -> String {
        String(format: "%.2f", duration)
    }

    private func formattedFrameDuration(_ duration: Double) -> String {
        if duration < 1 {
            return "\(Int((duration * 1000).rounded())) ms"
        }
        return "\(String(format: "%.2f", duration)) s"
    }

    private func formattedFPS(_ fps: Double) -> String {
        if fps >= 10 {
            return String(format: "%.0f", fps)
        }
        return String(format: "%.1f", fps)
    }
}

private struct DeletedFrame: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let data: Data
    let index: Int
}

private struct SessionOperationAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
private final class CameraRollVideoSaver: NSObject {
    private static var activeSavers: [UUID: CameraRollVideoSaver] = [:]

    private let id = UUID()
    private var continuation: CheckedContinuation<Result<Void, Error>, Never>?

    static func saveVideo(at url: URL) async -> Result<Void, Error> {
        guard UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(url.path) else {
            return .failure(NSError(
                domain: "TimelapseX.VideoSave",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "This timelapse file is not compatible with Photos. Create the timelapse again to generate a Photos-compatible video, then save it."]
            ))
        }

        let saver = CameraRollVideoSaver()
        activeSavers[saver.id] = saver
        return await saver.save(url)
    }

    private func save(_ url: URL) async -> Result<Void, Error> {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            UISaveVideoAtPathToSavedPhotosAlbum(
                url.path,
                self,
                #selector(video(_:didFinishSavingWithError:contextInfo:)),
                nil
            )
        }
    }

    @objc private func video(
        _ videoPath: String,
        didFinishSavingWithError error: Error?,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        if let error {
            continuation?.resume(returning: .failure(error))
        } else {
            continuation?.resume(returning: .success(()))
        }
        continuation = nil
        Self.activeSavers[id] = nil
    }
}

private struct ExportProgressCard: View {
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Creating Timelapse", systemImage: "film")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct TimelapseVideoCard: View {
    let url: URL
    let videoSaveState: SessionDetailView.VideoSaveState
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Timelapse", systemImage: "play.rectangle.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VideoPlayer(player: AVPlayer(url: url))
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                Button {
                    onSave()
                } label: {
                    if videoSaveState == .saving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label(videoSaveState == .success ? "Saved" : "Save Video", systemImage: videoSaveState == .success ? "checkmark" : "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(videoSaveState == .saving || videoSaveState == .success)

                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - FramePagerView

private struct FramePagerView: View {
    @Binding var frameURLs: [URL]
    let initialIndex: Int
    @Binding var deletedFrame: DeletedFrame?
    @Binding var deleteErrorMessage: String?
    let onDelete: (URL) -> DeletedFrame?
    let onUndoDelete: (DeletedFrame) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int

    init(
        frameURLs: Binding<[URL]>,
        initialIndex: Int,
        deletedFrame: Binding<DeletedFrame?>,
        deleteErrorMessage: Binding<String?>,
        onDelete: @escaping (URL) -> DeletedFrame?,
        onUndoDelete: @escaping (DeletedFrame) -> Void
    ) {
        self._frameURLs = frameURLs
        self.initialIndex = initialIndex
        self._deletedFrame = deletedFrame
        self._deleteErrorMessage = deleteErrorMessage
        self.onDelete = onDelete
        self.onUndoDelete = onUndoDelete
        self._selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if frameURLs.isEmpty {
                emptyState
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(frameURLs.enumerated()), id: \.element.absoluteString) { index, url in
                        FullScreenFrameImage(url: url)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .ignoresSafeArea()
            }

            topControls
                .zIndex(1)
            bottomControls
                .zIndex(1)

            if let deletedFrame {
                undoBanner(deletedFrame)
                    .zIndex(2)
            }
        }
        .onChange(of: frameURLs) { _, urls in
            if urls.isEmpty {
                dismiss()
            } else if selectedIndex >= urls.count {
                selectedIndex = urls.count - 1
            }
        }
    }

    private var topControls: some View {
        VStack {
            HStack(spacing: 14) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                }

                Spacer()

                if !frameURLs.isEmpty {
                    Text("\(selectedIndex + 1) / \(frameURLs.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.45), in: Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var bottomControls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(role: .destructive) {
                    deleteSelectedFrame()
                } label: {
                    Image(systemName: "trash")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(.ultraThinMaterial, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(frameURLs.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .alert("Delete Failed", isPresented: Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "Unable to delete this frame.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 42))
            Text("No frames")
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.white.opacity(0.7))
    }

    private func undoBanner(_ frame: DeletedFrame) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Text("Frame deleted")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button("Undo") {
                    onUndoDelete(frame)
                }
                .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.black.opacity(0.88), in: Capsule())
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
    }

    private func deleteSelectedFrame() {
        guard frameURLs.indices.contains(selectedIndex) else { return }
        let nextIndex = min(selectedIndex, max(frameURLs.count - 2, 0))
        if onDelete(frameURLs[selectedIndex]) != nil {
            selectedIndex = nextIndex
        } else if deleteErrorMessage == nil {
            deleteErrorMessage = "Unable to delete this frame."
        }
    }
}

// MARK: - FullScreenFrameImage

private struct FullScreenFrameImage: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
