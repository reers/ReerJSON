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
    /// Each top-level JSON value is yielded individually (JSON Lines / NDJSON).
    ///
    /// Values may be separated by any JSON whitespace (space, tab, CR, LF);
    /// strict NDJSON producers should separate values by a single `\n`.
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
///
/// ## Boundaries between chunks
///
/// JSON tokens that have an explicit terminator (strings, objects, arrays,
/// `true`/`false`/`null`) are always parsed reliably across chunk boundaries.
/// Bare numeric tokens (e.g. `123` or `1.5e10`) are inherently ambiguous when
/// a chunk ends exactly at the end of the number — the next chunk may or may
/// not continue the number. To stay correct, the parser conservatively defers
/// any value whose parse ends exactly at the buffer end; it will be yielded
/// after the next ``parse(_:)`` chunk arrives, or on ``finalize()``.
///
/// In practice, properly-formed NDJSON terminates every value with a newline,
/// so this deferral is invisible to the caller.
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
    ///   - options: Options for reading JSON. The parser internally combines
    ///     this with `YYJSON_READ_STOP_WHEN_DONE` for boundary detection.
    public init(mode: JSONStreamMode, options: JSONReadOptions = .default) {
        self.mode = mode
        self.options = options
        self.buffer = Data()
        self.readOffset = 0
        self.arrayState = .expectOpenBracket
    }

    // MARK: - Public Parse API

    /// Feeds data to the parser and returns all complete JSON values found.
    public mutating func parse(_ data: Data) throws -> [JSONValue] {
        if !data.isEmpty { buffer.append(data) }
        return try drainValues(finalizing: false)
    }

    /// Feeds raw bytes to the parser and returns all complete JSON values found.
    public mutating func parse(bytes: UnsafeBufferPointer<UInt8>) throws -> [JSONValue] {
        if let base = bytes.baseAddress, bytes.count > 0 {
            buffer.append(base, count: bytes.count)
        }
        return try drainValues(finalizing: false)
    }

    /// Signals end-of-stream and returns any remaining JSON values.
    ///
    /// After calling this method, the parser is in a finished state.
    /// Call ``reset()`` to reuse it.
    public mutating func finalize() throws -> [JSONValue] {
        let results = try drainValues(finalizing: true)
        try validateAtEndOfStream()
        return results
    }

    /// Resets the parser to its initial state, discarding all buffered data.
    public mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
        readOffset = 0
        arrayState = .expectOpenBracket
    }

    // MARK: - Internal Slice API (for streaming decoders)

    /// Feeds data and returns raw byte slices for each parsed JSON value,
    /// without constructing intermediate `JSONValue` instances. Used by the
    /// streaming decoders to avoid an extra serialize-and-reparse round-trip.
    internal mutating func parseSlices(_ data: Data) throws -> [Data] {
        if !data.isEmpty { buffer.append(data) }
        return try drainSlices(finalizing: false)
    }

    internal mutating func finalizeSlices() throws -> [Data] {
        let results = try drainSlices(finalizing: true)
        try validateAtEndOfStream()
        return results
    }

    // MARK: - Private Types

    private enum ArrayParseState: Sendable {
        case expectOpenBracket
        case expectElementOrClose
        case expectElementAfterComma
        case expectCommaOrClose
        case done
    }

    /// One parsed value's metadata.
    private struct ParsedItem {
        /// yyjson document owning the parsed value.
        let document: Document
        /// Byte range of this value in `buffer` (relative to `buffer.startIndex`).
        let range: Range<Int>
    }

    // MARK: - Drain entry points

    private mutating func drainValues(finalizing: Bool) throws -> [JSONValue] {
        compactIfNeeded()
        let items = try drainItems(finalizing: finalizing)
        var results: [JSONValue] = []
        results.reserveCapacity(items.count)
        for item in items {
            guard let root = item.document.root else {
                throw JSONError.invalidData("Document has no root value")
            }
            results.append(JSONValue(value: root, document: item.document))
        }
        return results
    }

    private mutating func drainSlices(finalizing: Bool) throws -> [Data] {
        compactIfNeeded()
        let items = try drainItems(finalizing: finalizing)
        var slices: [Data] = []
        slices.reserveCapacity(items.count)
        let start = buffer.startIndex
        for item in items {
            slices.append(buffer.subdata(in: (start + item.range.lowerBound)..<(start + item.range.upperBound)))
        }
        return slices
    }

    private mutating func drainItems(finalizing: Bool) throws -> [ParsedItem] {
        var items: [ParsedItem] = []
        switch mode {
        case .jsonLines:
            try drainJSONLines(finalizing: finalizing) { items.append($0) }
        case .jsonArray:
            try drainJSONArray(finalizing: finalizing) { items.append($0) }
        }
        return items
    }

    // MARK: - Mode-specific drain

    private mutating func drainJSONLines(
        finalizing: Bool,
        emit: (ParsedItem) throws -> Void
    ) throws {
        while true {
            skipWhitespace()
            guard readOffset < buffer.count else { break }

            guard let item = try parseOneItem(finalizing: finalizing) else { break }
            try emit(item)
        }
    }

    private mutating func drainJSONArray(
        finalizing: Bool,
        emit: (ParsedItem) throws -> Void
    ) throws {
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
                guard let item = try parseOneItem(finalizing: finalizing) else { break loop }
                try emit(item)
                arrayState = .expectCommaOrClose

            case .expectElementAfterComma:
                skipWhitespace()
                guard readOffset < buffer.count else { break loop }
                let byte = buffer[buffer.startIndex + readOffset]
                if byte == UInt8(ascii: "]") {
                    guard allowsTrailingCommas else {
                        throw JSONError.invalidJSON("Trailing comma is not allowed in JSON array stream")
                    }
                    readOffset += 1
                    arrayState = .done
                    break loop
                }
                guard let item = try parseOneItem(finalizing: finalizing) else { break loop }
                try emit(item)
                arrayState = .expectCommaOrClose

            case .expectCommaOrClose:
                skipWhitespace()
                guard readOffset < buffer.count else { break loop }
                let byte = buffer[buffer.startIndex + readOffset]
                if byte == UInt8(ascii: ",") {
                    readOffset += 1
                    arrayState = .expectElementAfterComma
                } else if byte == UInt8(ascii: "]") {
                    readOffset += 1
                    arrayState = .done
                    break loop
                } else {
                    let char = Unicode.Scalar(byte)
                    throw JSONError.invalidJSON(
                        "Expected ',' or ']' in JSON array, got '\(char)'"
                    )
                }

            case .done:
                break loop
            }
        }

        if arrayState == .done {
            try validateNoTrailingArrayContent()
        }
    }

    // MARK: - Core Parse

    /// Attempts to parse one JSON value starting at `readOffset`.
    ///
    /// Returns `nil` when more data is required to confidently advance:
    /// either yyjson reported incomplete input, or the parsed value ends
    /// exactly at the buffer end and we are not finalizing (which would be
    /// ambiguous for unterminated numeric tokens).
    private mutating func parseOneItem(finalizing: Bool) throws -> ParsedItem? {
        let available = buffer.count - readOffset
        guard available > 0 else { return nil }

        // yyjson_read_opts() in non-INSITU mode allocates its own padded buffer
        // and copies the input — so we do not need to add YYJSON_PADDING_SIZE
        // bytes ourselves here.
        let startOffset = readOffset
        let result: Document.StreamParseResult = try buffer.withUnsafeBytes { buf in
            guard let base = buf.baseAddress else { return .needMoreData }
            let ptr = base.advanced(by: startOffset).assumingMemoryBound(to: UInt8.self)
            return try Document.streamParse(bytes: ptr, count: available, options: options)
        }

        switch result {
        case .needMoreData:
            return nil
        case .success(let doc, let consumed):
            let endOffset = startOffset + consumed

            // Boundary safety:
            // A successful parse that ends exactly at the buffer end may be a
            // truncated numeric token (e.g. we have "12" so far but the source
            // is actually "123"). yyjson cannot tell the difference. Defer the
            // value until either more data arrives or the caller finalizes.
            if !finalizing && endOffset >= buffer.count {
                return nil
            }
            readOffset = endOffset
            return ParsedItem(document: doc, range: startOffset..<endOffset)
        }
    }

    // MARK: - Buffer Helpers

    private var allowsTrailingCommas: Bool {
        // `.json5` is a composite that already includes
        // YYJSON_READ_ALLOW_TRAILING_COMMAS, but check both for clarity.
        options.contains(.allowTrailingCommas) || options.contains(.json5)
    }

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

    private mutating func validateNoTrailingArrayContent() throws {
        skipWhitespace()
        guard readOffset < buffer.count else { return }
        throw JSONError.invalidJSON("Unexpected content after JSON array stream")
    }

    private mutating func validateAtEndOfStream() throws {
        skipWhitespace()
        if readOffset < buffer.count {
            if mode == .jsonArray {
                throw JSONError.invalidJSON("Unexpected end of JSON array stream")
            } else {
                throw JSONError.invalidJSON("Incomplete JSON value at end of stream")
            }
        }
        if mode == .jsonArray && arrayState != .done {
            throw JSONError.invalidJSON("Unexpected end of JSON array stream")
        }
    }
}

// MARK: - JSONIncrementalReader

/// An incremental reader for a single large JSON document.
///
/// Feed chunks of a single large JSON document with ``feed(_:)``.
/// Data is accumulated internally. ``feed(_:)`` will attempt to parse the
/// accumulated buffer after each chunk; ``finish()`` parses any remaining
/// buffered data and finalizes the reader.
///
/// ```swift
/// let reader = try JSONIncrementalReader()
/// for try await chunk in stream {
///     if let doc = try reader.feed(chunk) {
///         // doc.root is now available
///         break
///     }
/// }
/// ```
///
/// - Note: For a document already fully in memory, prefer
///   ``JSONDocument/init(data:options:)`` which is faster.
///   This type is for when data arrives in chunks over the network.
///
/// - Note: This type is internally synchronized; `feed`, `finish`, and
///   property access are safe to call concurrently from multiple threads.
///
/// - Important: Internally, ``feed(_:)`` attempts a fresh parse over the
///   entire accumulated buffer on each call. For a document of total size
///   `N` arriving as `K` chunks, the cost is `O(N · K)`. When `K` is small
///   (e.g. a handful of large network chunks) this is effectively `O(N)`.
///   If you expect a very large number of small chunks, consider buffering
///   them yourself and constructing a single ``JSONDocument`` once you've
///   received the entire document.
public final class JSONIncrementalReader: @unchecked Sendable {

    private let lock = LockedState<Void>()
    private var parser: IncrementalParser
    private var finished: Bool = false

    /// The total number of buffered input bytes.
    public var bufferedByteCount: Int {
        lock.lock(); defer { lock.unlock() }
        return parser.count
    }

    /// Creates a new incremental reader.
    ///
    /// - Parameters:
    ///   - data: An initial chunk of JSON data (may be empty).
    ///   - options: Options for reading JSON.
    public init(
        data: Data = Data(),
        options: JSONReadOptions = .default
    ) throws {
        self.parser = IncrementalParser(initialData: data, options: options)
    }

    /// Feeds more data and attempts to parse the accumulated buffer.
    ///
    /// - Parameter data: Additional JSON data (may be empty to retry).
    /// - Returns: A ``JSONDocument`` if the buffer contains a complete document,
    ///   or `nil` if more data is needed.
    /// - Throws: ``JSONError`` for non-recoverable parse errors, or if the
    ///   reader has already produced a complete document.
    public func feed(_ data: Data) throws -> JSONDocument? {
        lock.lock(); defer { lock.unlock() }
        guard !finished else {
            throw JSONError.invalidJSON("Incremental reader already finished")
        }
        parser.append(data)
        switch try parser.read() {
        case .success(let doc):
            finished = true
            return JSONDocument(_document: doc)
        case .needMoreData:
            return nil
        }
    }

    /// Signals end-of-stream and returns the completed document.
    ///
    /// - Returns: The parsed ``JSONDocument``.
    /// - Throws: ``JSONError`` if the document is incomplete or malformed.
    public func finish() throws -> JSONDocument {
        lock.lock(); defer { lock.unlock() }
        guard !finished else {
            throw JSONError.invalidJSON("Incremental reader already finished")
        }
        switch try parser.read() {
        case .success(let doc):
            finished = true
            return JSONDocument(_document: doc)
        case .needMoreData:
            throw JSONError.invalidJSON("Incomplete JSON value at end of stream")
        }
    }
}
