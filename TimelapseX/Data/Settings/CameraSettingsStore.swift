//
//  CameraSettingsStore.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import AVFoundation
import Combine
import Photos
import SwiftUI

enum LensOverride: String, Codable, CaseIterable {
    case auto
    case wide
    case ultraWide
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .wide: return "Wide"
        case .ultraWide: return "Ultra-Wide"
        }
    }
}

enum QualityMode: String, Codable, CaseIterable {
    case bestQuality
    case fastestCapture
    
    var displayName: String {
        switch self {
        case .bestQuality: return "Best Quality"
        case .fastestCapture: return "Fastest Capture"
        }
    }
}

enum GridOverlay: String, Codable, CaseIterable {
    case off
    case ruleOfThirds
    case centerCross
    
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .ruleOfThirds: return "Rule of Thirds"
        case .centerCross: return "Center Cross"
        }
    }
}

final class CameraSettingsStore: ObservableObject {
    static let shared = CameraSettingsStore()
    static let minimumIntervalCaptureSeconds = 0.01
    static let maximumIntervalCaptureSeconds = 60.0
    
    @Published var lensOverride: LensOverride {
        didSet {
            UserDefaults.standard.set(lensOverride.rawValue, forKey: "settings.lensOverride")
            // Lens-change interaction: auto-drop both locks to continuous when lens override changes, and reflect that in the UI
            exposureFocusLocked = false
            whiteBalanceLocked = false
        }
    }
    
    @Published var qualityMode: QualityMode {
        didSet {
            UserDefaults.standard.set(qualityMode.rawValue, forKey: "settings.qualityMode")
        }
    }
    
    @Published var gridOverlay: GridOverlay {
        didSet {
            UserDefaults.standard.set(gridOverlay.rawValue, forKey: "settings.gridOverlay")
        }
    }
    
    @Published var exposureFocusLocked: Bool {
        didSet {
            UserDefaults.standard.set(exposureFocusLocked, forKey: "settings.exposureFocusLocked")
        }
    }
    
    @Published var whiteBalanceLocked: Bool {
        didSet {
            UserDefaults.standard.set(whiteBalanceLocked, forKey: "settings.whiteBalanceLocked")
        }
    }

    @Published var intervalCaptureEnabled: Bool {
        didSet {
            UserDefaults.standard.set(intervalCaptureEnabled, forKey: "settings.intervalCaptureEnabled")
        }
    }

    @Published var intervalCaptureSeconds: Double {
        didSet {
            UserDefaults.standard.set(Self.clampedIntervalCaptureSeconds(intervalCaptureSeconds), forKey: "settings.intervalCaptureSeconds")
        }
    }

    @Published var automaticSessionRotationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(automaticSessionRotationEnabled, forKey: "settings.automaticSessionRotationEnabled")
        }
    }

    @Published var sessionInactivityMinutes: Double {
        didSet {
            UserDefaults.standard.set(
                SessionRotationPolicy.clampedInactivityMinutes(sessionInactivityMinutes),
                forKey: "settings.sessionInactivityMinutes"
            )
        }
    }

    @Published var latestPhotoPreviewEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                latestPhotoPreviewEnabled,
                forKey: "settings.latestPhotoPreviewEnabled"
            )
        }
    }

    @Published var latestPhotoPreviewDurationSeconds: Double {
        didSet {
            UserDefaults.standard.set(
                LatestPhotoPreviewPolicy.clampedDuration(latestPhotoPreviewDurationSeconds),
                forKey: "settings.latestPhotoPreviewDurationSeconds"
            )
        }
    }
    
    @Published var cameraPermissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var photosPermissionStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    
    var isUltraWideSupported: Bool {
        AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
    }
    
    private init() {
        self.lensOverride = (UserDefaults.standard.string(forKey: "settings.lensOverride").flatMap(LensOverride.init)) ?? .auto
        self.qualityMode = (UserDefaults.standard.string(forKey: "settings.qualityMode").flatMap(QualityMode.init)) ?? .bestQuality
        self.gridOverlay = (UserDefaults.standard.string(forKey: "settings.gridOverlay").flatMap(GridOverlay.init)) ?? .off
        self.exposureFocusLocked = UserDefaults.standard.bool(forKey: "settings.exposureFocusLocked")
        self.whiteBalanceLocked = UserDefaults.standard.bool(forKey: "settings.whiteBalanceLocked")
        self.intervalCaptureEnabled = UserDefaults.standard.bool(forKey: "settings.intervalCaptureEnabled")
        let savedInterval = UserDefaults.standard.object(forKey: "settings.intervalCaptureSeconds") as? Double
        self.intervalCaptureSeconds = Self.clampedIntervalCaptureSeconds(savedInterval ?? 2.0)
        self.automaticSessionRotationEnabled = (
            UserDefaults.standard.object(forKey: "settings.automaticSessionRotationEnabled") as? Bool
        ) ?? true
        let savedInactivityMinutes = UserDefaults.standard.object(
            forKey: "settings.sessionInactivityMinutes"
        ) as? Double
        self.sessionInactivityMinutes = SessionRotationPolicy.clampedInactivityMinutes(
            savedInactivityMinutes ?? SessionRotationPolicy.defaultInactivityMinutes
        )
        self.latestPhotoPreviewEnabled = (
            UserDefaults.standard.object(forKey: "settings.latestPhotoPreviewEnabled") as? Bool
        ) ?? true
        let savedPreviewDuration = UserDefaults.standard.object(
            forKey: "settings.latestPhotoPreviewDurationSeconds"
        ) as? Double
        self.latestPhotoPreviewDurationSeconds = LatestPhotoPreviewPolicy.clampedDuration(
            savedPreviewDuration ?? LatestPhotoPreviewPolicy.defaultDuration
        )
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPermissions()
        }
    }
    
    func refreshPermissions() {
        let currentCameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let currentPhotosStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        if cameraPermissionStatus != currentCameraStatus {
            cameraPermissionStatus = currentCameraStatus
        }

        if photosPermissionStatus != currentPhotosStatus {
            photosPermissionStatus = currentPhotosStatus
        }
    }

    static func clampedIntervalCaptureSeconds(_ value: Double) -> Double {
        min(max(value, minimumIntervalCaptureSeconds), maximumIntervalCaptureSeconds)
    }
}
