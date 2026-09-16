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

private extension JSONReadOptions {
    var codableStreamingOptions: JSONReadOptions {
        union(.numberAsRaw)
    }
}

// MARK: - StreamingJSONLinesDecoder

/// A streaming decoder for JSON Lines (NDJSON) format.
///
/// Each top-level JSON value in the stream is decoded into `T`.
///
/// Internally this decodes values already parsed by the underlying
/// ``JSONStreamParser``, avoiding an intermediate serialization and reparse
/// round-trip.
///
/// ```swift
/// var decoder = StreamingJSONLinesDecoder(Item.self)
/// let items1 = try decoder.parseBuffer(chunk1)
/// let items2 = try decoder.parseBuffer(chunk2)
/// let remaining = try decoder.finalize()
/// ```
public struct StreamingJSONLinesDecoder<T: Decodable & Sendable>: Sendable {

    private var parser: JSONStreamParser
    private let decoderOptions: ReerJSONDecoder.Options
    private let type: T.Type

    /// Creates a new JSON Lines streaming decoder.
    ///
    /// - Parameters:
    ///   - type: The `Decodable` type to decode each value into.
    ///   - options: Options for reading JSON.
    ///   - decoder: An optional ``ReerJSONDecoder`` with custom strategies.
    ///     If `nil`, a default decoder is used.
    public init(
        _ type: T.Type,
        options: JSONReadOptions = .default,
        decoder: ReerJSONDecoder? = nil
    ) {
        self.type = type
        self.parser = JSONStreamParser(mode: .jsonLines, options: options.codableStreamingOptions)
        self.decoderOptions = decoder?.optionsSnapshot() ?? ReerJSONDecoder.Options()
    }

    /// Feeds data to the decoder and returns all decoded values.
    public mutating func parseBuffer(_ data: Data) throws -> [T] {
        let values = try parser.parse(data)
        return try values.map { value in
            try ReerJSONDecoder.decodeParsedValue(type, from: value, options: decoderOptions)
        }
    }

    /// Signals end-of-stream and returns any remaining decoded values.
    public mutating func finalize() throws -> [T] {
        let values = try parser.finalize()
        return try values.map { value in
            try ReerJSONDecoder.decodeParsedValue(type, from: value, options: decoderOptions)
        }
    }

    /// Resets the decoder to its initial state.
    public mutating func reset() {
        parser.reset()
    }

}

// MARK: - StreamingJSONArrayDecoder

/// A streaming decoder for JSON array format.
///
/// The stream is expected to be a single JSON array. Each element is decoded
/// individually as it becomes available.
///
/// ```swift
/// var decoder = StreamingJSONArrayDecoder(Item.self)
/// let items1 = try decoder.parseBuffer(chunk1)
/// let items2 = try decoder.parseBuffer(chunk2)
/// let remaining = try decoder.finalize()
/// ```
public struct StreamingJSONArrayDecoder<T: Decodable & Sendable>: Sendable {

    private var parser: JSONStreamParser
    private let decoderOptions: ReerJSONDecoder.Options
    private let type: T.Type

    public init(
        _ type: T.Type,
        options: JSONReadOptions = .default,
        decoder: ReerJSONDecoder? = nil
    ) {
        self.type = type
        self.parser = JSONStreamParser(mode: .jsonArray, options: options.codableStreamingOptions)
        self.decoderOptions = decoder?.optionsSnapshot() ?? ReerJSONDecoder.Options()
    }

    public mutating func parseBuffer(_ data: Data) throws -> [T] {
        let values = try parser.parse(data)
        return try values.map { value in
            try ReerJSONDecoder.decodeParsedValue(type, from: value, options: decoderOptions)
        }
    }

    public mutating func finalize() throws -> [T] {
        let values = try parser.finalize()
        return try values.map { value in
            try ReerJSONDecoder.decodeParsedValue(type, from: value, options: decoderOptions)
        }
    }

    public mutating func reset() {
        parser.reset()
    }

}

// MARK: - AsyncSequence Adapters

struct PendingQueue<Element: Sendable>: Sendable {
    private var elements: [Element] = []
    private var index = 0

    var capacity: Int {
        elements.capacity
    }

    @inline(__always)
    mutating func popFirst() -> Element? {
        guard index < elements.count else { return nil }
        let element = elements[index]
        index += 1
        if index >= elements.count {
            elements.removeAll(keepingCapacity: true)
            index = 0
        }
        return element
    }

    @inline(__always)
    mutating func replace(with newElements: [Element]) {
        elements = newElements
        index = 0
    }
}

struct ByteChunkBuffer: Sendable {
    private var storage: [UInt8]

    var capacity: Int {
        storage.count
    }

    init(capacity: Int) {
        self.storage = Array(repeating: 0, count: max(1, capacity))
    }

    mutating func readChunk(
        nextByte: () async throws -> UInt8?
    ) async rethrows -> (byteCount: Int, reachedEnd: Bool) {
        var count = 0
        while count < storage.count {
            guard let byte = try await nextByte() else {
                return (count, true)
            }
            storage[count] = byte
            count += 1
        }
        return (count, false)
    }

    func withUnsafeBufferPointer<R>(
        byteCount count: Int,
        _ body: (UnsafeBufferPointer<UInt8>) throws -> R
    ) rethrows -> R {
        try storage.withUnsafeBufferPointer { buffer in
            let clampedCount = Swift.min(Swift.max(count, 0), buffer.count)
            return try body(UnsafeBufferPointer(
                start: buffer.baseAddress,
                count: clampedCount
            ))
        }
    }
}

/// An `AsyncSequence` that yields ``JSONValue`` items from chunks of `Data`.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct JSONValueStream<Source: AsyncSequence & Sendable>: AsyncSequence, Sendable
where Source.Element == Data {
    public typealias Element = JSONValue

    let source: Source
    let mode: JSONStreamMode
    let options: JSONReadOptions

    public func makeAsyncIterator() -> Iterator {
        Iterator(source: source.makeAsyncIterator(), mode: mode, options: options)
    }

    public struct Iterator: AsyncIteratorProtocol {
        var sourceIterator: Source.AsyncIterator
        var parser: JSONStreamParser
        var pending = PendingQueue<JSONValue>()
        var sourceExhausted = false

        init(source: Source.AsyncIterator, mode: JSONStreamMode, options: JSONReadOptions) {
            self.sourceIterator = source
            self.parser = JSONStreamParser(mode: mode, options: options)
        }

        public mutating func next() async throws -> JSONValue? {
            while true {
                if let value = pending.popFirst() {
                    return value
                }

                if sourceExhausted {
                    return nil
                }

                guard let chunk = try await sourceIterator.next() else {
                    sourceExhausted = true
                    let remaining = try parser.finalize()
                    if !remaining.isEmpty {
                        pending.replace(with: remaining)
                        continue
                    }
                    return nil
                }

                let values = try parser.parse(chunk)
                if !values.isEmpty {
                    pending.replace(with: values)
                }
            }
        }
    }
}

/// An `AsyncSequence` that yields ``JSONValue`` items from an `AsyncSequence` of bytes.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct JSONValueByteStream<Source: AsyncSequence & Sendable>: AsyncSequence, Sendable
where Source.Element == UInt8 {
    public typealias Element = JSONValue

    let source: Source
    let mode: JSONStreamMode
    let options: JSONReadOptions
    let chunkSize: Int

    public func makeAsyncIterator() -> Iterator {
        Iterator(
            source: source.makeAsyncIterator(),
            mode: mode, options: options,
            chunkSize: chunkSize
        )
    }

    public struct Iterator: AsyncIteratorProtocol {
        var sourceIterator: Source.AsyncIterator
        var parser: JSONStreamParser
        var pending = PendingQueue<JSONValue>()
        var sourceExhausted = false
        var chunkBuffer: ByteChunkBuffer

        init(
            source: Source.AsyncIterator,
            mode: JSONStreamMode, options: JSONReadOptions,
            chunkSize: Int
        ) {
            self.sourceIterator = source
            self.parser = JSONStreamParser(mode: mode, options: options)
            self.chunkBuffer = ByteChunkBuffer(capacity: chunkSize)
        }

        public mutating func next() async throws -> JSONValue? {
            while true {
                if let value = pending.popFirst() {
                    return value
                }

                if sourceExhausted {
                    return nil
                }

                let byteCount = try await readChunk()
                if byteCount > 0 {
                    let values = try chunkBuffer.withUnsafeBufferPointer(byteCount: byteCount) {
                        try parser.parse(bytes: $0)
                    }
                    if !values.isEmpty {
                        pending.replace(with: values)
                        continue
                    }
                }

                if sourceExhausted {
                    let remaining = try parser.finalize()
                    if !remaining.isEmpty {
                        pending.replace(with: remaining)
                        continue
                    }
                    return nil
                }
            }
        }

        /// Reads up to `chunkSize` bytes into reusable storage before
        /// passing the borrowed bytes directly to the parser.
        private mutating func readChunk() async throws -> Int {
            let chunk = try await chunkBuffer.readChunk {
                try await sourceIterator.next()
            }
            sourceExhausted = chunk.reachedEnd
            return chunk.byteCount
        }
    }
}

/// An `AsyncSequence` that decodes JSON values directly into `Decodable` types.
///
/// Internally this decodes values already parsed by ``JSONStreamParser``,
/// skipping the serialization and reparse round-trip.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct DecodingStream<T: Decodable & Sendable, Source: AsyncSequence & Sendable>:
    AsyncSequence, Sendable
where Source.Element == Data {
    public typealias Element = T

    let source: Source
    let mode: JSONStreamMode
    let options: JSONReadOptions
    let decoderOptions: ReerJSONDecoder.Options
    let type: T.Type

    public func makeAsyncIterator() -> Iterator {
        Iterator(
            source: source.makeAsyncIterator(),
            mode: mode, options: options,
            decoderOptions: decoderOptions, type: type
        )
    }

    public struct Iterator: AsyncIteratorProtocol {
        var sourceIterator: Source.AsyncIterator
        var parser: JSONStreamParser
        var pending = PendingQueue<T>()
        var sourceExhausted = false
        let decoderOptions: ReerJSONDecoder.Options
        let type: T.Type

        init(
            source: Source.AsyncIterator,
            mode: JSONStreamMode, options: JSONReadOptions,
            decoderOptions: ReerJSONDecoder.Options, type: T.Type
        ) {
            self.sourceIterator = source
            self.parser = JSONStreamParser(mode: mode, options: options.codableStreamingOptions)
            self.decoderOptions = decoderOptions
            self.type = type
        }

        public mutating func next() async throws -> T? {
            while true {
                if let value = pending.popFirst() {
                    return value
                }

                if sourceExhausted {
                    return nil
                }

                guard let chunk = try await sourceIterator.next() else {
                    sourceExhausted = true
                    let remaining = try parser.finalize()
                    if !remaining.isEmpty {
                        let decoded = try remaining.map { value in
                            try ReerJSONDecoder.decodeParsedValue(type, from: value, options: decoderOptions)
                        }
                        pending.replace(with: decoded)
                        continue
                    }
                    return nil
                }

                let values = try parser.parse(chunk)
                if !values.isEmpty {
                    let decoded = try values.map { value in
                        try ReerJSONDecoder.decodeParsedValue(type, from: value, options: decoderOptions)
                    }
                    pending.replace(with: decoded)
                }
            }
        }
    }
}

// MARK: - AsyncSequence Extensions

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension AsyncSequence where Element == Data, Self: Sendable {

    /// Returns an `AsyncSequence` of ``JSONValue`` items parsed from this
    /// data stream.
    ///
    /// - Parameters:
    ///   - mode: The stream format (`.jsonLines` or `.jsonArray`).
    ///   - options: Options for reading JSON.
    public func jsonValues(
        mode: JSONStreamMode = .jsonLines,
        options: JSONReadOptions = .default
    ) -> JSONValueStream<Self> {
        JSONValueStream(source: self, mode: mode, options: options)
    }

    /// Returns an `AsyncSequence` that decodes items from this data stream.
    ///
    /// - Parameters:
    ///   - type: The `Decodable` type to decode each value into.
    ///   - mode: The stream format (`.jsonLines` or `.jsonArray`).
    ///   - options: Options for reading JSON.
    ///   - decoder: An optional ``ReerJSONDecoder``. If `nil`, uses a default decoder.
    public func decode<T: Decodable & Sendable>(
        _ type: T.Type,
        mode: JSONStreamMode = .jsonLines,
        options: JSONReadOptions = .default,
        decoder: ReerJSONDecoder? = nil
    ) -> DecodingStream<T, Self> {
        DecodingStream(
            source: self,
            mode: mode, options: options,
            decoderOptions: decoder?.optionsSnapshot() ?? ReerJSONDecoder.Options(),
            type: type
        )
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension AsyncSequence where Element == UInt8, Self: Sendable {

    /// Returns an `AsyncSequence` of ``JSONValue`` items parsed from this
    /// byte stream.
    ///
    /// Bytes are batched internally for efficient parsing.
    ///
    /// - Parameters:
    ///   - mode: The stream format (`.jsonLines` or `.jsonArray`).
    ///   - options: Options for reading JSON.
    ///   - chunkSize: Number of bytes to batch before parsing. Default is 4096.
    public func jsonValues(
        mode: JSONStreamMode = .jsonLines,
        options: JSONReadOptions = .default,
        chunkSize: Int = 4096
    ) -> JSONValueByteStream<Self> {
        JSONValueByteStream(
            source: self, mode: mode,
            options: options, chunkSize: chunkSize
        )
    }
}
