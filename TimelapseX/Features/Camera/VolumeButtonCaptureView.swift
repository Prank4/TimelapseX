//
//  VolumeButtonCaptureView.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

struct VolumeButtonCaptureView: UIViewRepresentable {
    let onVolumeButtonPress: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onVolumeButtonPress: onVolumeButtonPress)
    }

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: .zero)
        context.coordinator.attach(to: containerView)
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onVolumeButtonPress = onVolumeButtonPress
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        var onVolumeButtonPress: () -> Void
        private let audioSession = AVAudioSession.sharedInstance()
        private var observation: NSKeyValueObservation?
        private weak var volumeSlider: UISlider?
        private let targetVolume: Float = 0.5
        private var originalVolume: Float = 0.5
        private var isResettingVolume = false
        private var foregroundObserver: NSObjectProtocol?
        private weak var containerView: UIView?

        init(onVolumeButtonPress: @escaping () -> Void) {
            self.onVolumeButtonPress = onVolumeButtonPress
        }

        func attach(to containerView: UIView) {
            self.containerView = containerView

            let volumeView = MPVolumeView(frame: .zero)
            volumeView.frame = CGRect(x: -1000, y: -1000, width: 1, height: 1)
            volumeView.alpha = 0.0001
            volumeView.showsVolumeSlider = true
            containerView.addSubview(volumeView)

            volumeSlider = volumeView.subviews.compactMap { $0 as? UISlider }.first
            originalVolume = audioSession.outputVolume

            do {
                try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                try audioSession.setActive(true)
            } catch {
                return
            }

            observation = audioSession.observe(\.outputVolume, options: [.old, .new]) { [weak self] _, change in
                guard let self = self else { return }
                guard !self.isResettingVolume else {
                    self.isResettingVolume = false
                    return
                }

                guard let newVolume = change.newValue, let oldVolume = change.oldValue else {
                    return
                }

                if abs(newVolume - oldVolume) > 0.001 {
                    DispatchQueue.main.async {
                        self.onVolumeButtonPress()
                    }
                }

                self.restoreTargetVolume()
            }

            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main) { [weak self] _ in
                    guard let self = self, let containerView = self.containerView else { return }
                    self.reattach(to: containerView)
                }

            restoreTargetVolume()
        }

        func reattach(to containerView: UIView) {
            detach()
            attach(to: containerView)
        }

        func detach() {
            observation = nil

            if let foregroundObserver = foregroundObserver {
                NotificationCenter.default.removeObserver(foregroundObserver)
                self.foregroundObserver = nil
            }

            restoreOriginalVolume()
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            volumeSlider = nil
            containerView = nil
        }

        private func restoreTargetVolume() {
            setVolume(targetVolume)
        }

        private func restoreOriginalVolume() {
            setVolume(originalVolume)
        }

        private func setVolume(_ value: Float) {
            DispatchQueue.main.async {
                guard let volumeSlider = self.volumeSlider else { return }
                self.isResettingVolume = true
                volumeSlider.setValue(value, animated: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    self.isResettingVolume = false
                }
            }
        }

        deinit {
            detach()
        }
    }
}
