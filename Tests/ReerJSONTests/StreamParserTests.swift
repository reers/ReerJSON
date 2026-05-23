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

    // MARK: - Boundary / cross-chunk correctness

    /// Regression: yyjson with STOP_WHEN_DONE will happily parse `1` from
    /// a buffer that ends exactly at "1" — but the real input might be
    /// "12345". The parser must defer such tokens until the next chunk or
    /// `finalize()` confirms there is no continuation.
    func testCrossChunkSplitNumber() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        // Send "12345\n" split as "1" / "234" / "5\n".
        let v1 = try parser.parse(Data("1".utf8))
        XCTAssertTrue(v1.isEmpty, "Bare number at end of buffer must not be yielded yet")
        let v2 = try parser.parse(Data("234".utf8))
        XCTAssertTrue(v2.isEmpty)
        let v3 = try parser.parse(Data("5\n".utf8))
        XCTAssertEqual(v3.count, 1)
        XCTAssertEqual(v3[0].int64, 12345)
        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testCrossChunkSplitFloat() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        let v1 = try parser.parse(Data("1.2".utf8))
        XCTAssertTrue(v1.isEmpty)
        let v2 = try parser.parse(Data("3e".utf8))
        XCTAssertTrue(v2.isEmpty)
        let v3 = try parser.parse(Data("4\n".utf8))
        XCTAssertEqual(v3.count, 1)
        XCTAssertEqual(v3[0].number, 1.23e4)
        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    /// Strings end with `"`, so yyjson can detect truncation directly.
    /// Splitting them mid-token must still work.
    func testCrossChunkSplitInsideString() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        let v1 = try parser.parse(Data("\"hel".utf8))
        XCTAssertTrue(v1.isEmpty)
        let v2 = try parser.parse(Data("lo\"\n".utf8))
        XCTAssertEqual(v2.count, 1)
        XCTAssertEqual(v2[0].string, "hello")
    }

    /// A value that ends exactly at the buffer boundary without a trailing
    /// terminator (e.g. {"a":1} with no newline) should still surface on
    /// finalize().
    func testFinalizeFlushesTrailingValueWithoutNewline() throws {
        var parser = JSONStreamParser(mode: .jsonLines)
        let v1 = try parser.parse(Data("{\"a\":1}".utf8))
        // May or may not be yielded depending on buffer-end heuristic; the
        // important contract is that finalize() yields it.
        let remaining = try parser.finalize()
        let total = v1 + remaining
        XCTAssertEqual(total.count, 1)
        XCTAssertEqual(total[0]["a"]?.int64, 1)
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

    func testTrailingCommaWithoutOptionThrows() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        XCTAssertThrowsError(try parser.parse(Data("[1, 2, 3,]".utf8)))
    }

    func testTrailingCommaWithJSON5Option() throws {
        var parser = JSONStreamParser(mode: .jsonArray, options: .json5)
        let values = try parser.parse(Data("[1, 2, 3,]".utf8))
        XCTAssertEqual(values.map(\.int64), [1, 2, 3])
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

    func testEmptyArrayStreamAtFinalizeThrows() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        XCTAssertThrowsError(try parser.finalize())
    }

    func testTrailingContentAfterArrayThrows() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        XCTAssertThrowsError(try parser.parse(Data("[1] 2".utf8)))
    }

    /// Regression for cross-chunk numeric splitting inside an array.
    /// Without the buffer-end deferral, the parser would commit `1` from
    /// `[1` and then choke on `2` when the second chunk arrives.
    func testCrossChunkArraySplitNumber() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        let v1 = try parser.parse(Data("[1".utf8))
        XCTAssertTrue(v1.isEmpty, "Bare number at buffer end must defer")
        let v2 = try parser.parse(Data("23,456]".utf8))
        XCTAssertEqual(v2.map(\.int64), [123, 456])
        let remaining = try parser.finalize()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testCrossChunkArrayTinyChunks() throws {
        var parser = JSONStreamParser(mode: .jsonArray)
        let chunks = ["[", "12", "3,", "45", "6", ",", "789", "]"]
        var all: [JSONValue] = []
        for chunk in chunks {
            all += try parser.parse(Data(chunk.utf8))
        }
        all += try parser.finalize()
        XCTAssertEqual(all.map(\.int64), [123, 456, 789])
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
        // First feed should need more data.
        switch try reader.feed(Data("y\":\"val".utf8)) {
        case .ready(let doc):
            XCTFail("Should need more data, got doc with root: \(String(describing: doc.root))")
        case .needMoreData:
            break
        }
        // Second feed should complete.
        switch try reader.feed(Data("ue\"}".utf8)) {
        case .ready(let doc):
            XCTAssertEqual(doc.root?["key"]?.string, "value")
        case .needMoreData:
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
        feedLoop: while offset < jsonData.count {
            let end = min(offset + chunkSize, jsonData.count)
            let chunk = Data(jsonData[offset..<end])
            switch try reader.feed(chunk) {
            case .ready(let doc):
                XCTAssertEqual(doc.rootArray?.count, 100)
                parsed = true
                break feedLoop
            case .needMoreData:
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

    func testInvalidJSONIsThrownNotDeferred() throws {
        let reader = try JSONIncrementalReader(data: Data("{\"key\":}".utf8))
        do {
            _ = try reader.finish()
            XCTFail("Expected an error for malformed JSON")
        } catch {
            // Expected
        }
    }

    /// Regression: a JSON error message that happens to contain "Empty
    /// content" or "Unexpected end" used to be misclassified as a
    /// recoverable "need more data" condition. With error-code-based
    /// detection, syntactic errors must surface immediately.
    func testStructuralErrorIsNotMistakenForNeedMore() throws {
        let reader = try JSONIncrementalReader(data: Data())
        // Empty buffer is recoverable.
        do {
            switch try reader.feed(Data()) {
            case .ready:
                XCTFail("Empty buffer should not yield a document")
            case .needMoreData:
                break
            }
        } catch {
            XCTFail("Empty buffer should not throw, got: \(error)")
        }
        // But a structurally invalid chunk must throw.
        let badReader = try JSONIncrementalReader()
        do {
            _ = try badReader.feed(Data("[1,]extra".utf8))
            XCTFail("Structurally invalid JSON should throw")
        } catch {
            // Expected
        }
    }

    /// `JSONIncrementalReader` is documented as `@unchecked Sendable`; this
    /// exercises basic concurrent access to confirm the internal lock works.
    func testConcurrentFeedDoesNotCrash() async throws {
        let reader = try JSONIncrementalReader()
        let chunks: [Data] = [
            Data("{\"a\":".utf8),
            Data("[1,2,".utf8),
            Data("3,4,".utf8),
            Data("5]}".utf8)
        ]
        await withTaskGroup(of: Void.self) { group in
            for chunk in chunks {
                group.addTask {
                    _ = try? reader.feed(chunk)
                }
            }
        }
        // Best-effort: either we've already finished, or finish() completes it.
        do {
            let doc = try reader.finish()
            XCTAssertNotNil(doc.root)
        } catch {
            // Race may have finished it via feed(); that's also acceptable.
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
