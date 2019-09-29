//
//  ViewController.swift
//  ReadReceipt
//
//  Created by mnrn on 2019/09/06.
//  Copyright © 2019 mnrn. All rights reserved.
//

import Alamofire
import AVFoundation
import SwiftyJSON
import UIKit
import Firebase

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  // MARK: - Properties

  let camera = Camera()
  var googleURL: URL {
    let env = ProcessInfo.processInfo.environment
    let googleAPIKey = env["GOOGLE_API_KEY"]!
    return URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(googleAPIKey)")!
  }

  @IBOutlet var cameraButton: UIButton!

  // MARK: - Actions

  @IBAction func cameraButtonTouchUpInside(_: Any) {
    let settings = AVCapturePhotoSettings()
    settings.flashMode = .auto
    settings.isAutoStillImageStabilizationEnabled = true
    camera.takePhoto(settings: settings, delegate: self as AVCapturePhotoCaptureDelegate)
  }

  // MARK: - View Life Cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    do {
      setupLineLayer()
      let session = try createCameraLayer()
      session.startRunning()
      try setupCameraButtonStyle()
    } catch {
      print(error)
    }
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: - Configuration

  private func createCameraLayer() throws -> AVCaptureSession {
    let device = camera.findDevice(position: .back)
    let session = AVCaptureSession()
    let previewLayer = try camera.createPreviewLayer(session: session, device: device!)
    previewLayer.videoGravity = .resizeAspectFill
    previewLayer.connection?.videoOrientation = .portrait
    previewLayer.frame = view.frame
    view.layer.insertSublayer(previewLayer, at: 0)
    return session
  }

  private func setupCameraButtonStyle() throws {
    cameraButton.frame = CGRect(x: 0, y: 0, width: 100, height: 75)
    cameraButton.layer.position = CGPoint(x: view.frame.width / 2, y: view.frame.height - 50)
    view.layer.addSublayer(cameraButton.layer)
    if let path = Bundle.main.path(forResource: "kaden_camera_compact", ofType: "png") {
      let image = UIImage(contentsOfFile: path)
      cameraButton.setImage(image, for: .normal)
    } else {
      fatalError("image not found")
    }
  }

  private func setupLineLayer() {
    let linePath = UIBezierPath()
    linePath.move(to: CGPoint(x: 0, y: view.frame.height - 50))
    linePath.addLine(to: CGPoint(x: view.frame.width, y: view.frame.height - 50))
    let lineLayer = CAShapeLayer()
    lineLayer.path = linePath.cgPath
    lineLayer.strokeColor = UIColor(red: 0.32, green: 0.32, blue: 0.32, alpha: 0.8).cgColor
    lineLayer.lineWidth = 100
    view.layer.addSublayer(lineLayer)
  }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension ViewController: AVCapturePhotoCaptureDelegate {
  func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error _: Error?) {
    if let imageData = photo.fileDataRepresentation() {
      let uiImage = UIImage(data: imageData)
      // Base64 encode the image and create the request
      let binaryImageData = base64EncodeImage(uiImage!)
      createRequest(with: binaryImageData)
    }
  }
}

// MARK: - Networking

extension ViewController {
  func createRequest(with imageBase64: String) {
    // Create our request headers
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "X-Ios-Bundle-Identifier": Bundle.main.bundleIdentifier ?? ""
    ]

    // Build our API request
    let parameters: [String: Any] = [
      "requests": [
        "image": ["content": imageBase64],
        "features": [["type": "TEXT_DETECTION", "maxResults": 1]]
      ]
    ]

    // Run the request on a background thread
    DispatchQueue.global().async {
      Alamofire.request(self.googleURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
        .responseJSON { response in
          switch response.result {
          case .success:
            guard let data = response.data else { return }
            self.analyzeResults(data)
          case let .failure(error):
            print(error)
          }
        }
    }
  }
}

// MARK: - Analyze Response

extension ViewController {
  func analyzeResults(_ dataToParse: Data) {

    // Use SwiftyJSON to parse results
    guard let json = try? JSON(data: dataToParse) else {
      return
    }

    print(json)

    // Update UI on the main thread
    DispatchQueue.main.async {}

    // Send analyzed data to Firebase database.
    if let data = json.dictionaryObject {
      Database.database()
        .reference()
        .child("read-reciept")
        .childByAutoId()
        .setValue(data)
    }
  }
}
