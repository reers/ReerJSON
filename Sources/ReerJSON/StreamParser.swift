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

import yyjson
import Foundation

// MARK: - JSONStreamMode

/// The parsing mode for a stream of JSON data.
public enum JSONStreamMode: Sendable {
    /// Each line is an independent JSON value (JSON Lines / NDJSON).
    case jsonLines
    /// The stream is a single JSON array whose elements are yielded one by one.
    case jsonArray
}

// MARK: - JSONStreamParser

/// A streaming JSON parser that extracts individual ``JSONValue`` items from
/// a byte stream, supporting both JSON Lines and JSON Array modes.
///
/// `JSONStreamParser` maintains an internal buffer. You feed data incrementally
/// with ``parse(_:)`` and receive fully-parsed ``JSONValue`` items as they
/// become available. Call ``finalize()`` when the stream ends to flush any
/// remaining buffered data.
///
/// ## JSON Lines Mode
///
/// Each top-level JSON value in the buffer is extracted as a separate item.
/// Values may span multiple ``parse(_:)`` calls.
///
/// ```swift
/// var parser = JSONStreamParser(mode: .jsonLines)
/// let chunk1 = Data("{\"a\":1}\n{\"b\"".utf8)
/// let chunk2 = Data(":2}\n".utf8)
/// let values1 = try parser.parse(chunk1)  // [{"a":1}]
/// let values2 = try parser.parse(chunk2)  // [{"b":2}]
/// ```
///
/// ## JSON Array Mode
///
/// The stream is expected to be a single JSON array (`[...]`).
/// Each array element is yielded individually.
///
/// ```swift
/// var parser = JSONStreamParser(mode: .jsonArray)
/// let items = try parser.parse(Data("[1, 2, 3]".utf8))
/// let remaining = try parser.finalize()
/// // items + remaining contain JSONValues for 1, 2, 3
/// ```
public struct JSONStreamParser: Sendable {

    /// The parsing mode.
    public let mode: JSONStreamMode

    /// Options for reading JSON.
    public let options: JSONReadOptions

    private var buffer: Data
    private var readOffset: Int
    private var arrayState: ArrayParseState

    /// The number of bytes buffered but not yet consumed.
    public var pendingByteCount: Int {
        buffer.count - readOffset
    }

    /// Creates a new stream parser.
    ///
    /// - Parameters:
    ///   - mode: The stream format (`.jsonLines` or `.jsonArray`).
    ///   - options: Options for reading JSON. Note that `.stopWhenDone` is
    ///     always applied internally and does not need to be specified.
    public init(mode: JSONStreamMode, options: JSONReadOptions = .default) {
        self.mode = mode
        self.options = options
        self.buffer = Data()
        self.readOffset = 0
        self.arrayState = .expectOpenBracket
    }

    /// Feeds data to the parser and returns all complete JSON values found.
    ///
    /// - Parameter data: New data to append to the internal buffer.
    /// - Returns: An array of fully-parsed ``JSONValue`` items.
    /// - Throws: ``JSONError`` if malformed JSON is encountered.
    public mutating func parse(_ data: Data) throws -> [JSONValue] {
        buffer.append(data)
        return try drainBuffer()
    }

    /// Feeds raw bytes to the parser and returns all complete JSON values found.
    ///
    /// - Parameter bytes: A buffer pointer to the raw bytes.
    /// - Returns: An array of fully-parsed ``JSONValue`` items.
    /// - Throws: ``JSONError`` if malformed JSON is encountered.
    public mutating func parse(bytes: UnsafeBufferPointer<UInt8>) throws -> [JSONValue] {
        if let base = bytes.baseAddress, bytes.count > 0 {
            buffer.append(base, count: bytes.count)
        }
        return try drainBuffer()
    }

    /// Signals end-of-stream and returns any remaining JSON values.
    ///
    /// After calling this method, the parser is in a finished state.
    /// Call ``reset()`` to reuse it.
    ///
    /// - Returns: An array of any remaining ``JSONValue`` items.
    /// - Throws: ``JSONError`` if the remaining buffer contains incomplete JSON.
    public mutating func finalize() throws -> [JSONValue] {
        let results = try drainBuffer()

        skipWhitespace()
        if readOffset < buffer.count {
            if mode == .jsonArray {
                throw JSONError.invalidJSON("Unexpected end of JSON array stream")
            } else {
                throw JSONError.invalidJSON("Incomplete JSON value at end of stream")
            }
        }

        if mode == .jsonArray && arrayState != .done && arrayState != .expectOpenBracket {
            throw JSONError.invalidJSON("Unexpected end of JSON array stream")
        }

        return results
    }

    /// Resets the parser to its initial state, discarding all buffered data.
    public mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
        readOffset = 0
        arrayState = .expectOpenBracket
    }

    // MARK: - Private Types

    private enum ArrayParseState: Sendable {
        case expectOpenBracket
        case expectElementOrClose
        case expectCommaOrClose
        case done
    }

    // MARK: - Drain Logic

    private mutating func drainBuffer() throws -> [JSONValue] {
        compactIfNeeded()

        switch mode {
        case .jsonLines:
            return try drainJSONLines()
        case .jsonArray:
            return try drainJSONArray()
        }
    }

    private mutating func drainJSONLines() throws -> [JSONValue] {
        var results: [JSONValue] = []

        while true {
            skipWhitespace()
            guard buffer.count - readOffset > 0 else { break }

            guard let value = try parseOneValue() else { break }
            results.append(value)
        }

        return results
    }

    private mutating func drainJSONArray() throws -> [JSONValue] {
        var results: [JSONValue] = []

        loop: while true {
            skipWhitespace()

            switch arrayState {
            case .expectOpenBracket:
                guard readOffset < buffer.count else { break loop }
                let byte = buffer[buffer.startIndex + readOffset]
                guard byte == UInt8(ascii: "[") else {
                    throw JSONError.invalidJSON("Expected '[' at start of JSON array stream")
                }
                readOffset += 1
                arrayState = .expectElementOrClose

            case .expectElementOrClose:
                skipWhitespace()
                guard readOffset < buffer.count else { break loop }
                let byte = buffer[buffer.startIndex + readOffset]
                if byte == UInt8(ascii: "]") {
                    readOffset += 1
                    arrayState = .done
                    break loop
                }
                guard let value = try parseOneValue() else { break loop }
                results.append(value)
                arrayState = .expectCommaOrClose

            case .expectCommaOrClose:
                skipWhitespace()
                guard readOffset < buffer.count else { break loop }
                let byte = buffer[buffer.startIndex + readOffset]
                if byte == UInt8(ascii: ",") {
                    readOffset += 1
                    arrayState = .expectElementOrClose
                } else if byte == UInt8(ascii: "]") {
                    readOffset += 1
                    arrayState = .done
                    break loop
                } else {
                    throw JSONError.invalidJSON(
                        "Expected ',' or ']' in JSON array, got '\(Unicode.Scalar(byte))'"
                    )
                }

            case .done:
                break loop
            }
        }

        return results
    }

    // MARK: - Core Parse

    /// Tries to parse one JSON value starting at `readOffset`.
    /// Returns `nil` if more data is needed.
    private mutating func parseOneValue() throws -> JSONValue? {
        let available = buffer.count - readOffset
        guard available > 0 else { return nil }

        let paddingSize = Int(YYJSON_PADDING_SIZE)

        // Build a padded copy so yyjson has enough trailing zero bytes.
        var padded = Data(count: available + paddingSize)
        buffer.withUnsafeBytes { srcBuf in
            padded.withUnsafeMutableBytes { dstBuf in
                let src = srcBuf.baseAddress!.advanced(by: readOffset)
                dstBuf.baseAddress!.copyMemory(from: src, byteCount: available)
            }
        }

        return try padded.withUnsafeBytes { padBuf -> JSONValue? in
            let ptr = padBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let result = try Document.streamParse(
                bytes: ptr, count: available, options: options
            )
            switch result {
            case .success(let doc, let consumed):
                guard let root = doc.root else {
                    throw JSONError.invalidData("Document has no root value")
                }
                readOffset += consumed
                return JSONValue(value: root, document: doc)
            case .needMoreData:
                return nil
            }
        }
    }

    // MARK: - Buffer Helpers

    private mutating func skipWhitespace() {
        let startIdx = buffer.startIndex
        while readOffset < buffer.count {
            let byte = buffer[startIdx + readOffset]
            guard byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D else { break }
            readOffset += 1
        }
    }

    private mutating func compactIfNeeded() {
        guard readOffset > 0, readOffset > buffer.count / 2 else { return }
        buffer.removeSubrange(buffer.startIndex ..< buffer.startIndex + readOffset)
        readOffset = 0
    }
}

// MARK: - JSONIncrementalReader

/// An incremental reader for large JSON documents.
///
/// Feed chunks of a single large JSON document with ``feed(_:)``.
/// Data is accumulated internally. Call ``finish()`` to parse the complete
/// document, or use ``feed(_:)`` which attempts a parse after each chunk.
///
/// ```swift
/// let reader = try JSONIncrementalReader(data: firstChunk)
/// for try await chunk in stream {
///     if let doc = try reader.feed(chunk) {
///         print(doc.root?["key"]?.string ?? "")
///         break
///     }
/// }
/// ```
///
/// - Note: For a document already fully in memory, prefer
///   ``JSONDocument/init(data:options:)`` which is faster.
///   This type is for when data arrives in chunks over the network.
public final class JSONIncrementalReader: @unchecked Sendable {

    private var buffer: Data
    private let options: JSONReadOptions
    private var finished: Bool

    /// Creates a new incremental reader with initial data.
    ///
    /// - Parameters:
    ///   - data: The first chunk of JSON data.
    ///   - options: Options for reading JSON.
    public init(data: Data, options: JSONReadOptions = .default) throws {
        self.buffer = data
        self.options = options
        self.finished = false
    }

    /// Feeds more data and attempts to parse the accumulated buffer.
    ///
    /// - Parameter data: Additional JSON data.
    /// - Returns: A ``JSONDocument`` if the buffer contains a complete document,
    ///   or `nil` if more data is needed.
    /// - Throws: ``JSONError`` for non-recoverable parse errors.
    public func feed(_ data: Data) throws -> JSONDocument? {
        guard !finished else {
            throw JSONError.invalidJSON("Incremental reader already finished")
        }
        buffer.append(data)
        return try attemptParse()
    }

    /// Signals end-of-stream and returns the completed document.
    ///
    /// All accumulated data is parsed as a single JSON document.
    ///
    /// - Returns: The parsed ``JSONDocument``.
    /// - Throws: ``JSONError`` if the document is incomplete or malformed.
    public func finish() throws -> JSONDocument {
        guard !finished else {
            throw JSONError.invalidJSON("Incremental reader already finished")
        }
        finished = true
        let doc = try Document(data: buffer, options: options)
        return JSONDocument(_document: doc)
    }

    // MARK: - Private

    private func attemptParse() throws -> JSONDocument? {
        // Try parsing the accumulated data. If it's complete, return the doc.
        // If incomplete, return nil to request more data.
        do {
            let doc = try Document(data: buffer, options: options)
            finished = true
            return JSONDocument(_document: doc)
        } catch let error as JSONError {
            // If the error indicates incomplete data, we need more
            if error.message.contains("unexpected end")
                || error.message.contains("Unexpected end")
                || error.message.contains("Empty content") {
                return nil
            }
            throw error
        }
    }
}
