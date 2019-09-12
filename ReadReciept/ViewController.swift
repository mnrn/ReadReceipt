//
//  ViewController.swift
//  ReadReciept
//
//  Created by mnrn on 2019/09/06.
//  Copyright © 2019 mnrn. All rights reserved.
//

import UIKit
import AVFoundation
import SwiftyJSON
import Alamofire

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - Properties

    let camera = Camera()
    var googleURL: URL {
        let env = ProcessInfo.processInfo.environment
        let googleAPIKey = env["GOOGLE_API_KEY"]!
        return URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(googleAPIKey)")!
    }
    @IBOutlet weak var cameraButton: UIButton!

    // MARK: - Actions

    @IBAction func cameraButtonTouchUpInside(_ sender: Any) {
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
            let session = try createCameraLayer()
            session.startRunning()
            setupCameraButtonStyle()
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

    private func setupCameraButtonStyle() {
        cameraButton.layer.borderColor = UIColor.white.cgColor
        cameraButton.layer.borderWidth = 5
        cameraButton.clipsToBounds = true
        cameraButton.layer.cornerRadius = min(cameraButton.frame.width, cameraButton.frame.height)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
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
                "image": [
                    "content": imageBase64
                ],
                "features": [
                    [
                        "type": "TEXT_DETECTION",
                        "maxResults": 1
                    ]
                ]
            ]
        ]

        // Run the request on a background thread
        DispatchQueue.global().async {
            Alamofire.request(self.googleURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
                switch response.result {
                case .success:
                    self.analyzeResults(response.data!)
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
        // Update UI on the main thread
        DispatchQueue.main.async(execute: {
            // Check for errors
            do {
                // Use SwiftyJSON to parse results
                let json = try JSON(data: dataToParse)

                // Parse the response
                let responses: JSON = json["responses"][0]

                // Get label annotations
                let textAnnotations: JSON = responses["textAnnotations"]
                let numTexts: Int = textAnnotations.count
                var texts: [String] = []
                if numTexts > 0 {
                    var textResultsText: String = "Texts found: "
                    for index in 0..<numTexts {
                        let text = textAnnotations[index]["description"].stringValue
                        texts.append(text)
                    }
                    for text in texts {
                        // if it's not the last item add a comma
                        if texts[texts.count - 1] != text {
                            textResultsText += "\(text), "
                        } else {
                            textResultsText += "\(text)"
                        }
                    }
                    print(textResultsText)
                } else {
                    print("No texts detected.")
                }
            } catch {
                print(error)
            }
        })
    }
}
