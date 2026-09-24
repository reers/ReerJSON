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

    // MARK: - JSONStreamParser

    private static func ndjson(count: Int) -> Data {
        var s = ""
        for i in 0..<count {
            s += "{\"id\":\(i),\"name\":\"item_\(i)\",\"value\":\(Double(i) * 1.5),\"flag\":true}\n"
        }
        return Data(s.utf8)
    }

    private static func bestTime(_ body: () throws -> Void) rethrows -> Double {
        var best = Double.greatestFiniteMagnitude
        for _ in 0..<3 {
            let start = DispatchTime.now().uptimeNanoseconds
            try body()
            best = min(best, Double(DispatchTime.now().uptimeNanoseconds - start))
        }
        return best
    }

    @Test(arguments: [JSONStreamMode.jsonLines, .jsonArray])
    func streamParserScalesLinearlyWithItemCount(mode: JSONStreamMode) throws {
        func payload(_ count: Int) -> Data {
            guard mode == .jsonArray else { return Self.ndjson(count: count) }
            var s = String(decoding: Self.ndjson(count: count), as: UTF8.self)
            s.removeLast()
            return Data(("[" + s.replacingOccurrences(of: "\n", with: ",") + "]").utf8)
        }
        let small = payload(2_000), large = payload(16_000)
        func parseAll(_ data: Data, expected: Int) throws {
            var parser = JSONStreamParser(mode: mode)
            let count = try parser.parse(data).count + parser.finalize().count
            #expect(count == expected)
        }
        let smallTime = try Self.bestTime { try parseAll(small, expected: 2_000) }
        let largeTime = try Self.bestTime { try parseAll(large, expected: 16_000) }
        // 8x the items: linear ≈ 8x, quadratic ≈ 64x.
        #expect(largeTime / smallTime < 24, "ratio \(largeTime / smallTime)")
    }

    @Test(arguments: [JSONStreamMode.jsonLines, .jsonArray])
    func streamParserHandlesMixedItemSizes(mode: JSONStreamMode) throws {
        let sizes = [1, 5_000, 3, 70_000, 10, 10, 300_000, 2, 1_000]
        var items: [String] = []
        for (i, size) in sizes.enumerated() {
            items.append("{\"i\":\(i),\"s\":\"\(String(repeating: "x", count: size))\"}")
            items.append("\(i * 1_000_003)")
        }
        let text = mode == .jsonLines
            ? items.joined(separator: " \n")
            : "[" + items.joined(separator: ", ") + "]"
        let data = Data(text.utf8)
        for chunkSize in [data.count, 4_096, 7] {
            var parser = JSONStreamParser(mode: mode)
            var values: [JSONValue] = []
            var offset = 0
            while offset < data.count {
                let end = min(offset + chunkSize, data.count)
                values += try parser.parse(data.subdata(in: offset..<end))
                offset = end
            }
            values += try parser.finalize()
            try #require(values.count == items.count)
            for (i, size) in sizes.enumerated() {
                #expect(values[2 * i]["i"]?.int64 == Int64(i))
                #expect(values[2 * i]["s"]?.string?.utf8.count == size)
                #expect(values[2 * i + 1].int64 == Int64(i * 1_000_003))
            }
        }
    }

    @Test func streamParserDefersNumberAtBufferEnd() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        var data = Self.ndjson(count: 500)
        data.append(contentsOf: Array("12".utf8))
        #expect(try parser.parse(data).count == 500)
        #expect(try parser.parse(Data("3\n".utf8)).first?.int64 == 123)
        #expect(try parser.finalize().isEmpty)
    }

    @Test func streamParserReportsErrorAfterValidItems() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        var data = Self.ndjson(count: 500)
        data.append(contentsOf: Array("{\"a\":tru}\n".utf8))
        data.append(Self.ndjson(count: 10))
        #expect(throws: JSONError.self) { try parser.parse(data) }
    }
}
