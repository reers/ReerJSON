//
//  Copyright © 2024 swiftlang.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Copyright © 2025 reers.
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
import yyjson

#if !os(Linux)
import JJLISO8601DateFormatter
#endif

class JSONEncoderImpl: Encoder {
    let doc: UnsafeMutablePointer<yyjson_mut_doc>
    let options: ReerJSONEncoder.Options
    var codingPath: [CodingKey]

    var userInfo: [CodingUserInfoKey: Any] { options.userInfo }

    var singleValue: UnsafeMutablePointer<yyjson_mut_val>?
    var array: UnsafeMutablePointer<yyjson_mut_val>?
    var object: UnsafeMutablePointer<yyjson_mut_val>?

    init(doc: UnsafeMutablePointer<yyjson_mut_doc>, codingPath: [CodingKey], options: ReerJSONEncoder.Options) {
        self.doc = doc
        self.codingPath = codingPath
        self.options = options
    }

    @inline(__always)
    func takeValue() -> UnsafeMutablePointer<yyjson_mut_val>? {
        if let object { return object }
        if let array { return array }
        return singleValue
    }

    // MARK: - Encoder Methods

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        if let object {
            return KeyedEncodingContainer(YYJSONKeyedEncodingContainer<Key>(impl: self, codingPath: codingPath, object: object))
        }
        if let sv = singleValue, yyjson_mut_is_obj(sv) {
            self.object = sv; self.singleValue = nil
            return KeyedEncodingContainer(YYJSONKeyedEncodingContainer<Key>(impl: self, codingPath: codingPath, object: sv))
        }
        guard singleValue == nil, array == nil else {
            preconditionFailure("Attempt to push new keyed encoding container when already previously encoded at this path.")
        }
        let obj = yyjson_mut_obj(doc)!
        self.object = obj
        return KeyedEncodingContainer(YYJSONKeyedEncodingContainer<Key>(impl: self, codingPath: codingPath, object: obj))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        if let array { return YYJSONUnkeyedEncodingContainer(impl: self, codingPath: codingPath, array: array) }
        if let sv = singleValue, yyjson_mut_is_arr(sv) {
            self.array = sv; self.singleValue = nil
            return YYJSONUnkeyedEncodingContainer(impl: self, codingPath: codingPath, array: sv)
        }
        guard singleValue == nil, object == nil else {
            preconditionFailure("Attempt to push new unkeyed encoding container when already previously encoded at this path.")
        }
        let arr = yyjson_mut_arr(doc)!
        self.array = arr
        return YYJSONUnkeyedEncodingContainer(impl: self, codingPath: codingPath, array: arr)
    }

    func singleValueContainer() -> SingleValueEncodingContainer { self }

    // MARK: - Primitive Value Helpers

    @inline(__always) func wrapInt(_ v: some FixedWidthInteger & SignedInteger) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_sint(doc, Int64(v)) }
    @inline(__always) func wrapUInt(_ v: some FixedWidthInteger & UnsignedInteger) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_uint(doc, UInt64(v)) }

    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    @inline(__always) func wrapInt128(_ v: Int128) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_rawcpy(doc, String(v)) }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    @inline(__always) func wrapUInt128(_ v: UInt128) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_rawcpy(doc, String(v)) }
    #endif

    @inline(__always)
    func wrapFloat<T: BinaryFloatingPoint & CustomStringConvertible>(_ float: T, for additionalKey: CodingKey?) throws -> UnsafeMutablePointer<yyjson_mut_val> {
        guard !float.isNaN, !float.isInfinite else {
            return try wrapNonConformingFloat(float, for: additionalKey)
        }
        let d = Double(float)
        if T.self == Double.self && d != d.rounded(.towardZero) {
            return yyjson_mut_double(doc, d)
        }
        var s = float.description
        if s.hasSuffix(".0") { s.removeLast(2) }
        return yyjson_mut_rawcpy(doc, s)
    }

    @inline(never)
    private func wrapNonConformingFloat<T: BinaryFloatingPoint & CustomStringConvertible>(_ float: T, for additionalKey: CodingKey?) throws -> UnsafeMutablePointer<yyjson_mut_val> {
        if case .convertToString(let posInf, let negInf, let nan) = options.nonConformingFloatEncodingStrategy {
            switch float {
            case T.infinity: return wrapString(posInf)
            case -T.infinity: return wrapString(negInf)
            default: return wrapString(nan)
            }
        }
        var path = codingPath
        if let additionalKey { path.append(additionalKey) }
        throw EncodingError.invalidValue(float, .init(codingPath: path, debugDescription: "Unable to encode \(T.self).\(float) directly in JSON."))
    }

    @inline(__always)
    func wrapString(_ string: String) -> UnsafeMutablePointer<yyjson_mut_val> {
        var s = string
        return s.withUTF8 { buf in
            yyjson_mut_strncpy(doc, buf.baseAddress, buf.count)
        }
    }

    // MARK: - Generic Encodable wrapping (T.self == for fast dispatch)

    func wrapGenericEncodable<T: Encodable>(_ value: T, for additionalKey: CodingKey?) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        // Fast-path: special Foundation types (most commonly encountered)
        if T.self == Date.self { return try wrapDateValue(value as! Date, for: additionalKey) }
        if T.self == Data.self { return try wrapDataValue(value as! Data, for: additionalKey) }
        if T.self == URL.self { return wrapString((value as! URL).absoluteString) }
        if T.self == Decimal.self { return yyjson_mut_rawcpy(doc, (value as! Decimal).description) }

        #if compiler(>=6.0)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            if T.self == Int128.self { return wrapInt128(value as! Int128) }
            if T.self == UInt128.self { return wrapUInt128(value as! UInt128) }
        }
        #endif

        if T.self is _JSONStringDictionaryEncodableMarker.Type, let dict = value as? [String: Encodable] {
            return try wrapStringKeyedDictValue(dict, for: additionalKey)
        }

        if T.self == [Double].self { return wrapBulkDoubleArray(value as! [Double]) }
        if T.self == [[Double]].self { return wrapNestedDoubleArray(value as! [[Double]]) }
        if T.self == [[[Double]]].self { return wrapTripleNestedDoubleArray(value as! [[[Double]]]) }
        if T.self == [String].self { return wrapBulkStringArray(value as! [String]) }
        if T.self == [Bool].self { return wrapBulkBoolArray(value as! [Bool]) }
        if T.self == [Int].self { return wrapBulkIntArray(value as! [Int]) }
        if T.self == [Int8].self { return wrapBulkInt8Array(value as! [Int8]) }
        if T.self == [Int16].self { return wrapBulkInt16Array(value as! [Int16]) }
        if T.self == [Int32].self { return wrapBulkInt32Array(value as! [Int32]) }
        if T.self == [Int64].self { return wrapBulkInt64Array(value as! [Int64]) }
        if T.self == [UInt].self { return wrapBulkUIntArray(value as! [UInt]) }
        if T.self == [UInt8].self { return wrapBulkUInt8Array(value as! [UInt8]) }
        if T.self == [UInt16].self { return wrapBulkUInt16Array(value as! [UInt16]) }
        if T.self == [UInt32].self { return wrapBulkUInt32Array(value as! [UInt32]) }
        if T.self == [UInt64].self { return wrapBulkUInt64Array(value as! [UInt64]) }
        if T.self == [Float].self { return try wrapFloatArray(value as! [Float]) }

        return try _encodeNestedValue(for: additionalKey) { try value.encode(to: self) }
    }

    func wrapEncodable(_ value: Encodable, for additionalKey: CodingKey?) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        if let date = value as? Date { return try wrapDateValue(date, for: additionalKey) }
        if let data = value as? Data { return try wrapDataValue(data, for: additionalKey) }
        if let url = value as? URL { return wrapString(url.absoluteString) }
        if let decimal = value as? Decimal { return yyjson_mut_rawcpy(doc, decimal.description) }
        if value is _JSONStringDictionaryEncodableMarker, let dict = value as? [String: Encodable] {
            return try wrapStringKeyedDictValue(dict, for: additionalKey)
        }
        #if compiler(>=6.0)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            if let i128 = value as? Int128 { return wrapInt128(i128) }
            if let u128 = value as? UInt128 { return wrapUInt128(u128) }
        }
        #endif

        return try _encodeNestedValue(for: additionalKey) { try value.encode(to: self) }
    }

    /// Reuse this encoder for a nested value.encode(to:) call, avoiding array copy + object allocation.
    @inline(__always)
    private func _encodeNestedValue(for additionalKey: CodingKey?, body: () throws -> Void) rethrows -> UnsafeMutablePointer<yyjson_mut_val>? {
        if let key = additionalKey { codingPath.append(key) }
        let savedSV = singleValue; let savedArr = array; let savedObj = object
        singleValue = nil; array = nil; object = nil
        defer {
            singleValue = savedSV; array = savedArr; object = savedObj
            if additionalKey != nil { codingPath.removeLast() }
        }
        try body()
        return takeValue()
    }

    // MARK: - Bulk array fast paths (single C call, zero Swift loop)

    @inline(__always) func wrapBulkDoubleArray(_ arr: [Double]) -> UnsafeMutablePointer<yyjson_mut_val> {
        if options.nonConformingFloatEncodingStrategy.isThrow {
            return arr.withUnsafeBufferPointer { yyjson_mut_arr_with_double(doc, $0.baseAddress, $0.count) }
        }
        let result = yyjson_mut_arr(doc)!
        for d in arr {
            if d != d.rounded(.towardZero) && !d.isNaN && !d.isInfinite {
                yyjson_mut_arr_add_real(doc, result, d)
            } else {
                yyjson_mut_arr_append(result, (try? wrapFloat(d, for: nil)) ?? yyjson_mut_null(doc))
            }
        }
        return result
    }
    @inline(__always) func wrapBulkBoolArray(_ arr: [Bool]) -> UnsafeMutablePointer<yyjson_mut_val> {
        arr.withUnsafeBufferPointer { yyjson_mut_arr_with_bool(doc, $0.baseAddress, $0.count) }
    }
    @inline(__always) func wrapBulkInt8Array(_ arr: [Int8]) -> UnsafeMutablePointer<yyjson_mut_val> {
        arr.withUnsafeBufferPointer { yyjson_mut_arr_with_sint8(doc, $0.baseAddress, $0.count) }
    }
    @inline(__always) func wrapBulkInt16Array(_ arr: [Int16]) -> UnsafeMutablePointer<yyjson_mut_val> {
        arr.withUnsafeBufferPointer { yyjson_mut_arr_with_sint16(doc, $0.baseAddress, $0.count) }
    }
    @inline(__always) func wrapBulkInt32Array(_ arr: [Int32]) -> UnsafeMutablePointer<yyjson_mut_val> {
        arr.withUnsafeBufferPointer { yyjson_mut_arr_with_sint32(doc, $0.baseAddress, $0.count) }
    }
    @inline(__always) func wrapBulkInt64Array(_ arr: [Int64]) -> UnsafeMutablePointer<yyjson_mut_val> {
        arr.withUnsafeBufferPointer { yyjson_mut_arr_with_sint64(doc, $0.baseAddress, $0.count) }
    }
    @inline(__always) func wrapBulkIntArray(_ arr: [Int]) -> UnsafeMutablePointer<yyjson_mut_val> {
        let mapped = arr.map { Int64($0) }
        return mapped.withUnsafeBufferPointer { yyjson_mut_arr_with_sint64(doc, $0.baseAddress, $0.count) }
    }
    @inline(__always) func wrapBulkUInt8Array(_ arr: [UInt8]) -> UnsafeMutablePointer<yyjson_mut_val> {
        arr.withUnsafeBufferPointer { yyjson_mut_arr_with_uint8(doc, $0.baseAddress, $0.count) }
    }
    @inline(__always) func wrapBulkUInt16Array(_ arr: [UInt16]) -> UnsafeMutablePointer<yyjson_mut_val> {
        arr.withUnsafeBufferPointer { yyjson_mut_arr_with_uint16(doc, $0.baseAddress, $0.count) }
    }
    @inline(__always) func wrapBulkUInt32Array(_ arr: [UInt32]) -> UnsafeMutablePointer<yyjson_mut_val> {
        arr.withUnsafeBufferPointer { yyjson_mut_arr_with_uint32(doc, $0.baseAddress, $0.count) }
    }
    @inline(__always) func wrapBulkUInt64Array(_ arr: [UInt64]) -> UnsafeMutablePointer<yyjson_mut_val> {
        arr.withUnsafeBufferPointer { yyjson_mut_arr_with_uint64(doc, $0.baseAddress, $0.count) }
    }
    @inline(__always) func wrapBulkUIntArray(_ arr: [UInt]) -> UnsafeMutablePointer<yyjson_mut_val> {
        let mapped = arr.map { UInt64($0) }
        return mapped.withUnsafeBufferPointer { yyjson_mut_arr_with_uint64(doc, $0.baseAddress, $0.count) }
    }
    @inline(__always) func wrapBulkStringArray(_ arr: [String]) -> UnsafeMutablePointer<yyjson_mut_val> {
        let result = yyjson_mut_arr(doc)!
        for s in arr { yyjson_mut_arr_append(result, wrapString(s)) }
        return result
    }
    @inline(__always) func wrapFloatArray(_ arr: [Float]) throws -> UnsafeMutablePointer<yyjson_mut_val> {
        let result = yyjson_mut_arr(doc)!
        for f in arr { yyjson_mut_arr_append(result, try wrapFloat(f, for: nil)) }
        return result
    }

    // MARK: - Nested double array fast paths (Canada-killer)

    func wrapNestedDoubleArray(_ arr: [[Double]]) -> UnsafeMutablePointer<yyjson_mut_val> {
        let result = yyjson_mut_arr(doc)!
        for inner in arr { yyjson_mut_arr_append(result, wrapBulkDoubleArray(inner)) }
        return result
    }

    func wrapTripleNestedDoubleArray(_ arr: [[[Double]]]) -> UnsafeMutablePointer<yyjson_mut_val> {
        let result = yyjson_mut_arr(doc)!
        for inner in arr { yyjson_mut_arr_append(result, wrapNestedDoubleArray(inner)) }
        return result
    }

    // MARK: - Date / Data / Dict wrapping

    func wrapDateValue(_ date: Date, for additionalKey: CodingKey?) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        switch options.dateEncodingStrategy {
        case .deferredToDate:
            return try _encodeNestedValue(for: additionalKey) { try date.encode(to: self) }
        case .secondsSince1970:
            return try wrapFloat(date.timeIntervalSince1970, for: additionalKey)
        case .millisecondsSince1970:
            return try wrapFloat(1000.0 * date.timeIntervalSince1970, for: additionalKey)
        case .iso8601:
            return wrapString(_iso8601Formatter.string(from: date))
        case .formatted(let formatter):
            return wrapString(formatter.string(from: date))
        case .custom(let closure):
            return try _encodeNestedValue(for: additionalKey) { try closure(date, self) } ?? yyjson_mut_obj(doc)
        @unknown default: fatalError()
        }
    }

    func wrapDataValue(_ data: Data, for additionalKey: CodingKey?) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        switch options.dataEncodingStrategy {
        case .deferredToData:
            return try _encodeNestedValue(for: additionalKey) { try data.encode(to: self) }
        case .base64:
            return wrapString(data.base64EncodedString())
        case .custom(let closure):
            return try _encodeNestedValue(for: additionalKey) { try closure(data, self) } ?? yyjson_mut_obj(doc)
        @unknown default: fatalError()
        }
    }

    func wrapStringKeyedDictValue(_ dict: [String: Encodable], for additionalKey: CodingKey?) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        let obj = yyjson_mut_obj(doc)!
        let savedPath = codingPath
        if let additionalKey { codingPath.append(additionalKey) }
        for (key, value) in dict {
            let keyVal = wrapString(key)
            let val = try wrapEncodable(value, for: _CodingKey(stringValue: key)!) ?? yyjson_mut_obj(doc)!
            yyjson_mut_obj_add(obj, keyVal, val)
        }
        codingPath = savedPath
        return obj
    }

    // MARK: - Key encoding strategy

    @inline(__always)
    func convertedKey(_ key: CodingKey) -> String {
        switch options.keyEncodingStrategy {
        case .useDefaultKeys: return key.stringValue
        case .convertToSnakeCase: return Self._convertToSnakeCase(key.stringValue)
        case .custom(let converter): return converter(codingPath + [key]).stringValue
        @unknown default: return key.stringValue
        }
    }

    static func _convertToSnakeCase(_ stringKey: String) -> String {
        guard !stringKey.isEmpty else { return stringKey }
        var words: [Range<String.Index>] = []
        var wordStart = stringKey.startIndex
        var searchRange = stringKey.index(after: wordStart)..<stringKey.endIndex
        while let upperCaseRange = stringKey[searchRange].rangeOfCharacter(from: .uppercaseLetters) {
            words.append(wordStart..<upperCaseRange.lowerBound)
            searchRange = upperCaseRange.lowerBound..<searchRange.upperBound
            guard let lowerCaseRange = stringKey[searchRange].rangeOfCharacter(from: .lowercaseLetters) else {
                wordStart = searchRange.lowerBound; break
            }
            let next = stringKey.index(after: upperCaseRange.lowerBound)
            if lowerCaseRange.lowerBound == next {
                wordStart = upperCaseRange.lowerBound
            } else {
                let before = stringKey.index(before: lowerCaseRange.lowerBound)
                words.append(upperCaseRange.lowerBound..<before)
                wordStart = before
            }
            searchRange = lowerCaseRange.upperBound..<searchRange.upperBound
        }
        words.append(wordStart..<searchRange.upperBound)
        return words.map { stringKey[$0].lowercased() }.joined(separator: "_")
    }
}

// MARK: - SingleValueEncodingContainer

extension JSONEncoderImpl: SingleValueEncodingContainer {
    func encodeNil() throws { singleValue = yyjson_mut_null(doc) }
    func encode(_ value: Bool) throws { singleValue = yyjson_mut_bool(doc, value) }
    func encode(_ value: String) throws { singleValue = wrapString(value) }
    func encode(_ value: Double) throws { singleValue = try wrapFloat(value, for: nil) }
    func encode(_ value: Float) throws { singleValue = try wrapFloat(value, for: nil) }
    func encode(_ value: Int) throws { singleValue = wrapInt(value) }
    func encode(_ value: Int8) throws { singleValue = wrapInt(value) }
    func encode(_ value: Int16) throws { singleValue = wrapInt(value) }
    func encode(_ value: Int32) throws { singleValue = wrapInt(value) }
    func encode(_ value: Int64) throws { singleValue = wrapInt(value) }
    func encode(_ value: UInt) throws { singleValue = wrapUInt(value) }
    func encode(_ value: UInt8) throws { singleValue = wrapUInt(value) }
    func encode(_ value: UInt16) throws { singleValue = wrapUInt(value) }
    func encode(_ value: UInt32) throws { singleValue = wrapUInt(value) }
    func encode(_ value: UInt64) throws { singleValue = wrapUInt(value) }
    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func encode(_ value: Int128) throws { singleValue = wrapInt128(value) }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func encode(_ value: UInt128) throws { singleValue = wrapUInt128(value) }
    #endif
    func encode<T: Encodable>(_ value: T) throws {
        singleValue = try wrapGenericEncodable(value, for: nil) ?? yyjson_mut_obj(doc)
    }
}

// MARK: - YYJSONKeyedEncodingContainer

private struct YYJSONKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K
    let impl: JSONEncoderImpl
    var codingPath: [CodingKey]
    let object: UnsafeMutablePointer<yyjson_mut_val>
    let doc: UnsafeMutablePointer<yyjson_mut_doc>
    let useDefaultKeys: Bool

    init(impl: JSONEncoderImpl, codingPath: [CodingKey], object: UnsafeMutablePointer<yyjson_mut_val>) {
        self.impl = impl
        self.codingPath = codingPath
        self.object = object
        self.doc = impl.doc
        if case .useDefaultKeys = impl.options.keyEncodingStrategy {
            self.useDefaultKeys = true
        } else {
            self.useDefaultKeys = false
        }
    }

    @inline(__always)
    private func _key(_ key: Key) -> String {
        useDefaultKeys ? key.stringValue : impl.convertedKey(key)
    }

    @inline(__always)
    private func _strVal(_ s: String) -> UnsafeMutablePointer<yyjson_mut_val> {
        impl.wrapString(s)
    }

    @inline(__always)
    private func addToObject(key: String, value: UnsafeMutablePointer<yyjson_mut_val>) {
        yyjson_mut_obj_put(object, _strVal(key), value)
    }

    mutating func encodeNil(forKey key: Key) throws { addToObject(key: _key(key), value: yyjson_mut_null(doc)) }
    mutating func encode(_ value: Bool, forKey key: Key) throws { addToObject(key: _key(key), value: yyjson_mut_bool(doc, value)) }
    mutating func encode(_ value: String, forKey key: Key) throws { addToObject(key: _key(key), value: _strVal(value)) }
    mutating func encode(_ value: Double, forKey key: Key) throws { addToObject(key: _key(key), value: try impl.wrapFloat(value, for: key)) }
    mutating func encode(_ value: Float, forKey key: Key) throws { addToObject(key: _key(key), value: try impl.wrapFloat(value, for: key)) }
    mutating func encode(_ value: Int, forKey key: Key) throws { addToObject(key: _key(key), value: yyjson_mut_sint(doc, Int64(value))) }
    mutating func encode(_ value: Int8, forKey key: Key) throws { addToObject(key: _key(key), value: yyjson_mut_sint(doc, Int64(value))) }
    mutating func encode(_ value: Int16, forKey key: Key) throws { addToObject(key: _key(key), value: yyjson_mut_sint(doc, Int64(value))) }
    mutating func encode(_ value: Int32, forKey key: Key) throws { addToObject(key: _key(key), value: yyjson_mut_sint(doc, Int64(value))) }
    mutating func encode(_ value: Int64, forKey key: Key) throws { addToObject(key: _key(key), value: yyjson_mut_sint(doc, Int64(value))) }
    mutating func encode(_ value: UInt, forKey key: Key) throws { addToObject(key: _key(key), value: yyjson_mut_uint(doc, UInt64(value))) }
    mutating func encode(_ value: UInt8, forKey key: Key) throws { addToObject(key: _key(key), value: yyjson_mut_uint(doc, UInt64(value))) }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { addToObject(key: _key(key), value: yyjson_mut_uint(doc, UInt64(value))) }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { addToObject(key: _key(key), value: yyjson_mut_uint(doc, UInt64(value))) }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { addToObject(key: _key(key), value: yyjson_mut_uint(doc, UInt64(value))) }
    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: Int128, forKey key: Key) throws { addToObject(key: _key(key), value: impl.wrapInt128(value)) }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: UInt128, forKey key: Key) throws { addToObject(key: _key(key), value: impl.wrapUInt128(value)) }
    #endif

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        addToObject(key: _key(key), value: try impl.wrapGenericEncodable(value, for: key) ?? yyjson_mut_obj(doc)!)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let k = impl.convertedKey(key)
        if let existing = k.withCString({ yyjson_mut_obj_getn(object, $0, k.utf8.count) }), yyjson_mut_is_obj(existing) {
            return KeyedEncodingContainer(YYJSONKeyedEncodingContainer<NestedKey>(impl: impl, codingPath: codingPath + [key], object: existing))
        }
        let obj = yyjson_mut_obj(doc)!
        addToObject(key: k, value: obj)
        return KeyedEncodingContainer(YYJSONKeyedEncodingContainer<NestedKey>(impl: impl, codingPath: codingPath + [key], object: obj))
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let arr = yyjson_mut_arr(doc)!
        addToObject(key: impl.convertedKey(key), value: arr)
        return YYJSONUnkeyedEncodingContainer(impl: impl, codingPath: codingPath + [key], array: arr)
    }

    mutating func superEncoder() -> Encoder {
        YYJSONReferencingEncoder(impl: impl, key: impl.convertedKey(_CodingKey.super), codingPath: codingPath + [_CodingKey.super], object: object)
    }
    mutating func superEncoder(forKey key: Key) -> Encoder {
        YYJSONReferencingEncoder(impl: impl, key: impl.convertedKey(key), codingPath: codingPath + [key], object: object)
    }
}

// MARK: - YYJSONUnkeyedEncodingContainer

private struct YYJSONUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let impl: JSONEncoderImpl
    var codingPath: [CodingKey]
    let array: UnsafeMutablePointer<yyjson_mut_val>
    var doc: UnsafeMutablePointer<yyjson_mut_doc> { impl.doc }
    var count: Int { Int(yyjson_mut_arr_size(array)) }

    mutating func encodeNil() throws { yyjson_mut_arr_add_null(doc, array) }
    mutating func encode(_ value: Bool) throws { yyjson_mut_arr_add_bool(doc, array, value) }
    mutating func encode(_ value: String) throws { yyjson_mut_arr_append(array, impl.wrapString(value)) }
    mutating func encode(_ value: Double) throws { yyjson_mut_arr_append(array, try impl.wrapFloat(value, for: _CodingKey(index: count))) }
    mutating func encode(_ value: Float) throws { yyjson_mut_arr_append(array, try impl.wrapFloat(value, for: _CodingKey(index: count))) }
    mutating func encode(_ value: Int) throws { yyjson_mut_arr_add_sint(doc, array, Int64(value)) }
    mutating func encode(_ value: Int8) throws { yyjson_mut_arr_add_sint(doc, array, Int64(value)) }
    mutating func encode(_ value: Int16) throws { yyjson_mut_arr_add_sint(doc, array, Int64(value)) }
    mutating func encode(_ value: Int32) throws { yyjson_mut_arr_add_sint(doc, array, Int64(value)) }
    mutating func encode(_ value: Int64) throws { yyjson_mut_arr_add_sint(doc, array, Int64(value)) }
    mutating func encode(_ value: UInt) throws { yyjson_mut_arr_add_uint(doc, array, UInt64(value)) }
    mutating func encode(_ value: UInt8) throws { yyjson_mut_arr_add_uint(doc, array, UInt64(value)) }
    mutating func encode(_ value: UInt16) throws { yyjson_mut_arr_add_uint(doc, array, UInt64(value)) }
    mutating func encode(_ value: UInt32) throws { yyjson_mut_arr_add_uint(doc, array, UInt64(value)) }
    mutating func encode(_ value: UInt64) throws { yyjson_mut_arr_add_uint(doc, array, UInt64(value)) }
    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: Int128) throws { yyjson_mut_arr_append(array, impl.wrapInt128(value)) }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: UInt128) throws { yyjson_mut_arr_append(array, impl.wrapUInt128(value)) }
    #endif

    mutating func encode<T: Encodable>(_ value: T) throws {
        yyjson_mut_arr_append(array, try impl.wrapGenericEncodable(value, for: _CodingKey(index: count)) ?? yyjson_mut_obj(doc)!)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let obj = yyjson_mut_obj(doc)!; yyjson_mut_arr_append(array, obj)
        return KeyedEncodingContainer(YYJSONKeyedEncodingContainer<NestedKey>(impl: impl, codingPath: codingPath + [_CodingKey(index: count - 1)], object: obj))
    }
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let arr = yyjson_mut_arr(doc)!; yyjson_mut_arr_append(array, arr)
        return YYJSONUnkeyedEncodingContainer(impl: impl, codingPath: codingPath + [_CodingKey(index: count - 1)], array: arr)
    }
    mutating func superEncoder() -> Encoder {
        YYJSONReferencingArrayEncoder(impl: impl, codingPath: codingPath + [_CodingKey(index: count)], array: array, index: count)
    }
}

// MARK: - Referencing Encoders

private class YYJSONReferencingEncoder: JSONEncoderImpl {
    let key: String
    let referencedObject: UnsafeMutablePointer<yyjson_mut_val>
    init(impl: JSONEncoderImpl, key: String, codingPath: [CodingKey], object: UnsafeMutablePointer<yyjson_mut_val>) {
        self.key = key; self.referencedObject = object
        super.init(doc: impl.doc, codingPath: codingPath, options: impl.options)
    }
    deinit {
        yyjson_mut_obj_put(referencedObject, wrapString(key), takeValue() ?? yyjson_mut_obj(doc)!)
    }
}

private class YYJSONReferencingArrayEncoder: JSONEncoderImpl {
    let referencedArray: UnsafeMutablePointer<yyjson_mut_val>
    let insertIndex: Int
    init(impl: JSONEncoderImpl, codingPath: [CodingKey], array: UnsafeMutablePointer<yyjson_mut_val>, index: Int) {
        self.referencedArray = array; self.insertIndex = index
        super.init(doc: impl.doc, codingPath: codingPath, options: impl.options)
    }
    deinit {
        yyjson_mut_arr_insert(referencedArray, takeValue() ?? yyjson_mut_obj(doc)!, insertIndex)
    }
}
