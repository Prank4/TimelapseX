//
//  CameraPreviewView.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        configurePortraitRotation(on: view.previewLayer.connection)
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.session = session
        uiView.previewLayer.videoGravity = .resizeAspect
        configurePortraitRotation(on: uiView.previewLayer.connection)
    }

    private func configurePortraitRotation(on connection: AVCaptureConnection?) {
        let portraitRotationAngle: CGFloat = 90
        guard let connection,
              connection.isVideoRotationAngleSupported(portraitRotationAngle) else { return }
        connection.videoRotationAngle = portraitRotationAngle
    }
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
