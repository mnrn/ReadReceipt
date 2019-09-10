//
//  ViewController.swift
//  ReadReciept
//
//  Created by mnrn on 2019/09/06.
//  Copyright © 2019 mnrn. All rights reserved.
//

import UIKit
import SwiftyJSON

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let imagePicker = UIImagePickerController()
    let session = URLSession.shared

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var textResults: UITextView!

    var googleURL: URL {
        let env = ProcessInfo.processInfo.environment
        let googleAPIKey = env["GOOGLE_API_KEY"]!
        return URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(googleAPIKey)")!
    }

    @IBAction func loadImageButtonTapped(_ sender: UIButton) {
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary

        present(imagePicker, animated: true, completion: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        imagePicker.delegate = self
        textResults.isHidden = true
        spinner.hidesWhenStopped = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

/// Image processing

extension ViewController {

    func analyzeResults(_ dataToParse: Data) {

        // Update UI on the main thread
        DispatchQueue.main.async(execute: {

            self.spinner.stopAnimating()
            self.imageView.isHidden = true
            self.textResults.isHidden = false

            // Check for errors
            do {
                // Use SwiftyJSON to parse results
                let json = try JSON(data: dataToParse)

                // Parse the response
                print(json)
                let responses: JSON = json["responses"][0]

                // Get label annotations
                let textAnnotations: JSON = responses["labelAnnotations"]
                let numTexts: Int = textAnnotations.count
                var texts: [String] = []
                if numTexts > 0 {
                    var textResultsText: String = "Labels found: "
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
                    self.textResults.text = textResultsText
                } else {
                    self.textResults.text = "No labels found"
                }
            } catch let error {
                self.textResults.text = "Error \(error)"
            }
        })

    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let pickedImage = info[.originalImage] as? UIImage {
            imageView.contentMode = .scaleAspectFit
            imageView.isHidden = true // You could optionally display the image here by setting imageView.image = pickedImage
            spinner.startAnimating()
            textResults.isHidden = true

            // Base64 encode the image and create the request
            let binaryImageData = base64EncodeImage(pickedImage)
            createRequest(with: binaryImageData)
        }

        dismiss(animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

    func resizeImage(_ imageSize: CGSize, image: UIImage) -> Data {
        UIGraphicsBeginImageContext(imageSize)
        image.draw(in: CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        let resizedImage = newImage!.pngData()
        UIGraphicsEndImageContext()
        return resizedImage!
    }
}

/// Networking

extension ViewController {
    func base64EncodeImage(_ image: UIImage) -> String {
        var imagedata = image.pngData()

        // Resize the image if it exceeds the 2MB API limit
        if imagedata?.count ?? 0 > 2097152 {
            let oldSize: CGSize = image.size
            let newSize: CGSize = CGSize(width: 800, height: oldSize.height / oldSize.width * 800)
            imagedata = resizeImage(newSize, image: image)
        }

        return imagedata!.base64EncodedString(options: .endLineWithCarriageReturn)
    }

    func createRequest(with imageBase64: String) {
        // Create our request URL

        var request = URLRequest(url: googleURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "X-Ios-Bundle-Identifier")

        // Build our API request
        let jsonRequest = [
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

        // Serialize the JSON
        let jsonObject = JSON(jsonRequest)
        guard let data = try? jsonObject.rawData() else {
            return
        }

        request.httpBody = data

        // Run the request on a background thread
        DispatchQueue.global().async { self.runRequestOnBackgroundThread(request) }
    }

    func runRequestOnBackgroundThread(_ request: URLRequest) {
        // run the request

        let task: URLSessionDataTask = session.dataTask(with: request) { (data, _, error) in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "")
                return
            }

            self.analyzeResults(data)
        }

        task.resume()
    }
}
