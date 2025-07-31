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
    /// Options set on the top-level encoder.
    fileprivate let options: ReerJSONEncoder.Options
    var codingPathNode: CodingPathNode
    let mutDoc: UnsafeMutablePointer<yyjson_mut_doc>
    var ownerEncoder: JSONEncoderImpl?
    var sharedSubEncoder: JSONEncoderImpl?
    var codingKey: (any CodingKey)?
    
    /// The encoder's storage.
    var singleValue: UnsafeMutablePointer<yyjson_mut_val>?
    var array: UnsafeMutablePointer<yyjson_mut_val>?
    var object: UnsafeMutablePointer<yyjson_mut_val>?
    
    func takeValue() -> UnsafeMutablePointer<yyjson_mut_val> {
        if let object = self.object {
            self.object = nil
            return .object(object.values)
        }
        if let array = self.array {
            self.array = nil
            return .array(array.values)
        }
        defer {
            self.singleValue = nil
        }
        return self.singleValue
    }
    
    var codingPath: [CodingKey] {
        codingPathNode.path
    }
    
    init(
        options: ReerJSONEncoder.Options,
        ownerEncoder: JSONEncoderImpl?,
        codingKey: (any CodingKey)? = _CodingKey?.none,
        mutDoc: UnsafeMutablePointer<yyjson_mut_doc>
    ) {
        self.options = options
        self.mutDoc = mutDoc
        self.ownerEncoder = ownerEncoder
        self.codingKey = codingKey
    }
    
    /// Contextual user-provided information for use during encoding.
    var userInfo: [CodingUserInfoKey : Any] {
        return self.options.userInfo
    }
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = JSONKeyedEncodingContainer<Key>(encoder: self, codingPathNode: codingPathNode)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return JSONUnkeyedEncodingContainer(encoder: self, codingPathNode: codingPathNode)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
    
    @inline(__always)
    func with(
        _ encode: (JSONEncoderImpl) throws -> (),
        for additionalKey: (some CodingKey)? = _CodingKey?.none
    ) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        var encoder = getEncoder(for: additionalKey)
        defer {
            returnEncoder(&encoder)
        }
        try encode(encoder)
        return encoder.takeValue()
    }

    @inline(__always)
    func getEncoder(for additionalKey: CodingKey?) -> JSONEncoderImpl {
        if let additionalKey {
            if let takenEncoder = sharedSubEncoder {
                self.sharedSubEncoder = nil
                takenEncoder.codingKey = additionalKey
                takenEncoder.ownerEncoder = self
                return takenEncoder
            }
#warning("mutDoc?")
            return JSONEncoderImpl(options: self.options, ownerEncoder: self, codingKey: additionalKey, mutDoc: mutDoc)
        }

        return self
    }

    @inline(__always)
    func returnEncoder(_ encoder: inout JSONEncoderImpl) {
        if encoder !== self, sharedSubEncoder == nil, isKnownUniquelyReferenced(&encoder) {
            encoder.codingKey = nil
            encoder.ownerEncoder = nil // Prevent retain cycle.
            sharedSubEncoder = encoder
        }
    }
}

// MARK: - Boxing Values

extension JSONEncoderImpl {
    
    @inline(__always)
    func box(_ value: Bool) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_bool(mutDoc, value) }
    
    @inline(__always)
    func box(_ value: Int) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_sint(mutDoc, Int64(value)) }
    
    @inline(__always)
    func box(_ value: Int8) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_sint(mutDoc, Int64(value)) }
    
    @inline(__always)
    func box(_ value: Int16) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_sint(mutDoc, Int64(value)) }
    
    @inline(__always)
    func box(_ value: Int32) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_sint(mutDoc, Int64(value)) }
    
    @inline(__always)
    func box(_ value: Int64) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_sint(mutDoc, value) }
    
    @inline(__always)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func box(_ value: Int128) -> UnsafeMutablePointer<yyjson_mut_val> {
        let str = value.description
        return yyjson_mut_strncpy(mutDoc, str, str.utf8.count)
    }

    @inline(__always)
    func box(_ value: UInt) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_uint(mutDoc, UInt64(value)) }
    
    @inline(__always)
    func box(_ value: UInt8) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_uint(mutDoc, UInt64(value)) }
    
    @inline(__always)
    func box(_ value: UInt16) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_uint(mutDoc, UInt64(value)) }
    
    @inline(__always)
    func box(_ value: UInt32) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_uint(mutDoc, UInt64(value)) }
    
    @inline(__always)
    func box(_ value: UInt64) -> UnsafeMutablePointer<yyjson_mut_val> { yyjson_mut_uint(mutDoc, value) }
    
    @inline(__always)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func box(_ value: UInt128) -> UnsafeMutablePointer<yyjson_mut_val> {
        let str = value.description
        return yyjson_mut_strncpy(mutDoc, str, str.utf8.count)
    }
    
    @inline(__always)
    func box(_ value: String) -> UnsafeMutablePointer<yyjson_mut_val> {
        return yyjson_mut_strncpy(mutDoc, value, value.utf8.count)
    }
    
    func box(
        _ dict: [String: Encodable],
        for addtionalKey: (some CodingKey)? = _CodingKey?.none
    ) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        var result: [String: UnsafeMutablePointer<yyjson_mut_val>] = [:]
        result.reserveCapacity(dict.count)

#warning("mutDoc????")
        let encoder = JSONEncoderImpl(options: options, ownerEncoder: self, mutDoc: mutDoc)
        for (key, value) in dict {
            encoder.codingKey = _CodingKey(stringValue: key)
            result[key] = try encoder.box(value)
        }
#warning("the return value???")
        return object
        
    }
    
    func box(
        _ value: Encodable,
        for additionalKey: (some CodingKey)? = _CodingKey?.none
    ) throws -> UnsafeMutablePointer<yyjson_mut_val> {
        return try _box(value, for: additionalKey) ?? yyjson_mut_obj(mutDoc)
    }
    
#warning("use static func or not")
    @inline(__always)
    func boxFloatingPoint<T: BinaryFloatingPoint & CustomStringConvertible>(
        _ float: T,
        for additionalKey: (some CodingKey)? = _CodingKey?.none
    ) throws -> UnsafeMutablePointer<yyjson_mut_val> {
        guard !float.isNaN, !float.isInfinite else {
            if case .convertToString(let posInfString, let negInfString, let nanString) = options.nonConformingFloatEncodingStrategy {
                switch float {
                case T.infinity:
                    return box(posInfString)
                case -T.infinity:
                    return box(negInfString)
                default:
                    return box(nanString)
                }
            }
            throw cannotEncodeNumber(float, encoder: self, additionalKey)
        }
        var string = float.description
        if string.hasSuffix(".0") {
            string.removeLast(2)
        }
        return box(string)
    }
    
    /// 优化的数组编码方法
    /// 相比 Foundation 的复杂优化，yyjson 的 C 实现已经足够高效
    func boxOptimizedArray(
        _ array: EncodableArray,
        for additionalKey: (some CodingKey)? = _CodingKey?.none
    ) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        // yyjson 的数组编码已经高度优化，直接使用标准流程即可
        // 无需像 Foundation 那样手动生成字节数组来绕过容器开销
        
        let yyjsonArray = yyjson_mut_arr(mutDoc)
        
        // 使用 yyjson 的批量创建 API，性能远超逐个添加
        if let intArray = array as? [Int] {
            return intArray.withUnsafeBufferPointer { buffer in
                // Swift Int 在64位系统上是 Int64，直接使用批量 API
                let casted = buffer.baseAddress!.withMemoryRebound(to: Int64.self, capacity: buffer.count) { ptr in
                    return yyjson_mut_arr_with_sint64(mutDoc, ptr, buffer.count)
                }
                return casted
            }
        } else if let int8Array = array as? [Int8] {
            return int8Array.withUnsafeBufferPointer { buffer in
                return yyjson_mut_arr_with_sint8(mutDoc, buffer.baseAddress!, buffer.count)
                yyjson_mut_arr_with_sint8(mutDoc, <#T##int8_t#>, <#T##Int#>)
            }
        } else if let int16Array = array as? [Int16] {
            return int16Array.withUnsafeBufferPointer { buffer in
                return yyjson_mut_arr_with_sint16(mutDoc, buffer.baseAddress!, buffer.count)
            }
        } else if let int32Array = array as? [Int32] {
            return int32Array.withUnsafeBufferPointer { buffer in
                return yyjson_mut_arr_with_sint32(mutDoc, buffer.baseAddress!, buffer.count)
            }
        } else if let int64Array = array as? [Int64] {
            return int64Array.withUnsafeBufferPointer { buffer in
                return yyjson_mut_arr_with_sint64(mutDoc, buffer.baseAddress!, buffer.count)
            }
        } else if let uintArray = array as? [UInt] {
            return uintArray.withUnsafeBufferPointer { buffer in
                let casted = buffer.baseAddress!.withMemoryRebound(to: UInt64.self, capacity: buffer.count) { ptr in
                    return yyjson_mut_arr_with_uint64(mutDoc, ptr, buffer.count)
                }
                return casted
            }
        } else if let uint8Array = array as? [UInt8] {
            return uint8Array.withUnsafeBufferPointer { buffer in
                return yyjson_mut_arr_with_uint8(mutDoc, buffer.baseAddress!, buffer.count)
            }
        } else if let uint16Array = array as? [UInt16] {
            return uint16Array.withUnsafeBufferPointer { buffer in
                return yyjson_mut_arr_with_uint16(mutDoc, buffer.baseAddress!, buffer.count)
            }
        } else if let uint32Array = array as? [UInt32] {
            return uint32Array.withUnsafeBufferPointer { buffer in
                return yyjson_mut_arr_with_uint32(mutDoc, buffer.baseAddress!, buffer.count)
            }
        } else if let uint64Array = array as? [UInt64] {
            return uint64Array.withUnsafeBufferPointer { buffer in
                return yyjson_mut_arr_with_uint64(mutDoc, buffer.baseAddress!, buffer.count)
            }
        }
        // 处理 Int128/UInt128 (如果可用)
        #if compiler(>=6.0)
        else if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *),
                let int128Array = array as? [Int128] {
            for value in int128Array {
                let str = value.description
                yyjson_mut_arr_append(yyjsonArray, yyjson_mut_strncpy(mutDoc, str, str.utf8.count))
            }
        } else if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *),
                  let uint128Array = array as? [UInt128] {
            for value in uint128Array {
                let str = value.description
                yyjson_mut_arr_append(yyjsonArray, yyjson_mut_strncpy(mutDoc, str, str.utf8.count))
            }
        }
        #endif
        // 处理浮点数数组 - 使用批量 API
        else if let doubleArray = array as? [Double] {
            // 检查是否包含特殊值（NaN, Infinity）
            let hasSpecialValues = doubleArray.contains { $0.isNaN || $0.isInfinite }
            if !hasSpecialValues {
                // 没有特殊值，可以使用高效的批量 API
                return doubleArray.withUnsafeBufferPointer { buffer in
                    return yyjson_mut_arr_with_double(mutDoc, buffer.baseAddress!, buffer.count)
                }
            } else {
                // 有特殊值，需要逐个处理以应用 nonConformingFloatEncodingStrategy
                let yyjsonArray = yyjson_mut_arr(mutDoc)
                for value in doubleArray {
                    yyjson_mut_arr_append(yyjsonArray, try boxFloatingPoint(value))
                }
                return yyjsonArray
            }
        } else if let floatArray = array as? [Float] {
            let hasSpecialValues = floatArray.contains { $0.isNaN || $0.isInfinite }
            if !hasSpecialValues {
                return floatArray.withUnsafeBufferPointer { buffer in
                    return yyjson_mut_arr_with_float(mutDoc, buffer.baseAddress!, buffer.count)
                }
            } else {
                let yyjsonArray = yyjson_mut_arr(mutDoc)
                for value in floatArray {
                    yyjson_mut_arr_append(yyjsonArray, try boxFloatingPoint(value))
                }
                return yyjsonArray
            }
        }
        // 处理字符串数组 - 批量处理较复杂，暂时使用逐个添加
        else if let stringArray = array as? [String] {
            // 字符串数组的批量 API 需要复杂的内存管理，为了安全起见使用逐个添加
            // 在实际场景中，字符串数组通常不会成为性能瓶颈
            let yyjsonArray = yyjson_mut_arr(mutDoc)
            for value in stringArray {
                yyjson_mut_arr_append(yyjsonArray, yyjson_mut_strncpy(mutDoc, value, value.utf8.count))
            }
            return yyjsonArray
        }
        // 处理布尔数组 - 使用批量 API
        else if let boolArray = array as? [Bool] {
            return boolArray.withUnsafeBufferPointer { buffer in
                return yyjson_mut_arr_with_bool(mutDoc, buffer.baseAddress!, buffer.count)
            }
        }
        // 处理通用 Encodable 数组
        else if let encodableArray = array as? [Encodable] {
            for value in encodableArray {
                let encodedValue = try _box(value, for: additionalKey)
                yyjson_mut_arr_append(yyjsonArray, encodedValue)
            }
        }
        // 处理嵌套数组的情况（例如 [[Int]]）
        else if let nestedIntArrays = array as? [[Int]] {
            for subArray in nestedIntArrays {
                if let nestedArray = try boxOptimizedArray(subArray, for: additionalKey) {
                    yyjson_mut_arr_append(yyjsonArray, nestedArray)
                } else {
                    // 如果优化失败，走标准流程
                    let encodedValue = try _box(subArray, for: additionalKey)
                    yyjson_mut_arr_append(yyjsonArray, encodedValue)
                }
            }
        } else if let nestedStringArrays = array as? [[String]] {
            for subArray in nestedStringArrays {
                if let nestedArray = try boxOptimizedArray(subArray, for: additionalKey) {
                    yyjson_mut_arr_append(yyjsonArray, nestedArray)
                } else {
                    let encodedValue = try _box(subArray, for: additionalKey)
                    yyjson_mut_arr_append(yyjsonArray, encodedValue)
                }
            }
        }
        else {
            // 对于其他类型，走标准编码流程
            // yyjson 的性能仍然远超 Foundation 的优化版本
            return nil // 让调用方走标准流程
        }
        
        return yyjsonArray
    }
  
    
    func _box<T: Encodable>(
        _ value: T,
        for additionalKey: (some CodingKey)? = _CodingKey?.none
    ) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        if let date = value as? Date {
            return try boxDate(date, for: additionalKey)
        } else if let data = value as? Data {
            return try boxData(data, for: additionalKey)
        } else if let url = value as? URL {
            return box(url.absoluteString)
        } else if let decimal = value as? Decimal {
            return box(decimal.description)
        } else if let encodable = value as? StringEncodableDictionary {
            return try box(encodable as! [String: Encodable], for: additionalKey)
        } else if let array = value as? EncodableArray {
            // 使用 yyjson 直接编码数组，无需手动优化
            return try boxOptimizedArray(array, for: additionalKey)
        }

        return try _wrapGeneric({
            try value.encode(to: $0)
        }, for: additionalKey)
        
//        return try box_(value) ?? yyjson_mut_null(mutDoc)
        if T.self == Date.self || T.self == NSDate.self {
            return try boxDate(value as! Date)
        } else if T.self == Data.self || T.self == NSData.self {
            return try boxData(value as! Data)
        } else if T.self == URL.self || T.self == NSURL.self {
            return boxURL(value as! URL)
        } else if T.self == Decimal.self || T.self == NSDecimalNumber.self {
            return try boxDecimal(value as! Decimal)
        }
        
        return try boxEncodable(value)
    }
    
    func boxEncodable<T: Encodable>(_ value: T) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        let depth = codingPathNode.depth
        if depth > 512 {
            var userInfo: [CodingUserInfoKey: Any] = [:]
            userInfo[CodingUserInfoKey(rawValue: "NSJSONEncodingDepthErrorKey")!] = codingPath
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: codingPath,
                debugDescription: "Too many nested containers",
                underlyingError: NSError(domain: "NSCocoaErrorDomain", code: 512, userInfo: userInfo)
            ))
        }
        
        let encoded = try boxAnyValue(value)
        return encoded
    }
    
    func boxAnyValue<T: Encodable>(_ value: T) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        if let value = value as? Bool {
            return yyjson_mut_bool(mutDoc, value)
        } else if let value = value as? Int {
            return yyjson_mut_sint(mutDoc, Int64(value))
        } else if let value = value as? Int8 {
            return yyjson_mut_sint(mutDoc, Int64(value))
        } else if let value = value as? Int16 {
            return yyjson_mut_sint(mutDoc, Int64(value))
        } else if let value = value as? Int32 {
            return yyjson_mut_sint(mutDoc, Int64(value))
        } else if let value = value as? Int64 {
            return yyjson_mut_sint(mutDoc, value)
        } else if let value = value as? UInt {
            return yyjson_mut_uint(mutDoc, UInt64(value))
        } else if let value = value as? UInt8 {
            return yyjson_mut_uint(mutDoc, UInt64(value))
        } else if let value = value as? UInt16 {
            return yyjson_mut_uint(mutDoc, UInt64(value))
        } else if let value = value as? UInt32 {
            return yyjson_mut_uint(mutDoc, UInt64(value))
        } else if let value = value as? UInt64 {
            return yyjson_mut_uint(mutDoc, value)
        
        }
#if compiler(>=6.0)
        else if let value = value as? Int128 {
            return yyjson_mut_strcpy(mutDoc, String(value))
        } else if let value = value as? UInt128 {
            return yyjson_mut_strcpy(mutDoc, String(value))
        
        }
#endif
        else if let value = value as? Float {
            return try boxFloat(Double(value))
        } else if let value = value as? Double {
            return try boxFloat(value)
        } else if let value = value as? String {
            return yyjson_mut_strcpy(mutDoc, value)
        } else {
            let encoder = JSONEncoderImpl(userInfo: userInfo, codingPathNode: codingPathNode, options: options, mutDoc: mutDoc)
            try value.encode(to: encoder)
            return encoder.getEncodedValue()
        }
    }
    
//    func boxFloat(_ value: Double) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
//        if value.isInfinite || value.isNaN {
//            guard case .convertToString(let positiveInfinity, let negativeInfinity, let nan) = options.nonConformingFloatEncodingStrategy else {
//                throw EncodingError.invalidValue(value, EncodingError.Context(
//                    codingPath: codingPath,
//                    debugDescription: "Unable to encode \(value) directly in JSON."
//                ))
//            }
//            
//            if value == Double.infinity {
//                return yyjson_mut_strcpy(mutDoc, positiveInfinity)
//            } else if value == -Double.infinity {
//                return yyjson_mut_strcpy(mutDoc, negativeInfinity)
//            } else {
//                return yyjson_mut_strcpy(mutDoc, nan)
//            }
//        }
//        
//        return yyjson_mut_real(mutDoc, value)
//    }
    
    func boxDate(
        _ date: Date,
        for additionalKey: (some CodingKey)? = _CodingKey?.none
    ) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        switch options.dateEncodingStrategy {
        case .deferredToDate:
            let encoder = JSONEncoderImpl(userInfo: userInfo, codingPathNode: codingPathNode, options: options, mutDoc: mutDoc)
            try date.encode(to: encoder)
            return encoder.getEncodedValue()
            
        case .secondsSince1970:
            return yyjson_mut_real(mutDoc, date.timeIntervalSince1970)
            
        case .millisecondsSince1970:
            return yyjson_mut_real(mutDoc, date.timeIntervalSince1970 * 1000.0)
            
        case .iso8601:
            return yyjson_mut_strcpy(mutDoc, _iso8601Formatter.string(from: date))
            
        case .formatted(let formatter):
            return yyjson_mut_strcpy(mutDoc, formatter.string(from: date))
            
        case .custom(let closure):
            let encoder = JSONEncoderImpl(userInfo: userInfo, codingPathNode: codingPathNode, options: options, mutDoc: mutDoc)
            try closure(date, encoder)
            return encoder.getEncodedValue()
        }
    }
    
    func boxData(_ data: Data, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        switch options.dataEncodingStrategy {
        case .deferredToData:
            let encoder = JSONEncoderImpl(userInfo: userInfo, codingPathNode: codingPathNode, options: options, mutDoc: mutDoc)
            try data.encode(to: encoder)
            return encoder.getEncodedValue()
            
        case .base64:
            return yyjson_mut_strcpy(mutDoc, data.base64EncodedString())
            
        case .custom(let closure):
            let encoder = JSONEncoderImpl(userInfo: userInfo, codingPathNode: codingPathNode, options: options, mutDoc: mutDoc)
            try closure(data, encoder)
            return encoder.getEncodedValue()
        }
    }
    
    func boxURL(_ url: URL) -> UnsafeMutablePointer<yyjson_mut_val>? {
        return yyjson_mut_strcpy(mutDoc, url.absoluteString)
    }
    
    func boxDecimal(_ decimal: Decimal) throws -> UnsafeMutablePointer<yyjson_mut_val>? {
        return yyjson_mut_strcpy(mutDoc, decimal.description)
    }
    
    private var _encodedValue: UnsafeMutablePointer<yyjson_mut_val>?
    
    func setEncodedValue(_ value: UnsafeMutablePointer<yyjson_mut_val>?) {
        _encodedValue = value
    }
    
    func getEncodedValue() -> UnsafeMutablePointer<yyjson_mut_val>? {
        return _encodedValue
    }
    
    func transformKey(_ key: String) -> String {
        switch options.keyEncodingStrategy {
        case .useDefaultKeys:
            return key
        case .convertToSnakeCase:
            return JSONEncoderImpl.convertToSnakeCase(key)
        case .custom(let closure):
            return closure(codingPath + [_CodingKey(stringValue: key)!]).stringValue
        }
    }
    
    static func convertToSnakeCase(_ key: String) -> String {
        guard !key.isEmpty else { return key }
        
        var result = ""
        var currentIndex = key.startIndex
        let endIndex = key.endIndex
        
        while currentIndex < endIndex {
            let character = key[currentIndex]
            
            if character.isUppercase {
                if currentIndex != key.startIndex {
                    result += "_"
                }
                result += character.lowercased()
            } else {
                result += String(character)
            }
            
            currentIndex = key.index(after: currentIndex)
        }
        
        return result
    }
    
    @inline(never)
    fileprivate func cannotEncodeNumber<T: BinaryFloatingPoint>(
        _ float: T,
        encoder: JSONEncoderImpl,
        _ additionalKey: (some CodingKey)?
    ) -> EncodingError {
        let path = encoder.codingPath + (additionalKey.map { [$0] } ?? [])
        return EncodingError.invalidValue(float, .init(
            codingPath: path,
            debugDescription: "Unable to encode \(T.self).\(float) directly in JSON."
        ))
    }
}

// MARK: - SingleValueEncodingContainer

extension JSONEncoderImpl: SingleValueEncodingContainer {
    @inline(__always)
    private func assertCanEncodeNewValue() {
        precondition(self.singleValue == nil, "Attempt to encode value through single value container when previously value already encoded.")
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
        singleValue = box(value)
    }
    
    func encode(_ value: Double) throws {
        assertCanEncodeNewValue()
        singleValue = try boxFloatingPoint(value)
    }
    
    func encode(_ value: Float) throws {
        assertCanEncodeNewValue()
        singleValue = try boxFloatingPoint(value)
    }
    
    func encode(_ value: Int) throws {
        assertCanEncodeNewValue()
        singleValue = box(value)
    }
    
    func encode(_ value: Int8) throws {
        assertCanEncodeNewValue()
        singleValue = box(value)
    }
    
    func encode(_ value: Int16) throws {
        assertCanEncodeNewValue()
        singleValue = box(value)
    }
    
    func encode(_ value: Int32) throws {
        assertCanEncodeNewValue()
        singleValue = box(value)
    }
    
    func encode(_ value: Int64) throws {
        assertCanEncodeNewValue()
        singleValue = box(value)
    }
    
    func encode(_ value: UInt) throws {
        assertCanEncodeNewValue()
        singleValue = box(value)
    }
    
    func encode(_ value: UInt8) throws {
        assertCanEncodeNewValue()
        singleValue = box(value)
    }
    
    func encode(_ value: UInt16) throws {
        assertCanEncodeNewValue()
        singleValue = box(value)
    }
    
    func encode(_ value: UInt32) throws {
        assertCanEncodeNewValue()
        singleValue = box(value)
    }
    
    func encode(_ value: UInt64) throws {
        assertCanEncodeNewValue()
        singleValue = box(value)
    }
    
    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func encode(_ value: Int128) throws {
        assertCanEncodeNewValue()
        singleValue = box(value)
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func encode(_ value: UInt128) throws {
        assertCanEncodeNewValue()
        singleValue = box(value)
    }
    #endif
    
    func encode<T: Encodable>(_ value: T) throws {
        assertCanEncodeNewValue()
        singleValue = try _box(value)
    }
}

// MARK: - KeyedEncodingContainer

private struct JSONKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K
    
    let encoder: JSONEncoderImpl
    let codingPathNode: CodingPathNode
    private let object: UnsafeMutablePointer<yyjson_mut_val>
    
    var codingPath: [CodingKey] {
        codingPathNode.path
    }
    
    init(encoder: JSONEncoderImpl, codingPathNode: CodingPathNode) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.object = yyjson_mut_obj(encoder.mutDoc)
        encoder.setEncodedValue(object)
    }
    
    mutating func encodeNil(forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let value = yyjson_mut_null(encoder.mutDoc)
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), value)
    }
    
    mutating func encode(_ value: Bool, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = yyjson_mut_bool(encoder.mutDoc, value)
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    mutating func encode(_ value: String, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = yyjson_mut_strcpy(encoder.mutDoc, value)
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    mutating func encode(_ value: Double, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = try encoder.boxFloat(value)
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    mutating func encode(_ value: Float, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = try encoder.boxFloat(Double(value))
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    mutating func encode(_ value: Int, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = yyjson_mut_sint(encoder.mutDoc, Int64(value))
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    mutating func encode(_ value: Int8, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = yyjson_mut_sint(encoder.mutDoc, Int64(value))
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    mutating func encode(_ value: Int16, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = yyjson_mut_sint(encoder.mutDoc, Int64(value))
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    mutating func encode(_ value: Int32, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = yyjson_mut_sint(encoder.mutDoc, Int64(value))
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    mutating func encode(_ value: Int64, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = yyjson_mut_sint(encoder.mutDoc, value)
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    mutating func encode(_ value: UInt, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = yyjson_mut_uint(encoder.mutDoc, UInt64(value))
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    mutating func encode(_ value: UInt8, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = yyjson_mut_uint(encoder.mutDoc, UInt64(value))
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    mutating func encode(_ value: UInt16, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = yyjson_mut_uint(encoder.mutDoc, UInt64(value))
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    mutating func encode(_ value: UInt32, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = yyjson_mut_uint(encoder.mutDoc, UInt64(value))
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    mutating func encode(_ value: UInt64, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = yyjson_mut_uint(encoder.mutDoc, value)
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: Int128, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = yyjson_mut_strcpy(encoder.mutDoc, String(value))
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: UInt128, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = yyjson_mut_strcpy(encoder.mutDoc, String(value))
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    #endif
    
    mutating func encode<T: Encodable>(_ value: T, forKey key: K) throws {
        let transformedKey = encoder.transformKey(key.stringValue)
        let mutValue = try encoder.with(path: codingPathNode.appending(key)) {
            try encoder.box(value)
        }
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), mutValue)
    }
    
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> {
        let transformedKey = encoder.transformKey(key.stringValue)
        let nestedObject = yyjson_mut_obj(encoder.mutDoc)
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), nestedObject)
        
        let nestedEncoder = JSONEncoderImpl(userInfo: encoder.userInfo, codingPathNode: codingPathNode.appending(key), options: encoder.options, mutDoc: encoder.mutDoc)
        nestedEncoder.setEncodedValue(nestedObject)
        
        let container = JSONKeyedEncodingContainer<NestedKey>(encoder: nestedEncoder, codingPathNode: codingPathNode.appending(key))
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        let transformedKey = encoder.transformKey(key.stringValue)
        let nestedArray = yyjson_mut_arr(encoder.mutDoc)
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), nestedArray)
        
        let nestedEncoder = JSONEncoderImpl(userInfo: encoder.userInfo, codingPathNode: codingPathNode.appending(key), options: encoder.options, mutDoc: encoder.mutDoc)
        nestedEncoder.setEncodedValue(nestedArray)
        
        return JSONUnkeyedEncodingContainer(encoder: nestedEncoder, codingPathNode: codingPathNode.appending(key), array: nestedArray)
    }
    
    mutating func superEncoder() -> Encoder {
        return superEncoder(forKey: _CodingKey.super as! K)
    }
    
    mutating func superEncoder(forKey key: K) -> Encoder {
        let transformedKey = encoder.transformKey(key.stringValue)
        let superObject = yyjson_mut_obj(encoder.mutDoc)
        yyjson_mut_obj_add(object, yyjson_mut_strcpy(encoder.mutDoc, transformedKey), superObject)
        
        let superEncoder = JSONEncoderImpl(userInfo: encoder.userInfo, codingPathNode: codingPathNode.appending(key), options: encoder.options, mutDoc: encoder.mutDoc)
        superEncoder.setEncodedValue(superObject)
        
        return superEncoder
    }
}

// MARK: - UnkeyedEncodingContainer

private struct JSONUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let encoder: JSONEncoderImpl
    let codingPathNode: CodingPathNode
    private let array: UnsafeMutablePointer<yyjson_mut_val>
    private var _count = 0
    
    var codingPath: [CodingKey] {
        codingPathNode.path
    }
    
    var count: Int {
        return _count
    }
    
    init(encoder: JSONEncoderImpl, codingPathNode: CodingPathNode) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.array = yyjson_mut_arr(encoder.mutDoc)
        encoder.setEncodedValue(array)
    }
    
    init(encoder: JSONEncoderImpl, codingPathNode: CodingPathNode, array: UnsafeMutablePointer<yyjson_mut_val>) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.array = array
    }
    
    private mutating func appendValue(_ value: UnsafeMutablePointer<yyjson_mut_val>?) {
        yyjson_mut_arr_append(array, value)
        _count += 1
    }
    
    mutating func encodeNil() throws {
        let value = yyjson_mut_null(encoder.mutDoc)
        appendValue(value)
    }
    
    mutating func encode(_ value: Bool) throws {
        let mutValue = yyjson_mut_bool(encoder.mutDoc, value)
        appendValue(mutValue)
    }
    
    mutating func encode(_ value: String) throws {
        let mutValue = yyjson_mut_strcpy(encoder.mutDoc, value)
        appendValue(mutValue)
    }
    
    mutating func encode(_ value: Double) throws {
        let mutValue = try encoder.boxFloat(value)
        appendValue(mutValue)
    }
    
    mutating func encode(_ value: Float) throws {
        let mutValue = try encoder.boxFloat(Double(value))
        appendValue(mutValue)
    }
    
    mutating func encode(_ value: Int) throws {
        let mutValue = yyjson_mut_sint(encoder.mutDoc, Int64(value))
        appendValue(mutValue)
    }
    
    mutating func encode(_ value: Int8) throws {
        let mutValue = yyjson_mut_sint(encoder.mutDoc, Int64(value))
        appendValue(mutValue)
    }
    
    mutating func encode(_ value: Int16) throws {
        let mutValue = yyjson_mut_sint(encoder.mutDoc, Int64(value))
        appendValue(mutValue)
    }
    
    mutating func encode(_ value: Int32) throws {
        let mutValue = yyjson_mut_sint(encoder.mutDoc, Int64(value))
        appendValue(mutValue)
    }
    
    mutating func encode(_ value: Int64) throws {
        let mutValue = yyjson_mut_sint(encoder.mutDoc, value)
        appendValue(mutValue)
    }
    
    mutating func encode(_ value: UInt) throws {
        let mutValue = yyjson_mut_uint(encoder.mutDoc, UInt64(value))
        appendValue(mutValue)
    }
    
    mutating func encode(_ value: UInt8) throws {
        let mutValue = yyjson_mut_uint(encoder.mutDoc, UInt64(value))
        appendValue(mutValue)
    }
    
    mutating func encode(_ value: UInt16) throws {
        let mutValue = yyjson_mut_uint(encoder.mutDoc, UInt64(value))
        appendValue(mutValue)
    }
    
    mutating func encode(_ value: UInt32) throws {
        let mutValue = yyjson_mut_uint(encoder.mutDoc, UInt64(value))
        appendValue(mutValue)
    }
    
    mutating func encode(_ value: UInt64) throws {
        let mutValue = yyjson_mut_uint(encoder.mutDoc, value)
        appendValue(mutValue)
    }
    
    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: Int128) throws {
        let mutValue = yyjson_mut_strcpy(encoder.mutDoc, String(value))
        appendValue(mutValue)
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    mutating func encode(_ value: UInt128) throws {
        let mutValue = yyjson_mut_strcpy(encoder.mutDoc, String(value))
        appendValue(mutValue)
    }
    #endif
    
    mutating func encode<T: Encodable>(_ value: T) throws {
        let mutValue = try encoder.with(path: codingPathNode.appending(index: count)) {
            try encoder.box(value)
        }
        appendValue(mutValue)
    }
    
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let nestedObject = yyjson_mut_obj(encoder.mutDoc)
        appendValue(nestedObject)
        
        let nestedEncoder = JSONEncoderImpl(userInfo: encoder.userInfo, codingPathNode: codingPathNode.appending(index: count - 1), options: encoder.options, mutDoc: encoder.mutDoc)
        nestedEncoder.setEncodedValue(nestedObject)
        
        let container = JSONKeyedEncodingContainer<NestedKey>(encoder: nestedEncoder, codingPathNode: codingPathNode.appending(index: count - 1))
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let nestedArray = yyjson_mut_arr(encoder.mutDoc)
        appendValue(nestedArray)
        
        let nestedEncoder = JSONEncoderImpl(userInfo: encoder.userInfo, codingPathNode: codingPathNode.appending(index: count - 1), options: encoder.options, mutDoc: encoder.mutDoc)
        nestedEncoder.setEncodedValue(nestedArray)
        
        return JSONUnkeyedEncodingContainer(encoder: nestedEncoder, codingPathNode: codingPathNode.appending(index: count - 1), array: nestedArray)
    }
    
    mutating func superEncoder() -> Encoder {
        let superObject = yyjson_mut_obj(encoder.mutDoc)
        appendValue(superObject)
        
        let superEncoder = JSONEncoderImpl(userInfo: encoder.userInfo, codingPathNode: codingPathNode.appending(index: count - 1), options: encoder.options, mutDoc: encoder.mutDoc)
        superEncoder.setEncodedValue(superObject)
        
        return superEncoder
    }
}
