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

    // MARK: - ReerJSONSerialization writing

    @Test func serializationWriteScalesLinearlyWithDictionaryWidth() throws {
        func dictionary(_ count: Int) -> NSDictionary {
            let dict = NSMutableDictionary()
            for i in 0..<count { dict["key_\(i)"] = i }
            return dict
        }
        let small = dictionary(1_000), large = dictionary(8_000)
        let smallTime = try Self.bestTime { _ = try ReerJSONSerialization.data(withJSONObject: small) }
        let largeTime = try Self.bestTime { _ = try ReerJSONSerialization.data(withJSONObject: large) }
        // 8x the keys: linear ≈ 8x, quadratic ≈ 64x.
        #expect(largeTime / smallTime < 24, "ratio \(largeTime / smallTime)")
    }

    @Test func serializationWriteMatchesFoundationOutput() throws {
        let object: [String: Any] = [
            "string": "héllo \"world\" / \u{1F600}",
            "int": -42,
            "uint64": UInt64.max,
            "double": 3.25,
            "bool": true,
            "false": false,
            "null": NSNull(),
            "array": [1, "two", 3.5, false, NSNull(), ["nested": [1, 2]]],
            "dict": ["a": ["b": ["c": "d"]]],
            "empty": [String: Any](),
            "emptyArray": [Any](),
            "nsstring": NSString(string: "bridged"),
            "nsnumber": NSNumber(value: Int8(-3)),
            "mutable": NSMutableString(string: "mut ü"),
            "long": String(repeating: "长字符串", count: 100),
        ]
        for options: ReerJSONSerialization.WritingOptions in [[.sortedKeys], [.sortedKeys, .withoutEscapingSlashes]] {
            let foundationOptions: JSONSerialization.WritingOptions =
                options.contains(.withoutEscapingSlashes) ? [.sortedKeys, .withoutEscapingSlashes] : [.sortedKeys]
            let reer = try ReerJSONSerialization.data(withJSONObject: object, options: options)
            let foundation = try JSONSerialization.data(withJSONObject: object, options: foundationOptions)
            #expect(String(decoding: reer, as: UTF8.self) == String(decoding: foundation, as: UTF8.self))
        }
    }

    @Test func serializationWriteReplacesUnpairedSurrogates() throws {
        var units: [unichar] = [0x61, 0xD800, 0x62]
        let lone = NSString(characters: &units, length: units.count)
        let data = try ReerJSONSerialization.data(withJSONObject: [lone] as NSArray)
        #expect(String(decoding: data, as: UTF8.self) == "[\"a\u{FFFD}b\"]")
    }

    // MARK: - Encoder keyed containers

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ string: String) { stringValue = string }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    private struct WideObject: Encodable {
        let count: Int
        var overrides: [(key: Int, value: Int)] = []
        var superKeys: [Int] = []
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: DynamicKey.self)
            for i in 0..<count { try container.encode(i, forKey: DynamicKey("key_\(i)")) }
            for (key, value) in overrides { try container.encode(value, forKey: DynamicKey("key_\(key)")) }
            for key in superKeys {
                var single = container.superEncoder(forKey: DynamicKey("key_\(key)")).singleValueContainer()
                try single.encode("super_\(key)")
            }
        }
    }

    @Test func encoderKeyedContainerScalesLinearlyWithWidth() throws {
        let encoder = ReerJSONEncoder()
        let small = WideObject(count: 1_000), large = WideObject(count: 8_000)
        let smallTime = try Self.bestTime { _ = try encoder.encode(small) }
        let largeTime = try Self.bestTime { _ = try encoder.encode(large) }
        // 8x the keys: linear ≈ 8x, quadratic ≈ 64x.
        #expect(largeTime / smallTime < 24, "ratio \(largeTime / smallTime)")
    }

    @Test(arguments: [5, 31, 32, 33, 200])
    func encoderWideObjectKeepsLastValueForDuplicateKeys(count: Int) throws {
        var object = WideObject(count: count)
        object.overrides = [(0, -1), (count - 1, -2), (count / 2, -3), (count - 1, -4)]
        object.superKeys = [1, count - 2]
        let data = try ReerJSONEncoder().encode(object)
        let text = String(decoding: data, as: UTF8.self)
        let value = try JSONValue(data: data)
        let keys = try #require(value.object).map(\.key)
        #expect(keys == (0..<count).map { "key_\($0)" })
        #expect(value["key_0"]?.int64 == -1)
        #expect(value["key_\(count / 2)"]?.int64 == (count / 2 == count - 1 ? -4 : -3))
        #expect(value["key_\(count - 1)"]?.int64 == -4)
        #expect(value["key_1"]?.string == "super_1")
        #expect(value["key_\(count - 2)"]?.string == "super_\(count - 2)")
        let foundation = try JSONSerialization.jsonObject(with: JSONEncoder().encode(object)) as! [String: Any]
        let reer = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(NSDictionary(dictionary: foundation) == NSDictionary(dictionary: reer), "\(text)")
    }

    private struct DictionaryThenKeyed: Encodable {
        let count: Int
        func encode(to encoder: Encoder) throws {
            var single = encoder.singleValueContainer()
            try single.encode(Dictionary(uniqueKeysWithValues: (0..<count).map { ("key_\($0)", $0) }))
            var keyed = encoder.container(keyedBy: DynamicKey.self)
            try keyed.encode(-1, forKey: DynamicKey("key_0"))
            try keyed.encode(-2, forKey: DynamicKey("extra"))
            try keyed.encode(-3, forKey: DynamicKey("key_\(count - 1)"))
        }
    }

    @Test(arguments: [3, 40, 100])
    func encoderKeyedContainerAmendsExistingDictionary(count: Int) throws {
        let data = try ReerJSONEncoder().encode(DictionaryThenKeyed(count: count))
        let value = try #require(try JSONValue(data: data).object)
        #expect(value.count == count + 1)
        #expect(value["key_0"]?.int64 == -1)
        #expect(value["extra"]?.int64 == -2)
        #expect(value["key_\(count - 1)"]?.int64 == -3)
        #expect(value["key_1"]?.int64 == 1)
    }

    private struct Thrower: Encodable {
        func encode(to encoder: Encoder) throws {
            throw EncodingError.invalidValue(0, .init(codingPath: encoder.codingPath, debugDescription: "boom"))
        }
    }

    private struct RecoversFromDictionaryError: Encodable {
        enum CodingKeys: String, CodingKey { case dict, value }
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            _ = try? container.encode(["inner": Thrower()], forKey: .dict)
            try container.encode(Thrower(), forKey: .value)
        }
    }

    @Test func encoderRestoresCodingPathAfterDictionaryError() throws {
        func errorPath(_ encode: () throws -> Data) -> [String] {
            do {
                _ = try encode()
            } catch let EncodingError.invalidValue(_, context) {
                return context.codingPath.map(\.stringValue)
            } catch {}
            return ["<no error>"]
        }
        let value = RecoversFromDictionaryError()
        let foundation = errorPath { try JSONEncoder().encode(value) }
        #expect(foundation == ["value"])
        #expect(errorPath { try ReerJSONEncoder().encode(value) } == foundation)
    }

    @Test func serializationWriteRejectsInvalidObjects() throws {
        let invalid = JSONError.invalidData("Invalid JSON object")
        let cases: [Any] = [
            ["a": Double.nan] as NSDictionary,
            ["a": [1, Double.infinity]] as NSDictionary,
            [["a": ["b": Float.nan]]] as NSArray,
            [1: "non-string key"] as NSDictionary,
            ["a": [2: 1]] as NSDictionary,
            ["a": Date()] as NSDictionary,
            [Data()] as NSArray,
        ]
        for object in cases {
            #expect(throws: invalid) { try ReerJSONSerialization.data(withJSONObject: object) }
            #expect(!ReerJSONSerialization.isValidJSONObject(object))
        }
        #expect(try ReerJSONSerialization.data(
            withJSONObject: ["a": [Double.nan]] as NSDictionary, options: .infAndNaNAsNull
        ) == Data(#"{"a":[null]}"#.utf8))
    }
}
