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
    
    var userInfo: [CodingUserInfoKey: Any] {
        return options.userInfo
    }
    
    var singleValue: UnsafeMutablePointer<yyjson_mut_val>?
    var array: UnsafeMutablePointer<yyjson_mut_val>?
    var object: UnsafeMutablePointer<yyjson_mut_val>?
    
    init(doc: UnsafeMutablePointer<yyjson_mut_doc>, codingPath: [CodingKey], options: ReerJSONEncoder.Options) {
        self.doc = doc
        self.codingPath = codingPath
        self.options = options
    }
    
    func takeValue() -> UnsafeMutablePointer<yyjson_mut_val>? {
        if let object {
            return object
        }
        if let array {
            return array
        }
        return singleValue
    }
    
    // MARK: - Encoder Methods
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        if let object {
            let container = YYJSONKeyedEncodingContainer<Key>(impl: self, codingPath: codingPath, object: object)
            return KeyedEncodingContainer(container)
        }
        
        if let sv = singleValue, yyjson_mut_is_obj(sv) {
            self.object = sv
            self.singleValue = nil
            let container = YYJSONKeyedEncodingContainer<Key>(impl: self, codingPath: codingPath, object: sv)
            return KeyedEncodingContainer(container)
        }
        
        guard singleValue == nil, array == nil else {
            preconditionFailure("Attempt to push new keyed encoding container when already previously encoded at this path.")
        }
        
        let obj = yyjson_mut_obj(doc)!
        self.object = obj
        let container = YYJSONKeyedEncodingContainer<Key>(impl: self, codingPath: codingPath, object: obj)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        if let array {
            return YYJSONUnkeyedEncodingContainer(impl: self, codingPath: codingPath, array: array)
        }
        
        if let sv = singleValue, yyjson_mut_is_arr(sv) {
            self.array = sv
            self.singleValue = nil
            return YYJSONUnkeyedEncodingContainer(impl: self, codingPath: codingPath, array: sv)
        }
        
        guard singleValue == nil, object == nil else {
            preconditionFailure("Attempt to push new unkeyed encoding container when already previously encoded at this path.")
        }
        
        let arr = yyjson_mut_arr(doc)!
        self.array = arr
        return YYJSONUnkeyedEncodingContainer(impl: self, codingPath: codingPath, array: arr)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
    
    // MARK: - Value Creation Helpers
    
    @inline(__always)
    func wrapInt(_ value: some FixedWidthInteger & SignedInteger) -> UnsafeMutablePointer<yyjson_mut_val> {
        return yyjson_mut_sint(doc, Int64(value))
    }
    
    @inline(__always)
    func wrapUInt(_ value: some FixedWidthInteger & UnsignedInteger) -> UnsafeMutablePointer<yyjson_mut_val> {
        return yyjson_mut_uint(doc, UInt64(value))
    }
    
    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func wrapInt128(_ value: Int128) -> UnsafeMutablePointer<yyjson_mut_val> {
        let str = String(value)
        return yyjson_mut_rawcpy(doc, str)
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func wrapUInt128(_ value: UInt128) -> UnsafeMutablePointer<yyjson_mut_val> {
        let str = String(value)
        return yyjson_mut_rawcpy(doc, str)
    }
    #endif
    
    @inline(__always)
    func wrapDouble(_ value: Double) -> UnsafeMutablePointer<yyjson_mut_val> {
        let str = formatDouble(value)
        return yyjson_mut_rawcpy(doc, str)
    }
    
    private func formatDouble(_ value: Double) -> String {
        var string = value.description
        if string.hasSuffix(".0") {
            string.removeLast(2)
        }
        return string
    }
    
    func wrapFloat<T: BinaryFloatingPoint & CustomStringConvertible>(_ float: T, for additionalKey: CodingKey?) throws -> UnsafeMutablePointer<yyjson_mut_val> {
        guard !float.isNaN, !float.isInfinite else {
            if case .convertToString(let posInfString, let negInfString, let nanString) = options.nonConformingFloatEncodingStrategy {
                switch float {
                case T.infinity:
                    return wrapString(posInfString)
                case -T.infinity:
                    return wrapString(negInfString)
                default:
                    return wrapString(nanString)
                }
            }
            
            var path = codingPath
            if let additionalKey { path.append(additionalKey) }
            throw EncodingError.invalidValue(float, .init(
                codingPath: path,
                debugDescription: "Unable to encode \(T.self).\(float) directly in JSON."
            ))
        }
        
        var string = float.description
        if string.hasSuffix(".0") {
            string.removeLast(2)
        }
        return yyjson_mut_rawcpy(doc, string)
    }
    
    @inline(__always)
    func wrapString(_ string: String) -> UnsafeMutablePointer<yyjson_mut_val> {
        return string.withCString { cStr in
            let len = string.utf8.count
            return yyjson_mut_strncpy(doc, cStr, len)
        }
    }
    
    func wrapEncodable(_ value: Encodable, for additionalKey: CodingKey?) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        if let date = value as? Date {
            return try wrapDateValue(date, for: additionalKey)
        } else if let data = value as? Data {
            return try wrapDataValue(data, for: additionalKey)
        } else if let url = value as? URL {
            return wrapString(url.absoluteString)
        } else if let decimal = value as? Decimal {
            return yyjson_mut_rawcpy(doc, decimal.description)
        } else if value is _JSONStringDictionaryEncodableMarker, let dict = value as? [String: Encodable] {
            return try wrapStringKeyedDictValue(dict, for: additionalKey)
        }
        #if compiler(>=6.0)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            if let i128 = value as? Int128 {
                return wrapInt128(i128)
            }
            if let u128 = value as? UInt128 {
                return wrapUInt128(u128)
            }
        }
        #endif
        
        let newPath = codingPath + (additionalKey.map { [$0] } ?? [])
        let subEncoder = JSONEncoderImpl(doc: doc, codingPath: newPath, options: options)
        try value.encode(to: subEncoder)
        return subEncoder.takeValue()
    }
    
    func wrapDateValue(_ date: Date, for additionalKey: CodingKey?) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        switch options.dateEncodingStrategy {
        case .deferredToDate:
            let newPath = codingPath + (additionalKey.map { [$0] } ?? [])
            let subEncoder = JSONEncoderImpl(doc: doc, codingPath: newPath, options: options)
            try date.encode(to: subEncoder)
            return subEncoder.takeValue()
            
        case .secondsSince1970:
            return try wrapFloat(date.timeIntervalSince1970, for: additionalKey)
            
        case .millisecondsSince1970:
            return try wrapFloat(1000.0 * date.timeIntervalSince1970, for: additionalKey)
            
        case .iso8601:
            let string = _iso8601Formatter.string(from: date)
            return wrapString(string)
            
        case .formatted(let formatter):
            let string = formatter.string(from: date)
            return wrapString(string)
            
        case .custom(let closure):
            let newPath = codingPath + (additionalKey.map { [$0] } ?? [])
            let subEncoder = JSONEncoderImpl(doc: doc, codingPath: newPath, options: options)
            try closure(date, subEncoder)
            return subEncoder.takeValue() ?? yyjson_mut_obj(doc)
            
        @unknown default:
            fatalError()
        }
    }
    
    func wrapDataValue(_ data: Data, for additionalKey: CodingKey?) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        switch options.dataEncodingStrategy {
        case .deferredToData:
            let newPath = codingPath + (additionalKey.map { [$0] } ?? [])
            let subEncoder = JSONEncoderImpl(doc: doc, codingPath: newPath, options: options)
            try data.encode(to: subEncoder)
            return subEncoder.takeValue()
            
        case .base64:
            let base64 = data.base64EncodedString()
            return wrapString(base64)
            
        case .custom(let closure):
            let newPath = codingPath + (additionalKey.map { [$0] } ?? [])
            let subEncoder = JSONEncoderImpl(doc: doc, codingPath: newPath, options: options)
            try closure(data, subEncoder)
            return subEncoder.takeValue() ?? yyjson_mut_obj(doc)
            
        @unknown default:
            fatalError()
        }
    }
    
    func wrapStringKeyedDictValue(_ dict: [String: Encodable], for additionalKey: CodingKey?) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        let obj = yyjson_mut_obj(doc)!
        let savedCodingPath = codingPath
        if let additionalKey {
            codingPath.append(additionalKey)
        }
        for (key, value) in dict {
            let keyVal = wrapString(key)
            let dictKey = _CodingKey(stringValue: key)!
            codingPath.append(dictKey)
            let subEncoder = JSONEncoderImpl(doc: doc, codingPath: codingPath, options: options)
            let val = try subEncoder.wrapEncodable(value, for: nil) ?? yyjson_mut_obj(doc)!
            yyjson_mut_obj_add(obj, keyVal, val)
            codingPath.removeLast()
        }
        codingPath = savedCodingPath
        return obj
    }
    
    // MARK: - Key encoding strategy
    
    func convertedKey(_ key: CodingKey) -> String {
        switch options.keyEncodingStrategy {
        case .useDefaultKeys:
            return key.stringValue
        case .convertToSnakeCase:
            return Self._convertToSnakeCase(key.stringValue)
        case .custom(let converter):
            return converter(codingPath + [key]).stringValue
        @unknown default:
            return key.stringValue
        }
    }
    
    static func _convertToSnakeCase(_ stringKey: String) -> String {
        guard !stringKey.isEmpty else { return stringKey }

        var words: [Range<String.Index>] = []
        var wordStart = stringKey.startIndex
        var searchRange = stringKey.index(after: wordStart)..<stringKey.endIndex

        while let upperCaseRange = stringKey[searchRange].rangeOfCharacter(from: .uppercaseLetters) {
            let untilUpperCase = wordStart..<upperCaseRange.lowerBound
            words.append(untilUpperCase)

            searchRange = upperCaseRange.lowerBound..<searchRange.upperBound
            guard let lowerCaseRange = stringKey[searchRange].rangeOfCharacter(from: .lowercaseLetters) else {
                wordStart = searchRange.lowerBound
                break
            }

            let nextCharacterAfterCapital = stringKey.index(after: upperCaseRange.lowerBound)
            if lowerCaseRange.lowerBound == nextCharacterAfterCapital {
                wordStart = upperCaseRange.lowerBound
            } else {
                let beforeLowerIndex = stringKey.index(before: lowerCaseRange.lowerBound)
                words.append(upperCaseRange.lowerBound..<beforeLowerIndex)
                wordStart = beforeLowerIndex
            }
            searchRange = lowerCaseRange.upperBound..<searchRange.upperBound
        }
        words.append(wordStart..<searchRange.upperBound)
        let result = words.map { range in
            return stringKey[range].lowercased()
        }.joined(separator: "_")
        return result
    }
}

// MARK: - SingleValueEncodingContainer

extension JSONEncoderImpl: SingleValueEncodingContainer {
    func encodeNil() throws {
        singleValue = yyjson_mut_null(doc)
    }
    
    func encode(_ value: Bool) throws {
        singleValue = yyjson_mut_bool(doc, value)
    }
    
    func encode(_ value: String) throws {
        singleValue = wrapString(value)
    }
    
    func encode(_ value: Double) throws {
        singleValue = try wrapFloat(value, for: nil)
    }
    
    func encode(_ value: Float) throws {
        singleValue = try wrapFloat(value, for: nil)
    }
    
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
    func encode(_ value: Int128) throws {
        singleValue = wrapInt128(value)
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func encode(_ value: UInt128) throws {
        singleValue = wrapUInt128(value)
    }
    #endif
    
    func encode<T: Encodable>(_ value: T) throws {
        #if compiler(>=6.0)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            if let i128 = value as? Int128 {
                singleValue = wrapInt128(i128)
                return
            }
            if let u128 = value as? UInt128 {
                singleValue = wrapUInt128(u128)
                return
            }
        }
        #endif
        singleValue = try wrapEncodable(value, for: nil) ?? yyjson_mut_obj(doc)
    }
}

// MARK: - YYJSONKeyedEncodingContainer

private struct YYJSONKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K
    
    let impl: JSONEncoderImpl
    var codingPath: [CodingKey]
    let object: UnsafeMutablePointer<yyjson_mut_val>
    
    var doc: UnsafeMutablePointer<yyjson_mut_doc> { impl.doc }
    
    init(impl: JSONEncoderImpl, codingPath: [CodingKey], object: UnsafeMutablePointer<yyjson_mut_val>) {
        self.impl = impl
        self.codingPath = codingPath
        self.object = object
    }
    
    private func addToObject(key: String, value: UnsafeMutablePointer<yyjson_mut_val>) {
        let keyVal = impl.wrapString(key)
        yyjson_mut_obj_put(object, keyVal, value)
    }
    
    mutating func encodeNil(forKey key: Key) throws {
        addToObject(key: impl.convertedKey(key), value: yyjson_mut_null(doc))
    }
    
    mutating func encode(_ value: Bool, forKey key: Key) throws {
        addToObject(key: impl.convertedKey(key), value: yyjson_mut_bool(doc, value))
    }
    
    mutating func encode(_ value: String, forKey key: Key) throws {
        addToObject(key: impl.convertedKey(key), value: impl.wrapString(value))
    }
    
    mutating func encode(_ value: Double, forKey key: Key) throws {
        addToObject(key: impl.convertedKey(key), value: try impl.wrapFloat(value, for: key))
    }
    
    mutating func encode(_ value: Float, forKey key: Key) throws {
        addToObject(key: impl.convertedKey(key), value: try impl.wrapFloat(value, for: key))
    }
    
    mutating func encode(_ value: Int, forKey key: Key) throws { addToObject(key: impl.convertedKey(key), value: impl.wrapInt(value)) }
    mutating func encode(_ value: Int8, forKey key: Key) throws { addToObject(key: impl.convertedKey(key), value: impl.wrapInt(value)) }
    mutating func encode(_ value: Int16, forKey key: Key) throws { addToObject(key: impl.convertedKey(key), value: impl.wrapInt(value)) }
    mutating func encode(_ value: Int32, forKey key: Key) throws { addToObject(key: impl.convertedKey(key), value: impl.wrapInt(value)) }
    mutating func encode(_ value: Int64, forKey key: Key) throws { addToObject(key: impl.convertedKey(key), value: impl.wrapInt(value)) }
    mutating func encode(_ value: UInt, forKey key: Key) throws { addToObject(key: impl.convertedKey(key), value: impl.wrapUInt(value)) }
    mutating func encode(_ value: UInt8, forKey key: Key) throws { addToObject(key: impl.convertedKey(key), value: impl.wrapUInt(value)) }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { addToObject(key: impl.convertedKey(key), value: impl.wrapUInt(value)) }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { addToObject(key: impl.convertedKey(key), value: impl.wrapUInt(value)) }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { addToObject(key: impl.convertedKey(key), value: impl.wrapUInt(value)) }
    
    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: Int128, forKey key: Key) throws { addToObject(key: impl.convertedKey(key), value: impl.wrapInt128(value)) }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: UInt128, forKey key: Key) throws { addToObject(key: impl.convertedKey(key), value: impl.wrapUInt128(value)) }
    #endif
    
    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        let convertedKeyStr = impl.convertedKey(key)
        let val = try impl.wrapEncodable(value, for: key) ?? yyjson_mut_obj(doc)!
        addToObject(key: convertedKeyStr, value: val)
    }
    
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let convertedKeyStr = impl.convertedKey(key)
        let existingVal = convertedKeyStr.withCString { cStr in
            yyjson_mut_obj_getn(object, cStr, convertedKeyStr.utf8.count)
        }
        if let existingVal, yyjson_mut_is_obj(existingVal) {
            let container = YYJSONKeyedEncodingContainer<NestedKey>(impl: impl, codingPath: codingPath + [key], object: existingVal)
            return KeyedEncodingContainer(container)
        }
        let nestedObj = yyjson_mut_obj(doc)!
        addToObject(key: convertedKeyStr, value: nestedObj)
        let container = YYJSONKeyedEncodingContainer<NestedKey>(impl: impl, codingPath: codingPath + [key], object: nestedObj)
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let convertedKeyStr = impl.convertedKey(key)
        let nestedArr = yyjson_mut_arr(doc)!
        addToObject(key: convertedKeyStr, value: nestedArr)
        return YYJSONUnkeyedEncodingContainer(impl: impl, codingPath: codingPath + [key], array: nestedArr)
    }
    
    mutating func superEncoder() -> Encoder {
        let convertedKeyStr = impl.convertedKey(_CodingKey.super)
        return YYJSONReferencingEncoder(impl: impl, key: convertedKeyStr, codingPath: codingPath + [_CodingKey.super], object: object) as Encoder
    }
    
    mutating func superEncoder(forKey key: Key) -> Encoder {
        let convertedKeyStr = impl.convertedKey(key)
        return YYJSONReferencingEncoder(impl: impl, key: convertedKeyStr, codingPath: codingPath + [key], object: object) as Encoder
    }
}

// MARK: - YYJSONUnkeyedEncodingContainer

private struct YYJSONUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let impl: JSONEncoderImpl
    var codingPath: [CodingKey]
    let array: UnsafeMutablePointer<yyjson_mut_val>
    
    var doc: UnsafeMutablePointer<yyjson_mut_doc> { impl.doc }
    
    var count: Int {
        Int(yyjson_mut_arr_size(array))
    }
    
    init(impl: JSONEncoderImpl, codingPath: [CodingKey], array: UnsafeMutablePointer<yyjson_mut_val>) {
        self.impl = impl
        self.codingPath = codingPath
        self.array = array
    }
    
    mutating func encodeNil() throws {
        yyjson_mut_arr_add_null(doc, array)
    }
    
    mutating func encode(_ value: Bool) throws {
        yyjson_mut_arr_add_bool(doc, array, value)
    }
    
    mutating func encode(_ value: String) throws {
        let val = impl.wrapString(value)
        yyjson_mut_arr_append(array, val)
    }
    
    mutating func encode(_ value: Double) throws {
        let val = try impl.wrapFloat(value, for: _CodingKey(index: count))
        yyjson_mut_arr_append(array, val)
    }
    
    mutating func encode(_ value: Float) throws {
        let val = try impl.wrapFloat(value, for: _CodingKey(index: count))
        yyjson_mut_arr_append(array, val)
    }
    
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
    mutating func encode(_ value: Int128) throws {
        let val = impl.wrapInt128(value)
        yyjson_mut_arr_append(array, val)
    }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: UInt128) throws {
        let val = impl.wrapUInt128(value)
        yyjson_mut_arr_append(array, val)
    }
    #endif
    
    mutating func encode<T: Encodable>(_ value: T) throws {
        let val = try impl.wrapEncodable(value, for: _CodingKey(index: count)) ?? yyjson_mut_obj(doc)!
        yyjson_mut_arr_append(array, val)
    }
    
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let nestedObj = yyjson_mut_obj(doc)!
        yyjson_mut_arr_append(array, nestedObj)
        let container = YYJSONKeyedEncodingContainer<NestedKey>(impl: impl, codingPath: codingPath + [_CodingKey(index: count - 1)], object: nestedObj)
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let nestedArr = yyjson_mut_arr(doc)!
        yyjson_mut_arr_append(array, nestedArr)
        return YYJSONUnkeyedEncodingContainer(impl: impl, codingPath: codingPath + [_CodingKey(index: count - 1)], array: nestedArr)
    }
    
    mutating func superEncoder() -> Encoder {
        let idx = count
        return YYJSONReferencingArrayEncoder(impl: impl, codingPath: codingPath + [_CodingKey(index: idx)], array: array, index: idx)
    }
}

// MARK: - YYJSONReferencingEncoder (for keyed containers)

private class YYJSONReferencingEncoder: JSONEncoderImpl {
    let key: String
    let referencedObject: UnsafeMutablePointer<yyjson_mut_val>
    
    init(impl: JSONEncoderImpl, key: String, codingPath: [CodingKey], object: UnsafeMutablePointer<yyjson_mut_val>) {
        self.key = key
        self.referencedObject = object
        super.init(doc: impl.doc, codingPath: codingPath, options: impl.options)
    }
    
    deinit {
        let value = takeValue() ?? yyjson_mut_obj(doc)!
        let keyVal = wrapString(key)
        yyjson_mut_obj_put(referencedObject, keyVal, value)
    }
}

// MARK: - YYJSONReferencingArrayEncoder (for unkeyed containers)

private class YYJSONReferencingArrayEncoder: JSONEncoderImpl {
    let referencedArray: UnsafeMutablePointer<yyjson_mut_val>
    let insertIndex: Int
    
    init(impl: JSONEncoderImpl, codingPath: [CodingKey], array: UnsafeMutablePointer<yyjson_mut_val>, index: Int) {
        self.referencedArray = array
        self.insertIndex = index
        super.init(doc: impl.doc, codingPath: codingPath, options: impl.options)
    }
    
    deinit {
        let value = takeValue() ?? yyjson_mut_obj(doc)!
        yyjson_mut_arr_insert(referencedArray, value, insertIndex)
    }
}
