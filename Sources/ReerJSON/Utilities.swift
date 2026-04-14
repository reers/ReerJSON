//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation
#if !os(Linux)
import JJLISO8601DateFormatter
#endif

enum CodingPathNode: Sendable {
    case root
    indirect case node(CodingKey, CodingPathNode, depth: Int)
    indirect case indexNode(Int, CodingPathNode, depth: Int)

    var path: [CodingKey] {
        switch self {
        case .root:
            return []
        case let .node(key, parent, _):
            return parent.path + [key]
        case let .indexNode(index, parent, _):
            return parent.path + [_CodingKey(index: index)]
        }
    }

    @inline(__always)
    var depth: Int {
        switch self {
        case .root: return 0
        case .node(_, _, let depth), .indexNode(_, _, let depth): return depth
        }
    }

    @inline(__always)
    func appending(_ key: __owned (some CodingKey)?) -> CodingPathNode {
        if let key {
            return .node(key, self, depth: self.depth + 1)
        } else {
            return self
        }
    }

    @inline(__always)
    func path(byAppending key: __owned (some CodingKey)?) -> [CodingKey] {
        if let key {
            return self.path + [key]
        }
        return self.path
    }

    // Specializations for indexes, commonly used by unkeyed containers.
    @inline(__always)
    func appending(index: __owned Int) -> CodingPathNode {
        .indexNode(index, self, depth: self.depth + 1)
    }

    func path(byAppendingIndex index: __owned Int) -> [CodingKey] {
        self.path + [_CodingKey(index: index)]
    }
}

enum _CodingKey: CodingKey {
    case string(String)
    case int(Int)
    case index(Int)
    case both(String, Int)

    @inline(__always)
    public init?(stringValue: String) {
        self = .string(stringValue)
    }

    @inline(__always)
    public init?(intValue: Int) {
        self = .int(intValue)
    }

    @inline(__always)
    internal init(index: Int) {
        self = .index(index)
    }

    @inline(__always)
    init(stringValue: String, intValue: Int?) {
        if let intValue {
            self = .both(stringValue, intValue)
        } else {
            self = .string(stringValue)
        }
    }

    var stringValue: String {
        switch self {
        case let .string(str): return str
        case let .int(int): return "\(int)"
        case let .index(index): return "Index \(index)"
        case let .both(str, _): return str
        }
    }

    var intValue: Int? {
        switch self {
        case .string: return nil
        case let .int(int): return int
        case let .index(index): return index
        case let .both(_, int): return int
        }
    }

    internal static let `super` = _CodingKey.string("super")
}

protocol StringDecodableDictionary {
    static var elementType: Decodable.Type { get }
}

protocol _JSONStringDictionaryEncodableMarker {}

extension Dictionary: _JSONStringDictionaryEncodableMarker where Key == String, Value: Encodable {}

extension Dictionary: StringDecodableDictionary where Key == String, Value: Decodable {
    static var elementType: Decodable.Type { return Value.self }
}

extension JSONDecoder.KeyDecodingStrategy {
    @inline(__always)
    var isDefault: Bool {
        switch self {
        case .useDefaultKeys:
            return true
        default:
            return false
        }
    }
}

extension JSONEncoder.NonConformingFloatEncodingStrategy {
    @inline(__always)
    var isThrow: Bool {
        if case .throw = self { return true }
        return false
    }
}

// This is a workaround for the lack of a "set value only if absent" function for Dictionary.
extension Optional {
    mutating func _setIfNil(to value: Wrapped) {
        guard _fastPath(self == nil) else { return }
        self = value
    }
}

#if os(Linux)
nonisolated(unsafe) let _iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()
#else
nonisolated(unsafe) let _iso8601Formatter: JJLISO8601DateFormatter = {
    let formatter = JJLISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()
#endif


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

// MARK: - Helper Functions

@inline(__always)
func yyObjGet(
    _ obj: UnsafeMutablePointer<yyjson_val>,
    key: String
) -> UnsafeMutablePointer<yyjson_val>? {
    var tmp = key
    return tmp.withUTF8 { buf in
        guard let ptr = buf.baseAddress else { return nil }
        return yyjson_obj_getn(obj, ptr, buf.count)
    }
}

@inline(__always)
func yyFromString(
    _ string: String,
    in doc: UnsafeMutablePointer<yyjson_mut_doc>
) throws -> UnsafeMutablePointer<yyjson_mut_val> {
    var tmp = string
    return try tmp.withUTF8 { buf in
        let result: UnsafeMutablePointer<yyjson_mut_val>?
        if let ptr = buf.baseAddress {
            result = yyjson_mut_strncpy(doc, ptr, buf.count)
        } else {
            result = yyjson_mut_strn(doc, "", 0)
        }
        guard let val = result else {
            throw JSONError.invalidData("Failed to allocate string value")
        }
        return val
    }
}

/// Recursively sort object keys in-place using UTF-8 lexicographical comparison (strcmp).
/// This matches Apple's JSONEncoder behavior for typical keys, but embedded null bytes
/// may compare differently due to C string semantics.
///
/// - Note: Uses direct C string comparison via `strcmp` for optimal performance,
///   avoiding Swift String allocations during sorting.
func sortObjectKeys(_ val: UnsafeMutablePointer<yyjson_mut_val>) throws {
    typealias MutVal = UnsafeMutablePointer<yyjson_mut_val>

    if yyjson_mut_is_obj(val) {
        var pairs: [(keyVal: MutVal, val: MutVal, keyStr: UnsafePointer<CChar>)] = []
        pairs.reserveCapacity(Int(yyjson_mut_obj_size(val)))

        var iter = yyjson_mut_obj_iter()
        guard yyjson_mut_obj_iter_init(val, &iter) else {
            throw JSONError.invalidData("Failed to initialize object iterator during key sorting")
        }

        while let keyPtr = yyjson_mut_obj_iter_next(&iter) {
            guard let valPtr = yyjson_mut_obj_iter_get_val(keyPtr) else {
                throw JSONError.invalidData("Object key has no associated value during key sorting")
            }
            guard let keyStr = yyjson_mut_get_str(keyPtr) else {
                throw JSONError.invalidData("Object key is not a string during key sorting")
            }
            pairs.append((keyPtr, valPtr, keyStr))
        }

        pairs.sort { pair1, pair2 in
            return strcmp(pair1.keyStr, pair2.keyStr) < 0
        }

        guard yyjson_mut_obj_clear(val) else {
            throw JSONError.invalidData("Failed to clear object during key sorting")
        }

        for pair in pairs {
            try sortObjectKeys(pair.val)
            guard yyjson_mut_obj_add(val, pair.keyVal, pair.val) else {
                throw JSONError.invalidData("Failed to add key back to object during key sorting")
            }
        }
    } else if yyjson_mut_is_arr(val) {
        var iter = yyjson_mut_arr_iter()
        guard yyjson_mut_arr_iter_init(val, &iter) else {
            throw JSONError.invalidData("Failed to initialize array iterator during key sorting")
        }
        while let elem = yyjson_mut_arr_iter_next(&iter) {
            try sortObjectKeys(elem)
        }
    }
}
