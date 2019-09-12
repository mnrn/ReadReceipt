//
//  Camera.swift
//  ReadReciept
//
//  Created by n on 2019/09/12.
//  Copyright © 2019 n. All rights reserved.
//

import UIKit
import AVFoundation

class Camera {
    let photoOutput = AVCapturePhotoOutput()

    func findDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        let devices = deviceDiscoverySession.devices
        return devices.first(where: { $0.position == position})
    }

    func createPreviewLayer(session: AVCaptureSession, device: AVCaptureDevice) throws -> AVCaptureVideoPreviewLayer {
        let captureDeviceInput = try AVCaptureDeviceInput(device: device)
        session.addInput(captureDeviceInput)
        photoOutput.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])], completionHandler: nil)
        session.addOutput(photoOutput)
        return AVCaptureVideoPreviewLayer(session: session)
    }

    func takePhoto(settings: AVCapturePhotoSettings, delegate: AVCapturePhotoCaptureDelegate) {
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }
}
