//
//  Copyright © 2026 Mattt (https://github.com/mattt)
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

// MARK: - Document (Internal)

/// A safe wrapper around a yyjson document.
///
/// The document is immutable after creation and safe for concurrent reads.
internal final class Document: @unchecked Sendable {
    let doc: UnsafeMutablePointer<yyjson_doc>

    /// Retained data buffer (used when parsing consumes the input).
    private var retainedData: Data?

    /// Creates a document by parsing JSON data.
    ///
    /// - Parameters:
    ///   - data: The JSON data to parse.
    ///   - options: Options for reading the JSON.
    /// - Throws: `JSONError` if parsing fails.
    init(data: Data, options: JSONReadOptions = .default) throws {
        var error = yyjson_read_err()
        var flags = options.yyjsonFlags
        // Mask out YYJSON_READ_INSITU to prevent use-after-free issues.
        // In-place parsing must use the dedicated consuming initializer.
        flags &= ~yyjson_read_flag(YYJSON_READ_INSITU)

        self.retainedData = nil

        if data.isEmpty {
            throw JSONError.invalidJSON("Empty content")
        }

        let result = data.withUnsafeBytes { bytes -> UnsafeMutablePointer<yyjson_doc>? in
            guard let baseAddress = bytes.baseAddress else { return nil }
            let ptr = UnsafeMutablePointer(mutating: baseAddress.assumingMemoryBound(to: CChar.self))
            return yyjson_read_opts(ptr, data.count, flags, nil, &error)
        }

        guard let doc = result else {
            throw JSONError(parsing: error)
        }
        self.doc = doc
    }

    /// Creates a document by consuming mutable data.
    ///
    /// This initializer takes ownership of the provided data
    /// and parses directly within the buffer,
    /// avoiding any data copies.
    ///
    /// - Parameters:
    ///   - consuming: The data to parse.
    ///     This data will be consumed and must not be used after this call.
    ///   - options: Options for reading the JSON.
    /// - Throws: `JSONError` if parsing fails.
    init(consuming data: inout Data, options: JSONReadOptions = .default) throws {
        var error = yyjson_read_err()
        var flags = options.yyjsonFlags
        flags |= YYJSON_READ_INSITU

        if data.isEmpty {
            throw JSONError.invalidJSON("Empty content")
        }

        let paddingSize = Int(YYJSON_PADDING_SIZE)
        let originalCount = data.count

        data.reserveCapacity(originalCount + paddingSize)
        data.append(contentsOf: repeatElement(0 as UInt8, count: paddingSize))

        self.retainedData = data

        let result = self.retainedData!.withUnsafeMutableBytes { bytes -> UnsafeMutablePointer<yyjson_doc>? in
            let ptr = bytes.baseAddress?.assumingMemoryBound(to: CChar.self)
            return yyjson_read_opts(ptr, originalCount, flags, nil, &error)
        }

        guard let doc = result else {
            throw JSONError(parsing: error)
        }
        self.doc = doc
    }

    deinit {
        yyjson_doc_free(doc)
    }

    var root: UnsafeMutablePointer<yyjson_val>? {
        yyjson_doc_get_root(doc)
    }
}

// MARK: - Document (Public)

/// A parsed JSON document that owns the underlying memory.
///
/// `JSONDocument` is a move-only type
/// that represents ownership of a parsed JSON document.
/// It cannot be copied, only moved,
/// which makes resource ownership explicit at compile time.
///
/// Use `JSONDocument` when you want explicit control
/// over the lifetime of the parsed JSON data.
/// For simpler use cases,
/// use ``JSONValue/init(data:options:)`` directly,
/// which manages the document internally.
///
/// ## Example
///
/// ```swift
/// let document = try JSONDocument(data: jsonData)
/// if let root = document.root {
///     print(root["name"]?.string ?? "unknown")
/// }
/// ```
///
/// For highest performance with large documents,
/// use in-place parsing:
///
/// ```swift
/// var data = try Data(contentsOf: fileURL)
/// let document = try JSONDocument(parsingInPlace: &data)
/// // `data` is now consumed and should not be used
/// ```
public struct JSONDocument: ~Copyable, @unchecked Sendable {
    internal let _document: Document

    /// Creates a document by parsing JSON data.
    ///
    /// - Parameters:
    ///   - data: The JSON data to parse.
    ///   - options: Options for reading the JSON.
    /// - Throws: `JSONError` if parsing fails.
    public init(data: Data, options: JSONReadOptions = .default) throws {
        self._document = try Document(data: data, options: options)
    }

    /// Creates a document by parsing a JSON string.
    ///
    /// - Parameters:
    ///   - string: The JSON string to parse.
    ///   - options: Options for reading the JSON.
    /// - Throws: `JSONError` if parsing fails.
    public init(string: String, options: JSONReadOptions = .default) throws {
        guard let data = string.data(using: .utf8) else {
            throw JSONError.invalidJSON("Invalid UTF-8 string")
        }
        self._document = try Document(data: data, options: options)
    }

    /// Creates a document by parsing JSON data in place,
    /// consuming the provided data.
    ///
    /// This initializer provides the highest performance parsing
    /// by avoiding a copy of the input data.
    /// The `data` parameter is consumed during parsing
    /// and retained by the document for its lifetime.
    ///
    /// - Parameters:
    ///   - parsingInPlace: The JSON data to parse.
    ///     This data will be **consumed** by this initializer
    ///     and is no longer valid after the call.
    ///   - options: Options for reading the JSON.
    /// - Throws: `JSONError` if parsing fails.
    public init(parsingInPlace data: inout Data, options: JSONReadOptions = .default) throws {
        self._document = try Document(consuming: &data, options: options)
    }

    /// The root value of the parsed JSON document.
    ///
    /// Returns `nil` if the document has no root value.
    public var root: JSONValue? {
        guard let root = _document.root else {
            return nil
        }
        return JSONValue(value: root, document: _document)
    }

    /// The root value as an object, or `nil` if the root is not an object
    /// or if the document has no root value.
    public var rootObject: JSONObject? {
        root?.object
    }

    /// The root value as an array, or `nil` if the root is not an array
    /// or if the document has no root value.
    public var rootArray: JSONArray? {
        root?.array
    }
}

// MARK: - Value

/// A JSON value that can represent any JSON type.
///
/// `JSONValue` is safe for concurrent reads across multiple threads and tasks
/// because the underlying yyjson document is immutable after parsing.
///
/// String values are lazily converted to Swift `String`
/// when accessed via the `.string` property.
/// For zero-allocation access in performance-critical code,
/// use `.cString` to get the raw C string pointer.
public struct JSONValue: @unchecked Sendable {
    /// Backing storage for a parsed JSON value.
    /// - Note: For non-null values, the `yyjson_val` pointer is guaranteed to be non-nil
    ///   and valid for the lifetime of `document`.
    private enum Storage {
        /// Represents a JSON null value. The pointer is `nil` when initialized with a `nil` value.
        case null(UnsafeMutablePointer<yyjson_val>?)
        /// A JSON boolean with its underlying yyjson value pointer.
        case bool(Bool, UnsafeMutablePointer<yyjson_val>)
        /// A JSON integer stored as `Int64`, with its yyjson value pointer.
        case numberInt(Int64, UnsafeMutablePointer<yyjson_val>)
        /// A JSON floating-point number stored as `Double`, with its yyjson value pointer.
        case numberDouble(Double, UnsafeMutablePointer<yyjson_val>)
        /// A JSON string backed by a C string pointer and its yyjson value pointer.
        case stringPtr(UnsafePointer<CChar>, UnsafeMutablePointer<yyjson_val>)
        /// A JSON object value pointer.
        case object(UnsafeMutablePointer<yyjson_val>)
        /// A JSON array value pointer.
        case array(UnsafeMutablePointer<yyjson_val>)
    }

    /// The backing storage for the JSON value.
    private let storage: Storage

    /// The raw yyjson value pointer (used for serialization and traversal).
    /// - Note: The pointer is valid for the lifetime of `document`. It is `nil`
    ///   only when this value was initialized with a `nil` pointer.
    var rawValue: UnsafeMutablePointer<yyjson_val>? {
        switch storage {
        case .null(let ptr):
            return ptr
        case .bool(_, let ptr):
            return ptr
        case .numberInt(_, let ptr):
            return ptr
        case .numberDouble(_, let ptr):
            return ptr
        case .stringPtr(_, let ptr):
            return ptr
        case .object(let ptr):
            return ptr
        case .array(let ptr):
            return ptr
        }
    }

    /// The document that owns this value (for lifetime management).
    let document: Document

    /// Initializes from a yyjson value pointer.
    ///
    /// - Parameters:
    ///   - value: The yyjson value pointer, or `nil` for null.
    ///   - document: The document that owns this value (for lifetime management).
    init(value: UnsafeMutablePointer<yyjson_val>?, document: Document) {
        self.document = document

        guard let val = value else {
            self.storage = .null(nil)
            return
        }

        switch yyjson_get_type(val) {
        case YYJSON_TYPE_NULL:
            self.storage = .null(val)
        case YYJSON_TYPE_BOOL:
            self.storage = .bool(yyjson_get_bool(val), val)
        case YYJSON_TYPE_NUM:
            if yyjson_is_int(val) {
                self.storage = .numberInt(yyjson_get_sint(val), val)
            } else {
                self.storage = .numberDouble(yyjson_get_real(val), val)
            }
        case YYJSON_TYPE_STR:
            if let str = yyjson_get_str(val) {
                self.storage = .stringPtr(str, val)
            } else {
                self.storage = .null(val)
            }
        case YYJSON_TYPE_ARR:
            self.storage = .array(val)
        case YYJSON_TYPE_OBJ:
            self.storage = .object(val)
        default:
            self.storage = .null(val)
        }
    }

    /// Whether this value is null.
    public var isNull: Bool {
        if case .null = storage { return true }
        return false
    }

    /// Accesses a value in an object by key.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value at the key,
    ///   or `nil` if not found or not an object.
    public subscript(key: String) -> JSONValue? {
        guard case .object(let ptr) = storage else { return nil }
        guard let val = yyObjGet(ptr, key: key) else { return nil }
        return JSONValue(value: val, document: document)
    }

    /// Accesses a value in an array by index.
    ///
    /// - Parameter index: The index to access.
    /// - Returns: The value at the index,
    ///   or `nil` if out of bounds or not an array.
    public subscript(index: Int) -> JSONValue? {
        guard case .array(let ptr) = storage else { return nil }
        guard let val = yyjson_arr_get(ptr, index) else { return nil }
        return JSONValue(value: val, document: document)
    }

    /// Get the string value, or nil if not a string.
    ///
    /// This property converts the underlying C string to a Swift `String`,
    /// which involves a copy.
    /// For zero-allocation access in hot paths, use `.cString` instead.
    public var string: String? {
        if case .stringPtr(let ptr, _) = storage {
            return String(cString: ptr)
        }
        return nil
    }

    /// Get the raw C string pointer, or nil if not a string.
    ///
    /// This provides zero-allocation access to the string data. The pointer
    /// is valid for the lifetime of the `JSONValue` and its underlying document.
    ///
    /// - Warning: Do not use this pointer after the `JSONValue`
    ///            or its originating document has been deallocated.
    public var cString: UnsafePointer<CChar>? {
        if case .stringPtr(let ptr, _) = storage { return ptr }
        return nil
    }

    /// The integer value as `Int64`, or `nil` if not stored as an integer.
    ///
    /// JSON numbers that were parsed as integers (e.g. `42`, `9007199254740993`)
    /// are returned exactly. Floating-point numbers (e.g. `3.14`, `1.0`) return `nil`.
    /// Use ``number`` when a `Double` approximation is acceptable.
    public var int64: Int64? {
        if case .numberInt(let v, _) = storage { return v }
        return nil
    }

    /// The number value as `Double`, or `nil` if not a number.
    ///
    /// Both integers and floating-point numbers are returned as `Double`.
    /// For integers larger than 2^53, this conversion is lossy.
    /// Use ``int64`` when exact integer precision is needed.
    public var number: Double? {
        switch storage {
        case .numberInt(let value, _):
            return Double(value)
        case .numberDouble(let value, _):
            return value
        default:
            return nil
        }
    }

    /// The Boolean value, or `nil` if not a Boolean.
    public var bool: Bool? {
        if case .bool(let b, _) = storage { return b }
        return nil
    }

    /// The object value, or `nil` if not an object.
    public var object: JSONObject? {
        guard case .object(let ptr) = storage else { return nil }
        return JSONObject(value: ptr, document: document)
    }

    /// The array value, or `nil` if not an array.
    public var array: JSONArray? {
        guard case .array(let ptr) = storage else { return nil }
        return JSONArray(value: ptr, document: document)
    }
}

extension JSONValue: CustomStringConvertible {
    public var description: String {
        switch storage {
        case .null:
            return "null"
        case .bool(let b, _):
            return b ? "true" : "false"
        case .numberInt(let n, _):
            return String(n)
        case .numberDouble(let n, _):
            return String(n)
        case .stringPtr(let ptr, _):
            return "\"\(String(cString: ptr))\""
        case .object(let ptr):
            return JSONObject(value: ptr, document: document).description
        case .array(let ptr):
            return JSONArray(value: ptr, document: document).description
        }
    }
}

// MARK: - JSON Object

/// A JSON object providing key-value access.
///
/// `JSONObject` is safe for concurrent reads across multiple threads and tasks
/// because the underlying yyjson document is immutable after parsing.
public struct JSONObject: @unchecked Sendable {
    internal let value: UnsafeMutablePointer<yyjson_val>
    internal let document: Document

    internal init(value: UnsafeMutablePointer<yyjson_val>, document: Document) {
        self.value = value
        self.document = document
    }

    /// Accesses a value by key.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value at the key, or `nil` if not found.
    public subscript(key: String) -> JSONValue? {
        guard let val = yyObjGet(value, key: key) else {
            return nil
        }
        return JSONValue(value: val, document: document)
    }

    /// Returns a Boolean value indicating whether the object contains the given key.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists; otherwise, `false`.
    public func contains(_ key: String) -> Bool {
        yyObjGet(value, key: key) != nil
    }

    /// All keys in the object.
    public var keys: [String] {
        let count = Int(yyjson_get_len(value))
        var keys: [String] = []
        keys.reserveCapacity(count)
        var iter = yyjson_obj_iter_with(value)
        while let keyVal = yyjson_obj_iter_next(&iter) {
            if let keyStr = yyjson_get_str(keyVal) {
                keys.append(String(cString: keyStr))
            }
        }
        return keys
    }
}

extension JSONObject: Sequence {
    public func makeIterator() -> JSONObjectIterator {
        JSONObjectIterator(value: value, document: document)
    }
}

/// Iterator for JSON object key-value pairs.
public struct JSONObjectIterator: IteratorProtocol {
    private let value: UnsafeMutablePointer<yyjson_val>
    private let document: Document
    private var iterator: yyjson_obj_iter

    internal init(value: UnsafeMutablePointer<yyjson_val>, document: Document) {
        self.value = value
        self.document = document
        self.iterator = yyjson_obj_iter_with(value)
    }

    public mutating func next() -> (key: String, value: JSONValue)? {
        guard let keyVal = yyjson_obj_iter_next(&iterator) else {
            return nil
        }
        guard let keyStr = yyjson_get_str(keyVal) else {
            return nil
        }
        let val = yyjson_obj_iter_get_val(keyVal)
        return (
            key: String(cString: keyStr),
            value: JSONValue(value: val, document: document)
        )
    }
}

extension JSONObject: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        for (key, value) in self {
            parts.append("\"\(key)\": \(value.description)")
        }
        return "{\(parts.joined(separator: ", "))}"
    }
}

// MARK: - JSON Array

/// A JSON array providing indexed access.
///
/// `JSONArray` is safe for concurrent reads across multiple threads and tasks
/// because the underlying yyjson document is immutable after parsing.
public struct JSONArray: @unchecked Sendable {
    internal let value: UnsafeMutablePointer<yyjson_val>
    internal let document: Document

    internal init(value: UnsafeMutablePointer<yyjson_val>, document: Document) {
        self.value = value
        self.document = document
    }

    /// Accesses a value by index.
    ///
    /// - Parameter index: The index to access.
    /// - Returns: The value at the index, or `nil` if out of bounds.
    public subscript(index: Int) -> JSONValue? {
        guard let val = yyjson_arr_get(value, index) else {
            return nil
        }
        return JSONValue(value: val, document: document)
    }

    /// The number of elements in the array.
    public var count: Int {
        Int(yyjson_get_len(value))
    }
}

extension JSONArray: Sequence {
    public func makeIterator() -> JSONArrayIterator {
        JSONArrayIterator(value: value, document: document)
    }
}

/// Iterator for JSON array elements.
public struct JSONArrayIterator: IteratorProtocol {
    private let value: UnsafeMutablePointer<yyjson_val>
    private let document: Document
    private var iterator: yyjson_arr_iter

    internal init(value: UnsafeMutablePointer<yyjson_val>, document: Document) {
        self.value = value
        self.document = document
        self.iterator = yyjson_arr_iter_with(value)
    }

    public mutating func next() -> JSONValue? {
        guard let val = yyjson_arr_iter_next(&iterator) else {
            return nil
        }
        return JSONValue(value: val, document: document)
    }
}

extension JSONArray: CustomStringConvertible {
    public var description: String {
        let elements = self.map { $0.description }
        return "[\(elements.joined(separator: ", "))]"
    }
}

// MARK: - Parsing

extension JSONValue {
    /// Creates a JSON value by parsing JSON data.
    ///
    /// - Parameters:
    ///   - data: The JSON data to parse.
    ///   - options: Options for reading the JSON.
    /// - Throws: `JSONError` if parsing fails.
    public init(data: Data, options: JSONReadOptions = .default) throws {
        let document = try Document(data: data, options: options)
        guard let root = document.root else {
            throw JSONError.invalidData("Document has no root value")
        }
        self.init(value: root, document: document)
    }

    /// Creates a JSON value by parsing a JSON string.
    ///
    /// - Parameters:
    ///   - string: The JSON string to parse.
    ///   - options: Options for reading the JSON.
    /// - Throws: `JSONError` if parsing fails.
    public init(string: String, options: JSONReadOptions = .default) throws {
        guard let data = string.data(using: .utf8) else {
            throw JSONError.invalidJSON("Invalid UTF-8 string")
        }
        try self.init(data: data, options: options)
    }

    /// Parses JSON data in place, consuming the provided data.
    ///
    /// This method provides the highest performance parsing by:
    /// 1. Avoiding a copy of the input data
    ///    (yyjson parses directly in the buffer)
    /// 2. Lazily converting strings to Swift `String` only when accessed
    ///
    /// The `data` parameter is consumed during parsing
    /// and retained by the returned `JSONValue` for its lifetime.
    /// After calling this method,
    /// the original binding is no longer valid.
    ///
    /// - Parameters:
    ///   - data: The JSON data to parse.
    ///     This data will be **consumed** by this method
    ///     and is no longer valid after the call.
    ///   - options: Options for reading the JSON.
    /// - Returns: The parsed JSON value.
    /// - Throws: `JSONError` if parsing fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var data = try Data(contentsOf: fileURL)
    /// let json = try JSONValue.parseInPlace(consuming: &data)
    /// // `data` is now consumed — compiler prevents further use
    /// ```
    ///
    /// - Note: For most use cases,
    ///   the standard ``init(data:options:)`` initializer is sufficient.
    ///   Use this method when parsing performance is critical
    ///   and you can accept the ownership semantics.
    public static func parseInPlace(consuming data: inout Data, options: JSONReadOptions = .default) throws
        -> JSONValue
    {
        let document = try Document(consuming: &data, options: options)
        guard let root = document.root else {
            throw JSONError.invalidData("Document has no root value")
        }
        return JSONValue(value: root, document: document)
    }
}

// MARK: - Writing

extension JSONValue {
    /// Returns JSON data for this value.
    /// - Parameter options: Options for writing JSON.
    /// - Returns: The encoded JSON data.
    /// - Throws: `JSONError` if writing fails.
    public func data(options: JSONWriteOptions = .default) throws -> Data {
        guard let rawValue = rawValue else {
            throw JSONError.invalidData("Value has no backing document")
        }

        var error = yyjson_write_err()
        var length: size_t = 0
        var jsonString: UnsafeMutablePointer<CChar>?

        if options.contains(.sortedKeys) {
            guard let doc = yyjson_mut_doc_new(nil) else {
                throw JSONError.invalidData("Failed to create document")
            }
            defer {
                yyjson_mut_doc_free(doc)
            }

            guard let mutableValue = yyjson_val_mut_copy(doc, rawValue) else {
                throw JSONError.invalidData("Failed to copy value")
            }

            try sortObjectKeys(mutableValue)
            jsonString = yyjson_mut_val_write_opts(mutableValue, options.yyjsonFlags, nil, &length, &error)
        } else {
            jsonString = yyjson_val_write_opts(rawValue, options.yyjsonFlags, nil, &length, &error)
        }

        guard let jsonString else {
            throw JSONError(writing: error)
        }

        defer {
            free(jsonString)
        }

        return Data(bytes: jsonString, count: length)
    }
}
