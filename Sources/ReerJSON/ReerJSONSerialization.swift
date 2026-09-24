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

/// An object that converts between JSON and the equivalent Foundation objects.
/// This provides a drop-in replacement for Foundation's JSONSerialization using yyjson.
public enum ReerJSONSerialization {
    /// Options used when creating Foundation objects from JSON data.
    public struct ReadingOptions: OptionSet, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Specifies that arrays and dictionaries in the returned object are mutable.
        public static let mutableContainers = ReadingOptions(rawValue: 1 << 0)

        /// Specifies that leaf strings in the JSON object graph are mutable.
        public static let mutableLeaves = ReadingOptions(rawValue: 1 << 1)

        /// Specifies that the parser allows top-level objects that aren't arrays or dictionaries.
        public static let fragmentsAllowed = ReadingOptions(rawValue: 1 << 2)

        /// Specifies that reading serialized JSON data supports the JSON5 syntax.
        public static let json5Allowed = ReadingOptions(rawValue: 1 << 3)

        /// A deprecated option that specifies that the parser should allow top-level objects
        /// that aren't arrays or dictionaries.
        @available(*, deprecated, renamed: "fragmentsAllowed")
        public static let allowFragments = fragmentsAllowed
    }

    /// Options for writing JSON data.
    public struct WritingOptions: OptionSet, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Specifies that the writer should allow top-level values that aren't arrays or dictionaries.
        public static let fragmentsAllowed = WritingOptions(rawValue: 1 << 0)

        /// Specifies that the output uses white space and indentation to make the resulting data more readable.
        public static let prettyPrinted = WritingOptions(rawValue: 1 << 1)

        /// Specifies that the output sorts keys in lexicographic order.
        public static let sortedKeys = WritingOptions(rawValue: 1 << 2)

        /// Specifies that the output doesn't prefix slash characters with escape characters.
        public static let withoutEscapingSlashes = WritingOptions(rawValue: 1 << 3)

        /// Specifies that the output uses white space and 2-space indentation.
        /// This configures `prettyPrinted` to use 2-space indentation.
        public static let indentationTwoSpaces = WritingOptions(rawValue: 1 << 4)

        /// Escape non-ASCII characters in string values as `\uXXXX`, making the output ASCII only.
        /// Scalars outside the BMP are emitted as surrogate pairs.
        public static let escapeUnicode = WritingOptions(rawValue: 1 << 5)

        /// Add a single newline character `\n` at the end of the JSON.
        public static let newlineAtEnd = WritingOptions(rawValue: 1 << 6)

        /// Writes infinity and NaN values as `Infinity` and `NaN` literals.
        ///
        /// If you set `infAndNaNAsNull`, it takes precedence.
        public static let allowInfAndNaN = WritingOptions(rawValue: 1 << 7)

        /// Writes infinity and NaN values as `null` literals.
        ///
        /// This option takes precedence over `allowInfAndNaN`.
        public static let infAndNaNAsNull = WritingOptions(rawValue: 1 << 8)
    }

    /// Returns a Foundation object from given JSON data.
    /// - Parameters:
    ///   - data: The JSON data to parse.
    ///   - options: Options for reading the JSON.
    /// - Returns: A Foundation object (NSArray, NSDictionary, NSString, NSNumber, or NSNull).
    /// - Throws: `JSONError` if parsing fails.
    public static func jsonObject(with data: Data, options: ReadingOptions = []) throws -> Any {
        var readOptions: JSONReadOptions = .default
        if options.contains(.json5Allowed) {
            readOptions.insert(.json5)
        }

        let document = try DocumentRef(data: data, options: readOptions)
        guard let root = document.root else {
            throw JSONError.invalidData("Document has no root value")
        }

        let value = JSONValue(value: root, document: document)
        let result = try value.toFoundationObject(options: options)

        if options.contains(.fragmentsAllowed) {
            return result
        }

        if result is NSArray || result is NSDictionary {
            return result
        }

        throw JSONError.invalidData("Top-level JSON value must be an array or dictionary")
    }

    /// Returns JSON data from a Foundation object.
    /// - Parameters:
    ///   - obj: The Foundation object to convert (NSArray, NSDictionary, or a scalar with `.fragmentsAllowed`).
    ///          `JSONValue`, `JSONObject`, and `JSONArray` are also supported.
    ///   - options: Options for writing the JSON.
    /// - Returns: The JSON data.
    /// - Throws: `JSONError` if conversion fails.
    public static func data(withJSONObject obj: Any, options: WritingOptions = []) throws -> Data {
        if let jsonValue = obj as? JSONValue {
            return try data(withJSONValue: jsonValue, options: options)
        }
        if let jsonObject = obj as? JSONObject {
            let value = JSONValue(value: jsonObject.value, document: jsonObject.document)
            return try data(withJSONValue: value, options: options)
        }
        if let jsonArray = obj as? JSONArray {
            let value = JSONValue(value: jsonArray.value, document: jsonArray.document)
            return try data(withJSONValue: value, options: options)
        }

        let isTopLevelContainer = obj is NSArray || obj is NSDictionary
        let isFragment = obj is NSString || obj is NSNumber || obj is NSNull

        let allowNonFiniteNumbers =
            options.contains(.infAndNaNAsNull)
            || options.contains(.allowInfAndNaN)

        // Containers are validated while they are converted.
        if isFragment {
            guard options.contains(.fragmentsAllowed) else {
                throw JSONError.invalidData("Top-level JSON value must be an array or dictionary")
            }
            if !allowNonFiniteNumbers, let number = obj as? NSNumber, !number.doubleValue.isFinite {
                throw JSONError.invalidData("NaN or Infinity not allowed in JSON")
            }
        } else if !isTopLevelContainer {
            throw invalidObjectError
        }

        guard let doc = yyjson_mut_doc_new(nil) else {
            throw JSONError.invalidData("Failed to create document")
        }
        defer {
            yyjson_mut_doc_free(doc)
        }

        let root = try foundationObjectToYYJSON(obj, doc: doc, options: options)
        yyjson_mut_doc_set_root(doc, root)

        var flags: yyjson_write_flag = 0

        // Pretty printing: 2-space overrides 4-space
        if options.contains(.indentationTwoSpaces) {
            flags |= YYJSON_WRITE_PRETTY_TWO_SPACES
        } else if options.contains(.prettyPrinted) {
            flags |= YYJSON_WRITE_PRETTY
        }

        // Escaping options
        if !options.contains(.withoutEscapingSlashes) {
            flags |= YYJSON_WRITE_ESCAPE_SLASHES
        }
        if options.contains(.escapeUnicode) {
            flags |= YYJSON_WRITE_ESCAPE_UNICODE
        }

        if options.contains(.allowInfAndNaN) {
            flags |= YYJSON_WRITE_ALLOW_INF_AND_NAN
        }
        if options.contains(.infAndNaNAsNull) {
            flags |= YYJSON_WRITE_INF_AND_NAN_AS_NULL
        }

        // Formatting options
        if options.contains(.newlineAtEnd) {
            flags |= YYJSON_WRITE_NEWLINE_AT_END
        }

        var error = yyjson_write_err()
        var length: size_t = 0

        guard let jsonString = yyjson_mut_val_write_opts(root, flags, nil, &length, &error) else {
            throw JSONError(writing: error)
        }

        defer {
            free(jsonString)
        }

        return Data(bytes: jsonString, count: length)
    }

    /// Returns a Boolean value that indicates whether the serializer can convert a given object to JSON data.
    /// - Parameter obj: The object to validate.
    /// - Returns: `true` if the object can be converted to JSON, `false` otherwise.
    ///
    /// - Note: Like Foundation's `JSONSerialization`, this only returns `true` for top-level
    ///   arrays and dictionaries. Scalar values (strings, numbers, null) are only valid
    ///   when nested inside containers.
    public static func isValidJSONObject(_ obj: Any) -> Bool {
        guard obj is NSArray || obj is NSDictionary else {
            return false
        }
        return isValidJSONObjectRecursive(obj, allowNonFiniteNumbers: false)
    }

    // MARK: - Private Helpers

    private static func isValidJSONObjectRecursive(
        _ obj: Any,
        allowNonFiniteNumbers: Bool
    ) -> Bool {
        switch obj {
        case let dict as NSDictionary:
            for (key, value) in dict {
                guard key is NSString else {
                    return false
                }
                if let number = value as? NSNumber {
                    let doubleValue = number.doubleValue
                    if !allowNonFiniteNumbers && (doubleValue.isNaN || doubleValue.isInfinite) {
                        return false
                    }
                }
                if !isValidJSONObjectRecursive(value, allowNonFiniteNumbers: allowNonFiniteNumbers) {
                    return false
                }
            }
            return true

        case let arr as NSArray:
            for element in arr {
                if let number = element as? NSNumber {
                    let doubleValue = number.doubleValue
                    if !allowNonFiniteNumbers && (doubleValue.isNaN || doubleValue.isInfinite) {
                        return false
                    }
                }
                if !isValidJSONObjectRecursive(element, allowNonFiniteNumbers: allowNonFiniteNumbers) {
                    return false
                }
            }
            return true

        case is NSString, is NSNumber, is NSNull:
            return true

        default:
            return false
        }
    }

    /// Serializes a `JSONValue` without Foundation round-tripping.
    /// - Parameters:
    ///   - value: The YYJSON value to write.
    ///   - options: `ReerJSONSerialization.WritingOptions` mapped to `JSONWriteOptions`.
    ///     `withoutEscapingSlashes` maps to `escapeSlashes` being *absent*.
    private static func data(withJSONValue value: JSONValue, options: WritingOptions) throws -> Data {
        guard let rawValue = value.rawValue else {
            throw JSONError.invalidData("Value has no backing document")
        }

        let isTopLevelContainer = yyjson_is_obj(rawValue) || yyjson_is_arr(rawValue)
        if !isTopLevelContainer && !options.contains(.fragmentsAllowed) {
            throw JSONError.invalidData("Top-level JSON value must be an array or dictionary")
        }

        var writeOptions: JSONWriteOptions = []
        if options.contains(.indentationTwoSpaces) {
            writeOptions.insert(.indentationTwoSpaces)
        } else if options.contains(.prettyPrinted) {
            writeOptions.insert(.prettyPrinted)
        }
        if options.contains(.sortedKeys) {
            writeOptions.insert(.sortedKeys)
        }
        if !options.contains(.withoutEscapingSlashes) {
            writeOptions.insert(.escapeSlashes)
        }
        if options.contains(.escapeUnicode) {
            writeOptions.insert(.escapeUnicode)
        }
        if options.contains(.newlineAtEnd) {
            writeOptions.insert(.newlineAtEnd)
        }
        if options.contains(.allowInfAndNaN) {
            writeOptions.insert(.allowInfAndNaN)
        }
        if options.contains(.infAndNaNAsNull) {
            writeOptions.insert(.infAndNaNAsNull)
        }

        return try value.data(options: writeOptions)
    }

    private static let invalidObjectError = JSONError.invalidData("Invalid JSON object")

    /// Converts and validates a Foundation object graph in a single pass.
    ///
    /// Any value that `isValidJSONObject` would reject throws `invalidObjectError`.
    private static func foundationObjectToYYJSON(
        _ obj: Any,
        doc: UnsafeMutablePointer<yyjson_mut_doc>,
        options: WritingOptions
    ) throws -> UnsafeMutablePointer<yyjson_mut_val> {
        #if canImport(Darwin)
            // Class checks on AnyObject are plain `isKindOfClass` calls, whereas
            // casting `Any` goes through the much slower generic dynamic cast.
            return try foundationObjectToYYJSON(object: obj as AnyObject, doc: doc, options: options)
        #else
            switch obj {
            case let str as NSString:
                return try yyFromString(str as String, in: doc)
            case let num as NSNumber:
                return try numberToYYJSON(num, doc: doc, options: options)
            case is NSNull:
                return yyjson_mut_null(doc)
            case let arr as NSArray:
                let jsonArr = try makeArray(doc)
                for element in arr {
                    _ = yyjson_mut_arr_append(jsonArr, try foundationObjectToYYJSON(element, doc: doc, options: options))
                }
                return jsonArr
            case let dict as NSDictionary:
                let jsonObj = try makeObject(doc)
                if options.contains(.sortedKeys) {
                    for (key, value) in try sortedEntries(of: dict) {
                        try addEntry(key: key, value: value, to: jsonObj, doc: doc, options: options)
                    }
                } else {
                    for (key, value) in dict {
                        guard let keyString = key as? String else { throw invalidObjectError }
                        try addEntry(key: keyString, value: value, to: jsonObj, doc: doc, options: options)
                    }
                }
                return jsonObj
            default:
                throw invalidObjectError
            }
        #endif
    }

    #if canImport(Darwin)
        private static func foundationObjectToYYJSON(
            object: AnyObject,
            doc: UnsafeMutablePointer<yyjson_mut_doc>,
            options: WritingOptions
        ) throws -> UnsafeMutablePointer<yyjson_mut_val> {
            if let str = object as? NSString {
                return try stringToYYJSON(str, doc: doc)
            }
            if let num = object as? NSNumber {
                return try numberToYYJSON(num, doc: doc, options: options)
            }
            if let dict = object as? NSDictionary {
                let jsonObj = try makeObject(doc)
                let count = CFDictionaryGetCount(dict)
                try withUnsafeTemporaryAllocation(of: UnsafeRawPointer?.self, capacity: max(count * 2, 1)) { buffer in
                    let keys = buffer.baseAddress!, values = keys + count
                    CFDictionaryGetKeysAndValues(dict, keys, values)
                    if options.contains(.sortedKeys) {
                        var entries: [(key: String, nsKey: NSString, value: AnyObject)] = []
                        entries.reserveCapacity(count)
                        for i in 0..<count {
                            let key = Unmanaged<AnyObject>.fromOpaque(keys[i]!).takeUnretainedValue()
                            guard let keyString = key as? NSString else { throw invalidObjectError }
                            let value = Unmanaged<AnyObject>.fromOpaque(values[i]!).takeUnretainedValue()
                            entries.append((keyString as String, keyString, value))
                        }
                        entries.sort { $0.key < $1.key }
                        for entry in entries {
                            let keyVal = try stringToYYJSON(entry.nsKey, doc: doc)
                            let valueVal = try foundationObjectToYYJSON(object: entry.value, doc: doc, options: options)
                            _ = yyjson_mut_obj_add(jsonObj, keyVal, valueVal)
                        }
                    } else {
                        for i in 0..<count {
                            let key = Unmanaged<AnyObject>.fromOpaque(keys[i]!).takeUnretainedValue()
                            guard let keyString = key as? NSString else { throw invalidObjectError }
                            let value = Unmanaged<AnyObject>.fromOpaque(values[i]!).takeUnretainedValue()
                            let keyVal = try stringToYYJSON(keyString, doc: doc)
                            let valueVal = try foundationObjectToYYJSON(object: value, doc: doc, options: options)
                            _ = yyjson_mut_obj_add(jsonObj, keyVal, valueVal)
                        }
                    }
                }
                return jsonObj
            }
            if let arr = object as? NSArray {
                let jsonArr = try makeArray(doc)
                let count = CFArrayGetCount(arr)
                try withUnsafeTemporaryAllocation(of: UnsafeRawPointer?.self, capacity: max(count, 1)) { buffer in
                    CFArrayGetValues(arr, CFRange(location: 0, length: count), buffer.baseAddress!)
                    for element in buffer.prefix(count) {
                        let object = Unmanaged<AnyObject>.fromOpaque(element!).takeUnretainedValue()
                        let elementVal = try foundationObjectToYYJSON(object: object, doc: doc, options: options)
                        _ = yyjson_mut_arr_append(jsonArr, elementVal)
                    }
                }
                return jsonArr
            }
            if object is NSNull {
                return yyjson_mut_null(doc)
            }
            throw invalidObjectError
        }

        @inline(__always)
        private static func stringToYYJSON(
            _ string: NSString,
            doc: UnsafeMutablePointer<yyjson_mut_doc>
        ) throws -> UnsafeMutablePointer<yyjson_mut_val> {
            let cfString = string as CFString
            // CFStringGetCStringPtr only succeeds for ASCII storage, where the
            // UTF-16 length equals the UTF-8 byte count.
            let length = CFStringGetLength(cfString)
            let utf8 = CFStringBuiltInEncodings.UTF8.rawValue
            if let ptr = CFStringGetCStringPtr(cfString, utf8),
               let val = yyjson_mut_strncpy(doc, ptr, length) {
                return val
            }
            let capacity = CFStringGetMaximumSizeForEncoding(length, utf8)
            let val = withUnsafeTemporaryAllocation(of: CChar.self, capacity: max(capacity, 1)) { buffer -> UnsafeMutablePointer<yyjson_mut_val>? in
                let base = buffer.baseAddress!
                var used: CFIndex = 0
                let converted = base.withMemoryRebound(to: UInt8.self, capacity: buffer.count) {
                    CFStringGetBytes(cfString, CFRange(location: 0, length: length), utf8, 0, false, $0, capacity, &used)
                }
                // A short conversion means unpaired surrogates; leave those to String bridging.
                guard converted == length else { return nil }
                return yyjson_mut_strncpy(doc, base, used)
            }
            if let val {
                return val
            }
            return try yyFromString(string as String, in: doc)
        }
    #else
        private static func addEntry(
            key: String,
            value: Any,
            to jsonObj: UnsafeMutablePointer<yyjson_mut_val>,
            doc: UnsafeMutablePointer<yyjson_mut_doc>,
            options: WritingOptions
        ) throws {
            let keyVal = try yyFromString(key, in: doc)
            let valueVal = try foundationObjectToYYJSON(value, doc: doc, options: options)
            _ = yyjson_mut_obj_add(jsonObj, keyVal, valueVal)
        }

        /// Returns the entries sorted by key; throws if any key is not a string.
        private static func sortedEntries(of dict: NSDictionary) throws -> [(key: String, value: Any)] {
            var entries: [(key: String, value: Any)] = []
            entries.reserveCapacity(dict.count)
            for (key, value) in dict {
                guard let keyString = key as? String else { throw invalidObjectError }
                entries.append((keyString, value))
            }
            entries.sort { $0.key < $1.key }
            return entries
        }
    #endif

    @inline(__always)
    private static func numberToYYJSON(
        _ num: NSNumber,
        doc: UnsafeMutablePointer<yyjson_mut_doc>,
        options: WritingOptions
    ) throws -> UnsafeMutablePointer<yyjson_mut_val> {
        if isBoolNumber(num) {
            return yyjson_mut_bool(doc, num.boolValue)
        }
        switch num.objCType.pointee {
        case 0x63, 0x73, 0x69, 0x6C, 0x71:  // 'c', 's', 'i', 'l', 'q' (signed integers)
            return yyjson_mut_sint(doc, num.int64Value)
        case 0x43, 0x53, 0x49, 0x4C, 0x51:  // 'C', 'S', 'I', 'L', 'Q' (unsigned integers)
            return yyjson_mut_uint(doc, num.uint64Value)
        default:
            let doubleValue = num.doubleValue
            if !doubleValue.isFinite {
                if options.contains(.infAndNaNAsNull) {
                    return yyjson_mut_null(doc)
                }
                if options.contains(.allowInfAndNaN) {
                    return yyjson_mut_real(doc, doubleValue)
                }
                throw invalidObjectError
            }
            return yyjson_mut_real(doc, doubleValue)
        }
    }

    @inline(__always)
    private static func makeArray(_ doc: UnsafeMutablePointer<yyjson_mut_doc>) throws -> UnsafeMutablePointer<yyjson_mut_val> {
        guard let arr = yyjson_mut_arr(doc) else {
            throw JSONError.invalidData("Failed to create array")
        }
        return arr
    }

    @inline(__always)
    private static func makeObject(_ doc: UnsafeMutablePointer<yyjson_mut_doc>) throws -> UnsafeMutablePointer<yyjson_mut_val> {
        guard let obj = yyjson_mut_obj(doc) else {
            throw JSONError.invalidData("Failed to create object")
        }
        return obj
    }
}

// MARK: - JSONValue to Foundation Conversion

extension JSONValue {
    fileprivate func toFoundationObject(options: ReerJSONSerialization.ReadingOptions) throws -> Any {
        if isNull {
            return NSNull()
        }

        if let b = bool {
            return NSNumber(value: b)
        }

        if let i = int64 {
            return NSNumber(value: i)
        }

        if let n = number {
            return NSNumber(value: n)
        }

        if let s = string {
            if options.contains(.mutableLeaves) {
                return try makeMutableString(from: s)
            }
            return NSString(string: s)
        }

        if let arr = array {
            if options.contains(.mutableContainers) {
                let result = NSMutableArray()
                for element in arr {
                    result.add(try element.toFoundationObject(options: options))
                }
                return result
            } else {
                var result: [Any] = []
                result.reserveCapacity(arr.count)
                for element in arr {
                    result.append(try element.toFoundationObject(options: options))
                }
                return result as NSArray
            }
        }

        if let obj = object {
            if options.contains(.mutableContainers) {
                let result = NSMutableDictionary()
                for (key, value) in obj {
                    result[key] = try value.toFoundationObject(options: options)
                }
                return result
            } else {
                var result: [String: Any] = [:]
                for (key, value) in obj {
                    result[key] = try value.toFoundationObject(options: options)
                }
                return result as NSDictionary
            }
        }

        return NSNull()
    }
}

// MARK: - Helper Functions

#if !canImport(Darwin)
    // Cache singleton bool NSNumbers for identity comparison on Linux.
    private let nsBoolTrue = NSNumber(value: true)
    private let nsBoolFalse = NSNumber(value: false)
#endif

/// Determines whether an `NSNumber` represents a Boolean value.
///
/// On Darwin, use CoreFoundation's `CFBooleanGetTypeID()`
/// to reliably identify Boolean `NSNumber` instances.
/// On Linux (swift-corelibs-foundation),
/// `CFGetTypeID` and `CFBooleanGetTypeID` are unavailable,
/// so compare against cached singleton instances.
/// This works because Foundation reuses the same `NSNumber`
/// instances for `true` and `false`.
@inline(__always)
private func isBoolNumber(_ num: NSNumber) -> Bool {
    #if canImport(Darwin)
        return CFGetTypeID(num) == CFBooleanGetTypeID()
    #else
        return num === nsBoolTrue || num === nsBoolFalse
    #endif
}

/// Creates a mutable string from a Swift `String`.
///
/// On Darwin, initialize `NSMutableString` directly.
/// On Linux (swift-corelibs-foundation),
/// use `mutableCopy()` to ensure consistent mutability.
private func makeMutableString(from string: String) throws -> NSMutableString {
    #if canImport(Darwin)
        return NSMutableString(string: string)
    #else
        // Unlikely to fail, but prefer explicit error over force-casting.
        guard let mutable = (string as NSString).mutableCopy() as? NSMutableString else {
            throw JSONError.invalidData(
                "Failed to create mutable string copy on Linux"
            )
        }
        return mutable
    #endif
}
