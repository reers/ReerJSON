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

#if os(Linux)
import Foundation
#else
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

enum _CodingKey : CodingKey {
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

protocol StringEncodableDictionary { }

extension Dictionary: StringEncodableDictionary where Key == String, Value: Encodable {}

/// A protocol used to determine whether a value is an `Array` containing values that allow
/// us to bypass UnkeyedEncodingContainer overhead by directly encoding the contents as
/// strings as passing that down to the JSONWriter.
protocol EncodableArray {
    @inline(__always)
    func nonPrettyJSONRepresentation(encoder: JSONEncoderImpl, _ additionalKey: (some CodingKey)?) throws -> [UInt8]
    @inline(__always)
    func individualElementRepresentation(encoder: JSONEncoderImpl, _ additionalKey: (some CodingKey)?) throws -> ([UInt8], lengths: [Int])
}
protocol EncodableArrayElement {
//    @inline(__always)
//    func serializeJsonRepresentation(into writer: inout JSONWriter, encoder: JSONEncoderImpl, _ additionalKey: (some CodingKey)?) throws -> Int
}
extension EncodableArrayElement where Self: FixedWidthInteger & CustomStringConvertible {
//    fileprivate func serializeJsonRepresentation(into writer: inout JSONWriter, encoder: JSONEncoderImpl, _ additionalKey: (some CodingKey)?) throws -> Int {
//        return writer.serializeSimpleStringContents(description)
//    }
}
extension Int : EncodableArrayElement { }
extension Int8 : EncodableArrayElement { }
extension Int16 : EncodableArrayElement { }
extension Int32 : EncodableArrayElement { }
extension Int64 : EncodableArrayElement { }
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension Int128 : EncodableArrayElement { }
extension UInt : EncodableArrayElement { }
extension UInt8 : EncodableArrayElement { }
extension UInt16 : EncodableArrayElement { }
extension UInt32 : EncodableArrayElement { }
extension UInt64 : EncodableArrayElement { }
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension UInt128 : EncodableArrayElement { }
extension String: EncodableArrayElement {
//    fileprivate func serializeJsonRepresentation(into writer: inout JSONWriter, encoder: JSONEncoderImpl, _ additionalKey: (some CodingKey)?) -> Int {
//        return writer.serializeString(self)
//    }
}
extension Float: EncodableArrayElement {
    fileprivate func serializeJsonRepresentation(into writer: inout JSONWriter, encoder: JSONEncoderImpl, _ additionalKey: (some CodingKey)?) throws -> Int {
        switch try JSONEncoderValue.number(from: self, encoder: encoder, additionalKey) {
        case .number(let string):
            return writer.serializeSimpleStringContents(string)
        case .string(let string):
            return writer.serializeSimpleString(string)
        default:
            fatalError("Impossible JSON value type coming from number formatting")
        }
    }
}

extension Double: EncodableArrayElement {
    fileprivate func serializeJsonRepresentation(into writer: inout JSONWriter, encoder: JSONEncoderImpl, _ additionalKey: (some CodingKey)?) throws -> Int {
        switch try JSONEncoderValue.number(from: self, encoder: encoder, additionalKey) {
        case .number(let string):
            return writer.serializeSimpleStringContents(string)
        case .string(let string):
            return writer.serializeSimpleString(string)
        default:
            fatalError("Impossible JSON value type coming from number formatting")
        }
    }
}

// This is not yet extended to Double & Float. That case is more complicated, given the possibility of Infinity or NaN values, which require nonConformingFloatEncodingStrategy and the ability to throw errors.

extension Array : EncodableArray where Element: EncodableArrayElement {
    func nonPrettyJSONRepresentation(encoder: JSONEncoderImpl, _ additionalKey: (some CodingKey)?) throws -> [UInt8] {
        var writer = JSONWriter(options: encoder.options.outputFormatting)

        writer.writer(ascii: ._openbracket)

        let count = count
        if count > 0 {
            _ = try self[0].serializeJsonRepresentation(into: &writer, encoder: encoder, additionalKey)

            for idx in 1 ..< count {
                writer.writer(ascii: ._comma)
                _ = try self[idx].serializeJsonRepresentation(into: &writer, encoder: encoder, additionalKey)
            }
        }

        writer.writer(ascii: ._closebracket)
        return writer.bytes
    }
    
    func individualElementRepresentation(encoder: JSONEncoderImpl, _ additionalKey: (some CodingKey)?) throws -> ([UInt8], lengths: [Int]) {
        var writer = JSONWriter(options: encoder.options.outputFormatting)
        var byteLengths = [Int]()
        byteLengths.reserveCapacity(self.count)

        for element in self {
            let length = try element.serializeJsonRepresentation(into: &writer, encoder: encoder, additionalKey)
            byteLengths.append(length)
        }

        return (writer.bytes, lengths: byteLengths)
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
let _iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()
#else
let _iso8601Formatter: JJLISO8601DateFormatter = {
    let formatter = JJLISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()
#endif
