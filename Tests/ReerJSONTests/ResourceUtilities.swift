//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//

#if canImport(Glibc)
@preconcurrency import Glibc
#endif

import Foundation

// Always compiled into the Tests project
final internal class Canary { }

func testData(forResource resource: String, withExtension ext: String, subdirectory: String? = nil) -> Data? {
//    guard let url = Bundle(for: Canary.self).url(forResource: resource, withExtension: ext, subdirectory: subdirectory) else {
//        return nil
//    }
//    return try? Data(contentsOf: url)
//    
    return ReerJSONTests().dataFromFile("Resources/\(subdirectory == nil ? "" : subdirectory! + "/")\(resource).\(ext)")
}
