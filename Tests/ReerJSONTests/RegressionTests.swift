//
//  Copyright © 2026 reers.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import Testing
@testable import ReerJSON

@Suite("Regression")
struct RegressionTests {

    @Test func encoderOptionsAreReadUnderLock() throws {
        let encoder = ReerJSONEncoder()
        let key = CodingUserInfoKey(rawValue: "k")!
        nonisolated(unsafe) let unsafeEncoder = encoder
        let group = DispatchGroup()
        let writer = Thread {
            for i in 0..<20_000 {
                unsafeEncoder.userInfo = [key: i]
                unsafeEncoder.keyEncodingStrategy = i % 2 == 0 ? .convertToSnakeCase : .useDefaultKeys
            }
            group.leave()
        }
        let reader = Thread {
            for i in 0..<20_000 {
                _ = try? unsafeEncoder.encode(["fooBar": i])
            }
            group.leave()
        }
        group.enter(); group.enter()
        writer.start(); reader.start()
        group.wait()
    }
}
