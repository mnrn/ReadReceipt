//
//  ImageUtil.swift
//  ReadReciept
//
//  Created by mnrn on 2019/09/12.
//  Copyright © 2019 mnrn. All rights reserved.
//

import UIKit

func resizeImage(_ imageSize: CGSize, image: UIImage) -> Data {
  UIGraphicsBeginImageContext(imageSize)
  image.draw(in: CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
  let newImage = UIGraphicsGetImageFromCurrentImageContext()
  let resizedImage = newImage!.pngData()
  UIGraphicsEndImageContext()
  return resizedImage!
}

func base64EncodeImage(_ image: UIImage) -> String {
  var imagedata = image.pngData()

  // Resize the image if it exceeds the 2MB API limit
  if imagedata?.count ?? 0 > 2_097_152 {
    let oldSize: CGSize = image.size
    let newSize: CGSize = CGSize(width: 800, height: oldSize.height / oldSize.width * 800)
    imagedata = resizeImage(newSize, image: image)
  }

  return imagedata!.base64EncodedString(options: .endLineWithCarriageReturn)
}
