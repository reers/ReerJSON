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
//#if !os(Linux)
import JJLISO8601DateFormatter
//#endif

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

// This is a workaround for the lack of a "set value only if absent" function for Dictionary.
extension Optional {
    mutating func _setIfNil(to value: Wrapped) {
        guard _fastPath(self == nil) else { return }
        self = value
    }
}

//#if os(Linux)
//nonisolated(unsafe) let _iso8601Formatter: ISO8601DateFormatter = {
//    let formatter = ISO8601DateFormatter()
//    formatter.formatOptions = .withInternetDateTime
//    return formatter
//}()
//#else
nonisolated(unsafe) let _iso8601Formatter: JJLISO8601DateFormatter = {
    let formatter = JJLISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()
//#endif
