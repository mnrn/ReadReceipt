//
//  Environment.swift
//  ReadReciept
//
//  Created by mnrn on 2019/09/12.
//  Copyright © 2019 mnrn. All rights reserved.
//

import Foundation

func setupEnviromentVariables(url: URL) throws {
  let data = try Data(contentsOf: url)
  let str = String(data: data, encoding: .utf8)!
  let clean = str.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
  _ = clean.components(separatedBy: "\n").map {
    $0.components(separatedBy: "=")
  }.filter {
    $0.count == 2
  }.map {
    setenv($0[0], $0[1], 1)
  }
}
