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

import XCTest
@testable import ReerJSON

// MARK: - Test Helpers

private struct Item: Codable, Equatable, Sendable {
    let id: Int
    let name: String
}

// MARK: - JSON Lines Tests

final class JSONStreamParserJSONLinesTests: XCTestCase {

    func testSingleCompleteChunk() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        let data = Data("{\"id\":1,\"name\":\"a\"}\n{\"id\":2,\"name\":\"b\"}\n".utf8)
        let values = try parser.parse(data)
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values[0]["id"]?.int64, 1)
        XCTAssertEqual(values[1]["name"]?.string, "b")
        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testCrossChunkValues() throws {
        var parser = JSONStreamParser(mode: .jsonLines)

        let chunk1 = Data("{\"id\":1}\n{\"id\"".utf8)
        let values1 = try parser.parse(chunk1)
        XCTAssertEqual(values1.count, 1)
        XCTAssertEqual(values1[0]["id"]?.int64, 1)

        let chunk2 = Data(":2}\n".utf8)
        let values2 = try parser.parse(chunk2)
        XCTAssertEqual(values2.count, 1)
        XCTAssertEqual(values2[0]["id"]?.int64, 2)

        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testEmptyLines() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        let data = Data("\n\n{\"x\":1}\n\n\n{\"x\":2}\n\n".utf8)
        let values = try parser.parse(data)
        XCTAssertEqual(values.count, 2)
        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testWhitespacePadding() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        let data = Data("   {\"a\":1}   \n   {\"a\":2}   ".utf8)
        let values = try parser.parse(data)
        XCTAssertEqual(values.count, 2)
        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testVariousTypes() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        let data = Data("42\n\"hello\"\ntrue\nnull\n[1,2]\n{\"k\":\"v\"}\n".utf8)
        let values = try parser.parse(data)
        XCTAssertEqual(values.count, 6)
        XCTAssertEqual(values[0].int64, 42)
        XCTAssertEqual(values[1].string, "hello")
        XCTAssertEqual(values[2].bool, true)
        XCTAssertTrue(values[3].isNull)
        XCTAssertEqual(values[4].array?.count, 2)
        XCTAssertEqual(values[5]["k"]?.string, "v")
        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testEmptyDataParse() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        let values = try parser.parse(Data())
        XCTAssertTrue(values.isEmpty)
        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testIncompleteJSONAtFinalize() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        _ = try parser.parse(Data("{\"id\":1}".utf8))
        _ = try parser.parse(Data("{\"incomplete".utf8))
        XCTAssertThrowsError(try parser.finalize())
    }
}

// MARK: - JSON Array Tests

final class JSONStreamParserJSONArrayTests: XCTestCase {

    func testNormalArray() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        let data = Data("[1, 2, 3]".utf8)
        let values = try parser.parse(data)
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values[0].int64, 1)
        XCTAssertEqual(values[1].int64, 2)
        XCTAssertEqual(values[2].int64, 3)
        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testNestedObjects() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        let data = Data("[{\"a\":1},{\"b\":[2,3]},{\"c\":{\"d\":4}}]".utf8)
        let values = try parser.parse(data)
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values[0]["a"]?.int64, 1)
        XCTAssertEqual(values[1]["b"]?.array?.count, 2)
        XCTAssertEqual(values[2]["c"]?["d"]?.int64, 4)
    }

    func testNestedArrays() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        let data = Data("[[1,2],[3,[4,5]]]".utf8)
        let values = try parser.parse(data)
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values[0].array?.count, 2)
    }

    func testEmptyArray() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        let data = Data("[]".utf8)
        let values = try parser.parse(data)
        XCTAssertTrue(values.isEmpty)
        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testTrailingCommaWithOption() throws {
        var parser = JSONStreamParser(mode: .jsonArray, options: .allowTrailingCommas)
        let data = Data("[1, 2, 3,]".utf8)
        let values = try parser.parse(data)
        XCTAssertEqual(values.count, 3)
    }

    func testCrossChunkArray() throws {
        var parser = JSONStreamParser(mode: .jsonArray)

        let chunk1 = Data("[{\"id\":1},".utf8)
        let values1 = try parser.parse(chunk1)
        XCTAssertEqual(values1.count, 1)
        XCTAssertEqual(values1[0]["id"]?.int64, 1)

        let chunk2 = Data("{\"id\":2}]".utf8)
        let values2 = try parser.parse(chunk2)
        XCTAssertEqual(values2.count, 1)
        XCTAssertEqual(values2[0]["id"]?.int64, 2)

        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testArrayWithWhitespace() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        let data = Data("  [  1  ,  2  ,  3  ]  ".utf8)
        let values = try parser.parse(data)
        XCTAssertEqual(values.count, 3)
        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testMissingOpenBracket() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        XCTAssertThrowsError(try parser.parse(Data("1, 2, 3]".utf8)))
    }

    func testIncompleteArray() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        _ = try parser.parse(Data("[1, 2".utf8))
        XCTAssertThrowsError(try parser.finalize())
    }

    func testStringElements() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        let data = Data("[\"hello\", \"world\"]".utf8)
        let values = try parser.parse(data)
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values[0].string, "hello")
        XCTAssertEqual(values[1].string, "world")
    }

    func testMixedTypes() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        let data = Data("[1, \"two\", true, null, {\"k\":\"v\"}, [3]]".utf8)
        let values = try parser.parse(data)
        XCTAssertEqual(values.count, 6)
        XCTAssertEqual(values[0].int64, 1)
        XCTAssertEqual(values[1].string, "two")
        XCTAssertEqual(values[2].bool, true)
        XCTAssertTrue(values[3].isNull)
    }
}

// MARK: - Incremental Reader Tests

final class JSONIncrementalReaderTests: XCTestCase {

    func testSingleChunk() throws {
        let reader = try JSONIncrementalReader(data: Data("{\"key\":\"value\"}".utf8))
        let doc = try reader.finish()
        XCTAssertEqual(doc.root?["key"]?.string, "value")
    }

    func testMultipleChunks() throws {
        let reader = try JSONIncrementalReader(data: Data("{\"ke".utf8))
        // First feed should need more data
        do {
            if let doc = try reader.feed(Data("y\":\"val".utf8)) {
                XCTFail("Should need more data, got doc with root: \(String(describing: doc.root))")
            }
        }
        // Second feed should complete
        if let doc = try reader.feed(Data("ue\"}".utf8)) {
            XCTAssertEqual(doc.root?["key"]?.string, "value")
        } else {
            XCTFail("Should have completed parsing")
        }
    }

    func testLargerDocument() throws {
        var items: [[String: Any]] = []
        for i in 0..<100 {
            items.append(["id": i, "name": "item_\(i)"])
        }
        let jsonData = try JSONSerialization.data(withJSONObject: items)

        let chunkSize = 64
        let firstChunk = Data(jsonData[0..<min(chunkSize, jsonData.count)])
        let reader = try JSONIncrementalReader(data: firstChunk)
        var offset = min(chunkSize, jsonData.count)

        var parsed = false
        while offset < jsonData.count {
            let end = min(offset + chunkSize, jsonData.count)
            let chunk = Data(jsonData[offset..<end])
            if let doc = try reader.feed(chunk) {
                XCTAssertEqual(doc.rootArray?.count, 100)
                parsed = true
                break
            }
            offset = end
        }
        if !parsed {
            let doc = try reader.finish()
            XCTAssertEqual(doc.rootArray?.count, 100)
        }
    }

    func testFinishTwiceThrows() throws {
        let reader = try JSONIncrementalReader(data: Data("42".utf8))
        _ = try reader.finish()
        do {
            _ = try reader.finish()
            XCTFail("Expected error on second finish()")
        } catch {
            // Expected
        }
    }
}

// MARK: - Edge Cases

final class JSONStreamParserEdgeCaseTests: XCTestCase {

    func testEmptyDataReturnsEmpty() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        let values = try parser.parse(Data())
        XCTAssertTrue(values.isEmpty)
    }

    func testFinalizeEmptyIsOk() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testReset() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        _ = try parser.parse(Data("{\"a\":1}\n".utf8))
        parser.reset()
        XCTAssertEqual(parser.pendingByteCount, 0)
        let values = try parser.parse(Data("{\"b\":2}\n".utf8))
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values[0]["b"]?.int64, 2)
    }

    func testPendingByteCount() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        _ = try parser.parse(Data("{\"a\":1}{\"incomplete".utf8))
        XCTAssertTrue(parser.pendingByteCount > 0)
    }

    func testVeryLargeObject() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        var json = "{\"data\":\""
        for _ in 0..<10_000 {
            json += "x"
        }
        json += "\"}\n"
        let values = try parser.parse(Data(json.utf8))
        XCTAssertEqual(values.count, 1)
    }

    func testArrayResetAndReuse() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        _ = try parser.parse(Data("[1,2]".utf8))
        _ = try parser.finalize()

        parser.reset()
        let values = try parser.parse(Data("[3,4]".utf8))
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values[0].int64, 3)
        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }
}

// MARK: - Codable Decoder Tests

final class StreamingDecoderTests: XCTestCase {

    func testJSONLinesDecoder() throws {
        var decoder = StreamingJSONLinesDecoder(Item.self)
        let data = Data("{\"id\":1,\"name\":\"a\"}\n{\"id\":2,\"name\":\"b\"}\n".utf8)
        let items = try decoder.parseBuffer(data)
        XCTAssertEqual(items, [Item(id: 1, name: "a"), Item(id: 2, name: "b")])
        let remaining = try decoder.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testJSONLinesDecoderCrossChunk() throws {
        var decoder = StreamingJSONLinesDecoder(Item.self)
        let items1 = try decoder.parseBuffer(Data("{\"id\":1,\"name\":\"a\"}\n{\"id\"".utf8))
        XCTAssertEqual(items1, [Item(id: 1, name: "a")])
        let items2 = try decoder.parseBuffer(Data(":2,\"name\":\"b\"}\n".utf8))
        XCTAssertEqual(items2, [Item(id: 2, name: "b")])
        let remaining = try decoder.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testJSONArrayDecoder() throws {
        var decoder = StreamingJSONArrayDecoder(Item.self)
        let data = Data("[{\"id\":1,\"name\":\"a\"},{\"id\":2,\"name\":\"b\"}]".utf8)
        let items = try decoder.parseBuffer(data)
        XCTAssertEqual(items, [Item(id: 1, name: "a"), Item(id: 2, name: "b")])
        let remaining = try decoder.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testJSONArrayDecoderCrossChunk() throws {
        var decoder = StreamingJSONArrayDecoder(Item.self)
        let items1 = try decoder.parseBuffer(Data("[{\"id\":1,\"name\":\"a\"},".utf8))
        XCTAssertEqual(items1, [Item(id: 1, name: "a")])
        let items2 = try decoder.parseBuffer(Data("{\"id\":2,\"name\":\"b\"}]".utf8))
        XCTAssertEqual(items2, [Item(id: 2, name: "b")])
        let remaining = try decoder.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testDecoderReset() throws {
        var decoder = StreamingJSONLinesDecoder(Item.self)
        _ = try decoder.parseBuffer(Data("{\"id\":1,\"name\":\"a\"}\n".utf8))
        decoder.reset()
        let items = try decoder.parseBuffer(Data("{\"id\":2,\"name\":\"b\"}\n".utf8))
        XCTAssertEqual(items, [Item(id: 2, name: "b")])
    }
}

// MARK: - AsyncSequence Tests

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class AsyncStreamTests: XCTestCase {

    func testJSONValueStream() async throws {
        let chunks: [Data] = [
            Data("{\"id\":1}\n{\"id\"".utf8),
            Data(":2}\n{\"id\":3}\n".utf8)
        ]
        let stream = AsyncStream<Data> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }

        var values: [JSONValue] = []
        for try await value in stream.jsonValues(mode: .jsonLines) {
            values.append(value)
        }
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values[0]["id"]?.int64, 1)
        XCTAssertEqual(values[1]["id"]?.int64, 2)
        XCTAssertEqual(values[2]["id"]?.int64, 3)
    }

    func testDecodingStream() async throws {
        let chunks: [Data] = [
            Data("{\"id\":1,\"name\":\"a\"}\n".utf8),
            Data("{\"id\":2,\"name\":\"b\"}\n".utf8)
        ]
        let stream = AsyncStream<Data> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }

        var items: [Item] = []
        for try await item in stream.decode(Item.self, mode: .jsonLines) {
            items.append(item)
        }
        XCTAssertEqual(items, [Item(id: 1, name: "a"), Item(id: 2, name: "b")])
    }

    func testJSONArrayValueStream() async throws {
        let chunks: [Data] = [
            Data("[{\"id\":1,\"name\":\"a\"},".utf8),
            Data("{\"id\":2,\"name\":\"b\"}]".utf8)
        ]
        let stream = AsyncStream<Data> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }

        var values: [JSONValue] = []
        for try await value in stream.jsonValues(mode: .jsonArray) {
            values.append(value)
        }
        XCTAssertEqual(values.count, 2)
    }

    func testDecodingStreamArrayMode() async throws {
        let chunks: [Data] = [
            Data("[{\"id\":1,\"name\":\"x\"},".utf8),
            Data("{\"id\":2,\"name\":\"y\"}]".utf8)
        ]
        let stream = AsyncStream<Data> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }

        var items: [Item] = []
        for try await item in stream.decode(Item.self, mode: .jsonArray) {
            items.append(item)
        }
        XCTAssertEqual(items, [Item(id: 1, name: "x"), Item(id: 2, name: "y")])
    }

    func testEmptyStream() async throws {
        let stream = AsyncStream<Data> { continuation in
            continuation.finish()
        }

        var count = 0
        for try await _ in stream.jsonValues(mode: .jsonLines) {
            count += 1
        }
        XCTAssertEqual(count, 0)
    }
}
