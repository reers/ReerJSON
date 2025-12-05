//
// Copyright © 2024 swiftlang.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
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

// MARK: - JSONEncoderImpl

final class JSONEncoderImpl: Encoder {
    
    // MARK: - Properties
    
    let options: ReerJSONEncoder.Options
    let mutDoc: UnsafeMutablePointer<yyjson_mut_doc>
    
    var codingPathNode: CodingPathNode
    var codingPath: [CodingKey] {
        codingPathNode.path
    }
    
    var userInfo: [CodingUserInfoKey: Any] {
        options.userInfo
    }
    
    /// Storage for encoded values
    private var singleValue: UnsafeMutablePointer<yyjson_mut_val>?
    private var array: JSONFutureArray?
    private var object: JSONFutureObject?
    
    // For encoder reuse optimization
    var ownerEncoder: JSONEncoderImpl?
    var sharedSubEncoder: JSONEncoderImpl?
    var codingKey: (any CodingKey)?
    
    // MARK: - Initialization
    
    init(
        options: ReerJSONEncoder.Options,
        mutDoc: UnsafeMutablePointer<yyjson_mut_doc>,
        codingPathNode: CodingPathNode = .root
    ) {
        self.options = options
        self.mutDoc = mutDoc
        self.codingPathNode = codingPathNode
    }
    
    // MARK: - Value Management
    
    func takeValue() -> UnsafeMutablePointer<yyjson_mut_val>? {
        if let object = self.object {
            self.object = nil
            return object.toYYJSONValue(doc: mutDoc, encoder: self)
        }
        if let array = self.array {
            self.array = nil
            return array.toYYJSONValue(doc: mutDoc, encoder: self)
        }
        defer { self.singleValue = nil }
        return self.singleValue
    }
    
    // MARK: - Encoder Protocol
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        if let existingObject = self.object {
            let container = JSONKeyedEncodingContainer<Key>(
                encoder: self,
                codingPathNode: codingPathNode,
                object: existingObject
            )
            return KeyedEncodingContainer(container)
        }
        
        if let singleValue = self.singleValue, let converted = JSONFutureObject(from: singleValue, doc: mutDoc) {
            self.singleValue = nil
            self.object = converted
            let container = JSONKeyedEncodingContainer<Key>(
                encoder: self,
                codingPathNode: codingPathNode,
                object: converted
            )
            return KeyedEncodingContainer(container)
        }
        
        precondition(
            self.singleValue == nil && self.array == nil,
            "Attempt to push new keyed encoding container when already previously encoded at this path."
        )
        
        let newObject = JSONFutureObject()
        self.object = newObject
        let container = JSONKeyedEncodingContainer<Key>(
            encoder: self,
            codingPathNode: codingPathNode,
            object: newObject
        )
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        if let existingArray = self.array {
            return JSONUnkeyedEncodingContainer(
                encoder: self,
                codingPathNode: codingPathNode,
                array: existingArray
            )
        }
        
        if let singleValue = self.singleValue, let converted = JSONFutureArray(from: singleValue, doc: mutDoc) {
            self.singleValue = nil
            self.array = converted
            return JSONUnkeyedEncodingContainer(
                encoder: self,
                codingPathNode: codingPathNode,
                array: converted
            )
        }
        
        precondition(
            self.singleValue == nil && self.object == nil,
            "Attempt to push new unkeyed encoding container when already previously encoded at this path."
        )
        
        let newArray = JSONFutureArray()
        self.array = newArray
        return JSONUnkeyedEncodingContainer(
            encoder: self,
            codingPathNode: codingPathNode,
            array: newArray
        )
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
    
    // MARK: - Encoder Reuse
    
    @inline(__always)
    func getEncoder(for additionalKey: (some CodingKey)?, basePathNode: CodingPathNode? = nil) -> JSONEncoderImpl {
        let basePath = basePathNode ?? self.codingPathNode
        if let additionalKey {
            if let takenEncoder = sharedSubEncoder {
                self.sharedSubEncoder = nil
                takenEncoder.codingKey = additionalKey
                takenEncoder.ownerEncoder = self
                takenEncoder.codingPathNode = basePath.appending(additionalKey)
                takenEncoder.singleValue = nil
                takenEncoder.array = nil
                takenEncoder.object = nil
                return takenEncoder
            }
            let encoder = JSONEncoderImpl(
                options: self.options,
                mutDoc: self.mutDoc,
                codingPathNode: basePath.appending(additionalKey)
            )
            encoder.ownerEncoder = self
            encoder.codingKey = additionalKey
            return encoder
        }
        return self
    }
    
    @inline(__always)
    func returnEncoder(_ encoder: inout JSONEncoderImpl) {
        if encoder !== self, sharedSubEncoder == nil, isKnownUniquelyReferenced(&encoder) {
            encoder.codingKey = nil
            encoder.ownerEncoder = nil
            sharedSubEncoder = encoder
        }
    }
    
    // MARK: - Key Transformation
    
    func convertedKey(_ key: some CodingKey) -> String {
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
        
        while let upperCaseRange = stringKey.rangeOfCharacter(
            from: CharacterSet.uppercaseLetters,
            range: searchRange
        ) {
            let untilUpperCase = wordStart..<upperCaseRange.lowerBound
            words.append(untilUpperCase)
            
            searchRange = upperCaseRange.lowerBound..<searchRange.upperBound
            guard let lowerCaseRange = stringKey.rangeOfCharacter(
                from: CharacterSet.lowercaseLetters,
                range: searchRange
            ) else {
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
        let result = words.map { stringKey[$0].lowercased() }.joined(separator: "_")
        return result
    }
}

// MARK: - SingleValueEncodingContainer

extension JSONEncoderImpl: SingleValueEncodingContainer {
    
    @inline(__always)
    private func assertCanEncodeNewValue() {
        precondition(
            self.singleValue == nil && self.array == nil && self.object == nil,
            "Attempt to encode value through single value container when previously value already encoded."
        )
    }
    
    func encodeNil() throws {
        assertCanEncodeNewValue()
        singleValue = yyjson_mut_null(mutDoc)
    }
    
    func encode(_ value: Bool) throws {
        assertCanEncodeNewValue()
        singleValue = yyjson_mut_bool(mutDoc, value)
    }
    
    func encode(_ value: String) throws {
        assertCanEncodeNewValue()
        singleValue = boxString(value)
    }
    
    func encode(_ value: Double) throws {
        assertCanEncodeNewValue()
        singleValue = try boxFloat(value)
    }
    
    func encode(_ value: Float) throws {
        assertCanEncodeNewValue()
        singleValue = try boxFloat(value)
    }
    
    func encode(_ value: Int) throws {
        assertCanEncodeNewValue()
        singleValue = yyjson_mut_sint(mutDoc, Int64(value))
    }
    
    func encode(_ value: Int8) throws {
        assertCanEncodeNewValue()
        singleValue = yyjson_mut_sint(mutDoc, Int64(value))
    }
    
    func encode(_ value: Int16) throws {
        assertCanEncodeNewValue()
        singleValue = yyjson_mut_sint(mutDoc, Int64(value))
    }
    
    func encode(_ value: Int32) throws {
        assertCanEncodeNewValue()
        singleValue = yyjson_mut_sint(mutDoc, Int64(value))
    }
    
    func encode(_ value: Int64) throws {
        assertCanEncodeNewValue()
        singleValue = yyjson_mut_sint(mutDoc, value)
    }
    
    func encode(_ value: UInt) throws {
        assertCanEncodeNewValue()
        singleValue = yyjson_mut_uint(mutDoc, UInt64(value))
    }
    
    func encode(_ value: UInt8) throws {
        assertCanEncodeNewValue()
        singleValue = yyjson_mut_uint(mutDoc, UInt64(value))
    }
    
    func encode(_ value: UInt16) throws {
        assertCanEncodeNewValue()
        singleValue = yyjson_mut_uint(mutDoc, UInt64(value))
    }
    
    func encode(_ value: UInt32) throws {
        assertCanEncodeNewValue()
        singleValue = yyjson_mut_uint(mutDoc, UInt64(value))
    }
    
    func encode(_ value: UInt64) throws {
        assertCanEncodeNewValue()
        singleValue = yyjson_mut_uint(mutDoc, value)
    }
    
    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func encode(_ value: Int128) throws {
        assertCanEncodeNewValue()
        singleValue = boxInt128(value)
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func encode(_ value: UInt128) throws {
        assertCanEncodeNewValue()
        singleValue = boxUInt128(value)
    }
    #endif
    
    func encode<T: Encodable>(_ value: T) throws {
        assertCanEncodeNewValue()
        singleValue = try box(value)
    }
}

// MARK: - Boxing Methods

extension JSONEncoderImpl {
    
    @inline(__always)
    func boxString(_ value: String) -> UnsafeMutablePointer<yyjson_mut_val>? {
        // Use withCString for better performance when no null bytes present
        // Use UTF8 view length to handle embedded null bytes correctly
        let utf8 = value.utf8
        let length = utf8.count
        return utf8.withContiguousStorageIfAvailable { buffer in
            yyjson_mut_strncpy(mutDoc, buffer.baseAddress, length)
        } ?? value.withCString { cStr in
            yyjson_mut_strncpy(mutDoc, cStr, length)
        }
    }
    
    @inline(__always)
    func boxFloat<T: BinaryFloatingPoint>(_ value: T, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        guard !value.isNaN, !value.isInfinite else {
            if case .convertToString(let posInf, let negInf, let nan) = options.nonConformingFloatEncodingStrategy {
                if value.isNaN {
                    return boxString(nan)
                } else if value == T.infinity {
                    return boxString(posInf)
                } else {
                    return boxString(negInf)
                }
            }
            let path = codingPath + (additionalKey.map { [$0] } ?? [])
            throw EncodingError.invalidValue(value, .init(
                codingPath: path,
                debugDescription: "Unable to encode \(T.self).\(value) directly in JSON."
            ))
        }
        return yyjson_mut_real(mutDoc, Double(value))
    }
    
    func box(_ value: Encodable, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        return try boxGeneric(value, for: additionalKey)
    }
    
    func boxGeneric<T: Encodable>(_ value: T, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        // Handle special types
        if let date = value as? Date {
            return try boxDate(date, for: additionalKey)
        }
        if let data = value as? Data {
            return try boxData(data, for: additionalKey)
        }
        if let url = value as? URL {
            return boxString(url.absoluteString)
        }
        if let decimal = value as? Decimal {
            return boxDecimal(decimal)
        }
        
        // Handle String-keyed dictionaries - DO NOT apply key conversion to dictionary keys
        if value is StringEncodableDictionary {
            return try boxStringKeyedDictionary(value, for: additionalKey)
        }
        
        // Try optimized array encoding for primitive types
        if let array = value as? EncodableArray {
            if let optimized = try boxOptimizedArray(array, for: additionalKey) {
                return optimized
            }
        }
        
        // Generic encoding via child encoder
        var encoder = getEncoder(for: additionalKey)
        defer { returnEncoder(&encoder) }
        try value.encode(to: encoder)
        // If nothing was encoded, return nil for top-level or empty object for nested
        if let result = encoder.takeValue() {
            return result
        }
        // For non-top-level encoding (not at root), return empty object
        // Top-level (root) will get nil and handle it appropriately
        // Check if the encoder's path is not empty (i.e., we're nested)
        if !encoder.codingPath.isEmpty {
            return yyjson_mut_obj(mutDoc)
        }
        return nil
    }
    
    /// Box a String-keyed dictionary without applying key conversion
    /// Dictionary keys should NOT be transformed by keyEncodingStrategy
    func boxStringKeyedDictionary<T: Encodable>(_ value: T, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        let obj = yyjson_mut_obj(mutDoc)
        
        // Use Mirror to iterate over dictionary entries
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .dictionary else {
            return nil
        }
        
        // Collect keys for potential sorting
        var entries: [(key: String, value: Any)] = []
        for child in mirror.children {
            guard let pair = child.value as? (key: Any, value: Any),
                  let key = pair.key as? String else {
                continue
            }
            entries.append((key: key, value: pair.value))
        }
        
        // Sort keys if needed - use simple string comparison (< operator)
        // This matches Apple's JSONEncoder behavior
        if options.outputFormatting.contains(.sortedKeys) {
            entries.sort { $0.key < $1.key }
        }
        
        // Encode entries - use original key WITHOUT conversion
        for entry in entries {
            let keyVal = boxString(entry.key)
            
            if let encodableValue = entry.value as? Encodable {
                let key = _CodingKey(stringValue: entry.key)!
                // Create sub-encoder with key already in path
                var subEncoder = getEncoder(for: key)
                defer { returnEncoder(&subEncoder) }
                // Don't pass key again - it's already in subEncoder's path
                let encodedValue = try subEncoder.box(encodableValue)
                yyjson_mut_obj_add(obj, keyVal, encodedValue)
            }
        }
        
        return obj
    }
    
    func boxDate(_ date: Date, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        switch options.dateEncodingStrategy {
        case .deferredToDate:
            var encoder = getEncoder(for: additionalKey)
            defer { returnEncoder(&encoder) }
            try date.encode(to: encoder)
            return encoder.takeValue()
            
        case .secondsSince1970:
            let seconds = date.timeIntervalSince1970
            // If the value is a whole number, encode as integer
            if seconds.truncatingRemainder(dividingBy: 1) == 0 && 
               seconds >= Double(Int64.min) && seconds <= Double(Int64.max) {
                return yyjson_mut_sint(mutDoc, Int64(seconds))
            }
            return try boxFloat(seconds, for: additionalKey)
            
        case .millisecondsSince1970:
            let ms = date.timeIntervalSince1970 * 1000.0
            // If the value is a whole number, encode as integer
            if ms.truncatingRemainder(dividingBy: 1) == 0 &&
               ms >= Double(Int64.min) && ms <= Double(Int64.max) {
                return yyjson_mut_sint(mutDoc, Int64(ms))
            }
            return try boxFloat(ms, for: additionalKey)
            
        case .iso8601:
            return boxString(_iso8601Formatter.string(from: date))
            
        case .formatted(let formatter):
            return boxString(formatter.string(from: date))
            
        case .custom(let closure):
            var encoder = getEncoder(for: additionalKey)
            defer { returnEncoder(&encoder) }
            try closure(date, encoder)
            return encoder.takeValue() ?? yyjson_mut_obj(mutDoc)
            
        @unknown default:
            fatalError("Unknown date encoding strategy")
        }
    }
    
    func boxData(_ data: Data, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        switch options.dataEncodingStrategy {
        case .deferredToData:
            var encoder = getEncoder(for: additionalKey)
            defer { returnEncoder(&encoder) }
            try data.encode(to: encoder)
            return encoder.takeValue()
            
        case .base64:
            return boxString(data.base64EncodedString())
            
        case .custom(let closure):
            var encoder = getEncoder(for: additionalKey)
            defer { returnEncoder(&encoder) }
            try closure(data, encoder)
            return encoder.takeValue() ?? yyjson_mut_obj(mutDoc)
            
        @unknown default:
            fatalError("Unknown data encoding strategy")
        }
    }
    
    func boxDecimal(_ decimal: Decimal) -> UnsafeMutablePointer<yyjson_mut_val>? {
        // Output Decimal as raw number to preserve precision
        let description = decimal.description
        return description.withCString { cStr in
            yyjson_mut_rawcpy(mutDoc, cStr)
        }
    }
    
    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func boxInt128(_ value: Int128) -> UnsafeMutablePointer<yyjson_mut_val>? {
        // Output Int128 as raw number to preserve the full value
        let description = String(value)
        return description.withCString { cStr in
            yyjson_mut_rawcpy(mutDoc, cStr)
        }
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func boxUInt128(_ value: UInt128) -> UnsafeMutablePointer<yyjson_mut_val>? {
        // Output UInt128 as raw number to preserve the full value
        let description = String(value)
        return description.withCString { cStr in
            yyjson_mut_rawcpy(mutDoc, cStr)
        }
    }
    #endif
    
    func boxOptimizedArray(_ array: EncodableArray, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        let arr = yyjson_mut_arr(mutDoc)
        
        if let a = array as? [Bool] {
            for v in a { yyjson_mut_arr_append(arr, yyjson_mut_bool(mutDoc, v)) }
            return arr
        }
        if let a = array as? [String] {
            for v in a { yyjson_mut_arr_append(arr, boxString(v)) }
            return arr
        }
        if let a = array as? [Double] {
            for v in a { yyjson_mut_arr_append(arr, try boxFloat(v, for: additionalKey)) }
            return arr
        }
        if let a = array as? [Float] {
            for v in a { yyjson_mut_arr_append(arr, try boxFloat(v, for: additionalKey)) }
            return arr
        }
        if let a = array as? [Int] {
            for v in a { yyjson_mut_arr_append(arr, yyjson_mut_sint(mutDoc, Int64(v))) }
            return arr
        }
        if let a = array as? [Int8] {
            for v in a { yyjson_mut_arr_append(arr, yyjson_mut_sint(mutDoc, Int64(v))) }
            return arr
        }
        if let a = array as? [Int16] {
            for v in a { yyjson_mut_arr_append(arr, yyjson_mut_sint(mutDoc, Int64(v))) }
            return arr
        }
        if let a = array as? [Int32] {
            for v in a { yyjson_mut_arr_append(arr, yyjson_mut_sint(mutDoc, Int64(v))) }
            return arr
        }
        if let a = array as? [Int64] {
            for v in a { yyjson_mut_arr_append(arr, yyjson_mut_sint(mutDoc, v)) }
            return arr
        }
        if let a = array as? [UInt] {
            for v in a { yyjson_mut_arr_append(arr, yyjson_mut_uint(mutDoc, UInt64(v))) }
            return arr
        }
        if let a = array as? [UInt8] {
            for v in a { yyjson_mut_arr_append(arr, yyjson_mut_uint(mutDoc, UInt64(v))) }
            return arr
        }
        if let a = array as? [UInt16] {
            for v in a { yyjson_mut_arr_append(arr, yyjson_mut_uint(mutDoc, UInt64(v))) }
            return arr
        }
        if let a = array as? [UInt32] {
            for v in a { yyjson_mut_arr_append(arr, yyjson_mut_uint(mutDoc, UInt64(v))) }
            return arr
        }
        if let a = array as? [UInt64] {
            for v in a { yyjson_mut_arr_append(arr, yyjson_mut_uint(mutDoc, v)) }
            return arr
        }
        
        #if compiler(>=6.0)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *), let a = array as? [Int128] {
            for v in a { yyjson_mut_arr_append(arr, boxInt128(v)) }
            return arr
        }
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *), let a = array as? [UInt128] {
            for v in a { yyjson_mut_arr_append(arr, boxUInt128(v)) }
            return arr
        }
        #endif
        
        return nil
    }
}

// MARK: - Future Types for Deferred Resolution

/// Represents a JSON object with potentially unresolved nested values
final class JSONFutureObject {
    var dict: [String: JSONFuture] = [:]
    
    init() {
        dict.reserveCapacity(8)
    }
    
    init?(from val: UnsafeMutablePointer<yyjson_mut_val>?, doc: UnsafeMutablePointer<yyjson_mut_doc>) {
        guard let val = val, yyjson_mut_is_obj(val) else { return nil }
        
        // Convert existing yyjson object to JSONFutureObject
        dict.reserveCapacity(8)
        var iter = yyjson_mut_obj_iter()
        yyjson_mut_obj_iter_init(val, &iter)
        while let key = yyjson_mut_obj_iter_next(&iter) {
            if let keyStr = yyjson_mut_get_str(key) {
                let value = yyjson_mut_obj_iter_get_val(key)
                dict[String(cString: keyStr)] = .value(value)
            }
        }
    }
    
    /// Creates a JSONFutureObject from an existing yyjson_mut_val object
    /// This is used when we need to convert an already-encoded object back to a mutable form
    static func from(_ val: UnsafeMutablePointer<yyjson_mut_val>, doc: UnsafeMutablePointer<yyjson_mut_doc>) -> JSONFutureObject {
        let futureObj = JSONFutureObject()
        
        // Iterate through the existing object and copy key-value pairs
        var iter = yyjson_mut_obj_iter()
        yyjson_mut_obj_iter_init(val, &iter)
        while let key = yyjson_mut_obj_iter_next(&iter) {
            if let keyStr = yyjson_mut_get_str(key) {
                let value = yyjson_mut_obj_iter_get_val(key)
                futureObj.dict[String(cString: keyStr)] = .value(value)
            }
        }
        
        return futureObj
    }
    
    @inline(__always)
    func set(_ value: UnsafeMutablePointer<yyjson_mut_val>?, for key: String) {
        dict[key] = .value(value)
    }
    
    @inline(__always)
    func setArray(for key: String) -> JSONFutureArray {
        if case .nestedArray(let arr) = dict[key] {
            return arr
        }
        let arr = JSONFutureArray()
        dict[key] = .nestedArray(arr)
        return arr
    }
    
    @inline(__always)
    func setObject(for key: String) -> JSONFutureObject {
        if case .nestedObject(let obj) = dict[key] {
            return obj
        }
        let obj = JSONFutureObject()
        dict[key] = .nestedObject(obj)
        return obj
    }
    
    func toYYJSONValue(doc: UnsafeMutablePointer<yyjson_mut_doc>, encoder: JSONEncoderImpl) -> UnsafeMutablePointer<yyjson_mut_val>? {
        let obj = yyjson_mut_obj(doc)
        
        // Get keys, sort if needed
        var keys = Array(dict.keys)
        if encoder.options.outputFormatting.contains(.sortedKeys) {
            keys.sort(by: Self.sortedKeyComparator)
        }
        
        for key in keys {
            guard let future = dict[key] else { continue }
            let keyVal = encoder.boxString(key)
            let val = future.toYYJSONValue(doc: doc, encoder: encoder)
            yyjson_mut_obj_add(obj, keyVal, val)
        }
        return obj
    }
    
    /// Comparator for sorted keys - simple string comparison (< operator)
    /// This matches Apple's JSONEncoder behavior
    static let sortedKeyComparator: (String, String) -> Bool = { lhs, rhs in
        lhs < rhs
    }
}

/// Represents a JSON array with potentially unresolved nested values
final class JSONFutureArray {
    var array: [JSONFuture] = []
    
    init() {
        array.reserveCapacity(8)
    }
    
    init?(from val: UnsafeMutablePointer<yyjson_mut_val>?, doc: UnsafeMutablePointer<yyjson_mut_doc>) {
        guard let val = val, yyjson_mut_is_arr(val) else { return nil }
        
        // Convert existing yyjson array to JSONFutureArray
        array.reserveCapacity(8)
        var iter = yyjson_mut_arr_iter()
        yyjson_mut_arr_iter_init(val, &iter)
        while let element = yyjson_mut_arr_iter_next(&iter) {
            array.append(.value(element))
        }
    }
    
    @inline(__always)
    func append(_ value: UnsafeMutablePointer<yyjson_mut_val>?) {
        array.append(.value(value))
    }
    
    @inline(__always)
    func appendArray() -> JSONFutureArray {
        let arr = JSONFutureArray()
        array.append(.nestedArray(arr))
        return arr
    }
    
    @inline(__always)
    func appendObject() -> JSONFutureObject {
        let obj = JSONFutureObject()
        array.append(.nestedObject(obj))
        return obj
    }
    
    @inline(__always)
    func insert(_ value: UnsafeMutablePointer<yyjson_mut_val>?, at index: Int) {
        array.insert(.value(value), at: index)
    }
    
    var count: Int { array.count }
    
    func toYYJSONValue(doc: UnsafeMutablePointer<yyjson_mut_doc>, encoder: JSONEncoderImpl) -> UnsafeMutablePointer<yyjson_mut_val>? {
        let arr = yyjson_mut_arr(doc)
        for future in array {
            let val = future.toYYJSONValue(doc: doc, encoder: encoder)
            yyjson_mut_arr_append(arr, val)
        }
        return arr
    }
}

/// Represents either a resolved value or a nested container
enum JSONFuture {
    case value(UnsafeMutablePointer<yyjson_mut_val>?)
    case nestedArray(JSONFutureArray)
    case nestedObject(JSONFutureObject)
    
    func toYYJSONValue(doc: UnsafeMutablePointer<yyjson_mut_doc>, encoder: JSONEncoderImpl) -> UnsafeMutablePointer<yyjson_mut_val>? {
        switch self {
        case .value(let val):
            return val
        case .nestedArray(let arr):
            return arr.toYYJSONValue(doc: doc, encoder: encoder)
        case .nestedObject(let obj):
            return obj.toYYJSONValue(doc: doc, encoder: encoder)
        }
    }
    
    var array: JSONFutureArray? {
        if case .nestedArray(let arr) = self { return arr }
        return nil
    }
    
    var object: JSONFutureObject? {
        if case .nestedObject(let obj) = self { return obj }
        return nil
    }
}

// MARK: - KeyedEncodingContainer

private struct JSONKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K
    
    let encoder: JSONEncoderImpl
    let codingPathNode: CodingPathNode
    let object: JSONFutureObject
    
    var codingPath: [CodingKey] {
        codingPathNode.path
    }
    
    init(encoder: JSONEncoderImpl, codingPathNode: CodingPathNode, object: JSONFutureObject) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.object = object
    }
    
    @inline(__always)
    private func converted(_ key: some CodingKey) -> String {
        // Use container's codingPath, not encoder's codingPath
        switch encoder.options.keyEncodingStrategy {
        case .useDefaultKeys:
            return key.stringValue
        case .convertToSnakeCase:
            return JSONEncoderImpl._convertToSnakeCase(key.stringValue)
        case .custom(let converter):
            // Append the key to the container's path (which is the full path up to this container)
            return converter(codingPath + [key]).stringValue
        @unknown default:
            return key.stringValue
        }
    }
    
    mutating func encodeNil(forKey key: K) throws {
        object.set(yyjson_mut_null(encoder.mutDoc), for: converted(key))
    }
    
    mutating func encode(_ value: Bool, forKey key: K) throws {
        object.set(yyjson_mut_bool(encoder.mutDoc, value), for: converted(key))
    }
    
    mutating func encode(_ value: String, forKey key: K) throws {
        object.set(encoder.boxString(value), for: converted(key))
    }
    
    mutating func encode(_ value: Double, forKey key: K) throws {
        object.set(try encoder.boxFloat(value, for: key), for: converted(key))
    }
    
    mutating func encode(_ value: Float, forKey key: K) throws {
        object.set(try encoder.boxFloat(value, for: key), for: converted(key))
    }
    
    mutating func encode(_ value: Int, forKey key: K) throws {
        object.set(yyjson_mut_sint(encoder.mutDoc, Int64(value)), for: converted(key))
    }
    
    mutating func encode(_ value: Int8, forKey key: K) throws {
        object.set(yyjson_mut_sint(encoder.mutDoc, Int64(value)), for: converted(key))
    }
    
    mutating func encode(_ value: Int16, forKey key: K) throws {
        object.set(yyjson_mut_sint(encoder.mutDoc, Int64(value)), for: converted(key))
    }
    
    mutating func encode(_ value: Int32, forKey key: K) throws {
        object.set(yyjson_mut_sint(encoder.mutDoc, Int64(value)), for: converted(key))
    }
    
    mutating func encode(_ value: Int64, forKey key: K) throws {
        object.set(yyjson_mut_sint(encoder.mutDoc, value), for: converted(key))
    }
    
    mutating func encode(_ value: UInt, forKey key: K) throws {
        object.set(yyjson_mut_uint(encoder.mutDoc, UInt64(value)), for: converted(key))
    }
    
    mutating func encode(_ value: UInt8, forKey key: K) throws {
        object.set(yyjson_mut_uint(encoder.mutDoc, UInt64(value)), for: converted(key))
    }
    
    mutating func encode(_ value: UInt16, forKey key: K) throws {
        object.set(yyjson_mut_uint(encoder.mutDoc, UInt64(value)), for: converted(key))
    }
    
    mutating func encode(_ value: UInt32, forKey key: K) throws {
        object.set(yyjson_mut_uint(encoder.mutDoc, UInt64(value)), for: converted(key))
    }
    
    mutating func encode(_ value: UInt64, forKey key: K) throws {
        object.set(yyjson_mut_uint(encoder.mutDoc, value), for: converted(key))
    }
    
    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: Int128, forKey key: K) throws {
        // Encode as raw number (not string) to match Apple's JSONEncoder behavior
        object.set(encoder.boxInt128(value), for: converted(key))
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: UInt128, forKey key: K) throws {
        // Encode as raw number (not string) to match Apple's JSONEncoder behavior
        object.set(encoder.boxUInt128(value), for: converted(key))
    }
    #endif
    
    mutating func encode<T: Encodable>(_ value: T, forKey key: K) throws {
        // Create sub-encoder with path based on container's codingPath, not encoder's
        // The key is already added to subEncoder's codingPathNode, so don't pass it to box() again
        var subEncoder = encoder.getEncoder(for: key, basePathNode: codingPathNode)
        defer { encoder.returnEncoder(&subEncoder) }
        let encoded = try subEncoder.box(value)
        object.set(encoded, for: converted(key))
    }
    
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> {
        let convertedKey = converted(key)
        let nestedObject: JSONFutureObject
        
        if let existing = object.dict[convertedKey] {
            if let obj = existing.object {
                nestedObject = obj
            } else if case .value(let val) = existing, let val = val, yyjson_mut_is_obj(val) {
                // Convert existing yyjson object value to JSONFutureObject for further encoding
                let converted = JSONFutureObject.from(val, doc: encoder.mutDoc)
                object.dict[convertedKey] = .nestedObject(converted)
                nestedObject = converted
            } else {
                preconditionFailure(
                    "Attempt to re-encode into nested KeyedEncodingContainer<\(Key.self)> for key \"\(convertedKey)\" is invalid: non-keyed container already encoded for this key"
                )
            }
        } else {
            nestedObject = object.setObject(for: convertedKey)
        }
        
        let container = JSONKeyedEncodingContainer<NestedKey>(
            encoder: encoder,
            codingPathNode: codingPathNode.appending(key),
            object: nestedObject
        )
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        let convertedKey = converted(key)
        let nestedArray: JSONFutureArray
        
        if let existing = object.dict[convertedKey] {
            if let arr = existing.array {
                nestedArray = arr
            } else {
                preconditionFailure(
                    "Attempt to re-encode into nested UnkeyedEncodingContainer for key \"\(convertedKey)\" is invalid: keyed container/single value already encoded for this key"
                )
            }
        } else {
            nestedArray = object.setArray(for: convertedKey)
        }
        
        return JSONUnkeyedEncodingContainer(
            encoder: encoder,
            codingPathNode: codingPathNode.appending(key),
            array: nestedArray
        )
    }
    
    mutating func superEncoder() -> Encoder {
        return JSONReferencingEncoder(
            encoder: encoder,
            key: _CodingKey.super,
            convertedKey: converted(_CodingKey.super),
            object: object
        )
    }
    
    mutating func superEncoder(forKey key: K) -> Encoder {
        return JSONReferencingEncoder(
            encoder: encoder,
            key: key,
            convertedKey: converted(key),
            object: object
        )
    }
}

// MARK: - UnkeyedEncodingContainer

private struct JSONUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let encoder: JSONEncoderImpl
    let codingPathNode: CodingPathNode
    let array: JSONFutureArray
    
    var codingPath: [CodingKey] {
        codingPathNode.path
    }
    
    var count: Int {
        array.count
    }
    
    init(encoder: JSONEncoderImpl, codingPathNode: CodingPathNode, array: JSONFutureArray) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.array = array
    }
    
    mutating func encodeNil() throws {
        array.append(yyjson_mut_null(encoder.mutDoc))
    }
    
    mutating func encode(_ value: Bool) throws {
        array.append(yyjson_mut_bool(encoder.mutDoc, value))
    }
    
    mutating func encode(_ value: String) throws {
        array.append(encoder.boxString(value))
    }
    
    mutating func encode(_ value: Double) throws {
        array.append(try encoder.boxFloat(value, for: _CodingKey(index: count)))
    }
    
    mutating func encode(_ value: Float) throws {
        array.append(try encoder.boxFloat(value, for: _CodingKey(index: count)))
    }
    
    mutating func encode(_ value: Int) throws {
        array.append(yyjson_mut_sint(encoder.mutDoc, Int64(value)))
    }
    
    mutating func encode(_ value: Int8) throws {
        array.append(yyjson_mut_sint(encoder.mutDoc, Int64(value)))
    }
    
    mutating func encode(_ value: Int16) throws {
        array.append(yyjson_mut_sint(encoder.mutDoc, Int64(value)))
    }
    
    mutating func encode(_ value: Int32) throws {
        array.append(yyjson_mut_sint(encoder.mutDoc, Int64(value)))
    }
    
    mutating func encode(_ value: Int64) throws {
        array.append(yyjson_mut_sint(encoder.mutDoc, value))
    }
    
    mutating func encode(_ value: UInt) throws {
        array.append(yyjson_mut_uint(encoder.mutDoc, UInt64(value)))
    }
    
    mutating func encode(_ value: UInt8) throws {
        array.append(yyjson_mut_uint(encoder.mutDoc, UInt64(value)))
    }
    
    mutating func encode(_ value: UInt16) throws {
        array.append(yyjson_mut_uint(encoder.mutDoc, UInt64(value)))
    }
    
    mutating func encode(_ value: UInt32) throws {
        array.append(yyjson_mut_uint(encoder.mutDoc, UInt64(value)))
    }
    
    mutating func encode(_ value: UInt64) throws {
        array.append(yyjson_mut_uint(encoder.mutDoc, value))
    }
    
    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: Int128) throws {
        array.append(encoder.boxInt128(value))
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: UInt128) throws {
        array.append(encoder.boxUInt128(value))
    }
    #endif
    
    mutating func encode<T: Encodable>(_ value: T) throws {
        let key = _CodingKey(index: count)
        // Pass basePathNode to use container's path
        var subEncoder = encoder.getEncoder(for: key, basePathNode: codingPathNode)
        defer { encoder.returnEncoder(&subEncoder) }
        // Don't pass key again - it's already in subEncoder's path
        let encoded = try subEncoder.box(value)
        array.append(encoded)
    }
    
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let nestedObject = array.appendObject()
        let container = JSONKeyedEncodingContainer<NestedKey>(
            encoder: encoder,
            codingPathNode: codingPathNode.appending(index: count - 1),
            object: nestedObject
        )
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let nestedArray = array.appendArray()
        return JSONUnkeyedEncodingContainer(
            encoder: encoder,
            codingPathNode: codingPathNode.appending(index: count - 1),
            array: nestedArray
        )
    }
    
    mutating func superEncoder() -> Encoder {
        return JSONReferencingEncoder(
            encoder: encoder,
            index: count,
            array: array
        )
    }
}

// MARK: - JSONReferencingEncoder

/// A special encoder for encoding super values that writes back to the parent container on deinit
private class JSONReferencingEncoder: Encoder {
    
    enum Reference {
        case array(JSONFutureArray, Int)
        case object(JSONFutureObject, String)
    }
    
    let encoder: JSONEncoderImpl
    let reference: Reference
    
    var codingPath: [CodingKey] {
        encoder.codingPath + [codingKey]
    }
    
    var userInfo: [CodingUserInfoKey: Any] {
        encoder.userInfo
    }
    
    let codingKey: CodingKey
    
    fileprivate var singleValue: UnsafeMutablePointer<yyjson_mut_val>?
    fileprivate var array: JSONFutureArray?
    fileprivate var object: JSONFutureObject?
    
    init(encoder: JSONEncoderImpl, key: some CodingKey, convertedKey: String, object: JSONFutureObject) {
        self.encoder = encoder
        self.codingKey = key
        self.reference = .object(object, convertedKey)
    }
    
    init(encoder: JSONEncoderImpl, index: Int, array: JSONFutureArray) {
        self.encoder = encoder
        self.codingKey = _CodingKey(index: index)
        self.reference = .array(array, index)
    }
    
    deinit {
        let value: JSONFuture
        if let obj = self.object {
            value = .nestedObject(obj)
        } else if let arr = self.array {
            value = .nestedArray(arr)
        } else {
            value = .value(self.singleValue ?? yyjson_mut_obj(encoder.mutDoc))
        }
        
        switch reference {
        case .array(let arr, let index):
            arr.array.insert(value, at: index)
        case .object(let obj, let key):
            obj.dict[key] = value
        }
    }
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        if let existingObject = self.object {
            let container = JSONKeyedEncodingContainer<Key>(
                encoder: encoder,
                codingPathNode: encoder.codingPathNode.appending(codingKey),
                object: existingObject
            )
            return KeyedEncodingContainer(container)
        }
        
        precondition(
            self.singleValue == nil && self.array == nil,
            "Attempt to push new keyed encoding container when already previously encoded at this path."
        )
        
        let newObject = JSONFutureObject()
        self.object = newObject
        let container = JSONKeyedEncodingContainer<Key>(
            encoder: encoder,
            codingPathNode: encoder.codingPathNode.appending(codingKey),
            object: newObject
        )
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        if let existingArray = self.array {
            return JSONUnkeyedEncodingContainer(
                encoder: encoder,
                codingPathNode: encoder.codingPathNode.appending(codingKey),
                array: existingArray
            )
        }
        
        precondition(
            self.singleValue == nil && self.object == nil,
            "Attempt to push new unkeyed encoding container when already previously encoded at this path."
        )
        
        let newArray = JSONFutureArray()
        self.array = newArray
        return JSONUnkeyedEncodingContainer(
            encoder: encoder,
            codingPathNode: encoder.codingPathNode.appending(codingKey),
            array: newArray
        )
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return JSONReferencingSingleValueContainer(referencingEncoder: self)
    }
}

// MARK: - JSONReferencingSingleValueContainer

private struct JSONReferencingSingleValueContainer: SingleValueEncodingContainer {
    let referencingEncoder: JSONReferencingEncoder
    
    var codingPath: [CodingKey] {
        referencingEncoder.codingPath
    }
    
    private var encoder: JSONEncoderImpl {
        referencingEncoder.encoder
    }
    
    private var mutDoc: UnsafeMutablePointer<yyjson_mut_doc> {
        encoder.mutDoc
    }
    
    func encodeNil() throws {
        referencingEncoder.singleValue = yyjson_mut_null(mutDoc)
    }
    
    func encode(_ value: Bool) throws {
        referencingEncoder.singleValue = yyjson_mut_bool(mutDoc, value)
    }
    
    func encode(_ value: String) throws {
        referencingEncoder.singleValue = encoder.boxString(value)
    }
    
    func encode(_ value: Double) throws {
        referencingEncoder.singleValue = try encoder.boxFloat(value)
    }
    
    func encode(_ value: Float) throws {
        referencingEncoder.singleValue = try encoder.boxFloat(value)
    }
    
    func encode(_ value: Int) throws {
        referencingEncoder.singleValue = yyjson_mut_sint(mutDoc, Int64(value))
    }
    
    func encode(_ value: Int8) throws {
        referencingEncoder.singleValue = yyjson_mut_sint(mutDoc, Int64(value))
    }
    
    func encode(_ value: Int16) throws {
        referencingEncoder.singleValue = yyjson_mut_sint(mutDoc, Int64(value))
    }
    
    func encode(_ value: Int32) throws {
        referencingEncoder.singleValue = yyjson_mut_sint(mutDoc, Int64(value))
    }
    
    func encode(_ value: Int64) throws {
        referencingEncoder.singleValue = yyjson_mut_sint(mutDoc, value)
    }
    
    func encode(_ value: UInt) throws {
        referencingEncoder.singleValue = yyjson_mut_uint(mutDoc, UInt64(value))
    }
    
    func encode(_ value: UInt8) throws {
        referencingEncoder.singleValue = yyjson_mut_uint(mutDoc, UInt64(value))
    }
    
    func encode(_ value: UInt16) throws {
        referencingEncoder.singleValue = yyjson_mut_uint(mutDoc, UInt64(value))
    }
    
    func encode(_ value: UInt32) throws {
        referencingEncoder.singleValue = yyjson_mut_uint(mutDoc, UInt64(value))
    }
    
    func encode(_ value: UInt64) throws {
        referencingEncoder.singleValue = yyjson_mut_uint(mutDoc, value)
    }
    
    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func encode(_ value: Int128) throws {
        referencingEncoder.singleValue = encoder.boxInt128(value)
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func encode(_ value: UInt128) throws {
        referencingEncoder.singleValue = encoder.boxUInt128(value)
    }
    #endif
    
    func encode<T: Encodable>(_ value: T) throws {
        referencingEncoder.singleValue = try encoder.box(value, for: referencingEncoder.codingKey)
    }
}
