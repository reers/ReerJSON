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

open class ReerJSONEncoder {

    open var outputFormatting: JSONEncoder.OutputFormatting {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.outputFormatting
        }
        _modify {
            optionsLock.lock()
            var value = options.outputFormatting
            defer {
                options.outputFormatting = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.outputFormatting = newValue
        }
    }

    open var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.dateEncodingStrategy
        }
        _modify {
            optionsLock.lock()
            var value = options.dateEncodingStrategy
            defer {
                options.dateEncodingStrategy = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.dateEncodingStrategy = newValue
        }
    }

    open var dataEncodingStrategy: JSONEncoder.DataEncodingStrategy {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.dataEncodingStrategy
        }
        _modify {
            optionsLock.lock()
            var value = options.dataEncodingStrategy
            defer {
                options.dataEncodingStrategy = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.dataEncodingStrategy = newValue
        }
    }

    open var nonConformingFloatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.nonConformingFloatEncodingStrategy
        }
        _modify {
            optionsLock.lock()
            var value = options.nonConformingFloatEncodingStrategy
            defer {
                options.nonConformingFloatEncodingStrategy = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.nonConformingFloatEncodingStrategy = newValue
        }
    }

    open var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.keyEncodingStrategy
        }
        _modify {
            optionsLock.lock()
            var value = options.keyEncodingStrategy
            defer {
                options.keyEncodingStrategy = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.keyEncodingStrategy = newValue
        }
    }

    @preconcurrency
    open var userInfo: [CodingUserInfoKey: any Sendable] {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.userInfo
        }
        _modify {
            optionsLock.lock()
            var value = options.userInfo
            defer {
                options.userInfo = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.userInfo = newValue
        }
    }

    struct Options {
        var outputFormatting: JSONEncoder.OutputFormatting = []
        var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate
        var dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64
        var nonConformingFloatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .throw
        var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys
        var userInfo: [CodingUserInfoKey: any Sendable] = [:]
    }

    fileprivate var options = Options()
    fileprivate let optionsLock = LockedState<Void>()

    public init() {}

    open func encode<T: Encodable>(_ value: T) throws -> Data {
        let doc = yyjson_mut_doc_new(nil)!
        defer { yyjson_mut_doc_free(doc) }
        
        let encoder = JSONEncoderImpl(doc: doc, codingPath: [], options: options)
        
        if let date = value as? Date {
            encoder.singleValue = try encoder.wrapDateValue(date, for: nil)
        } else if let data = value as? Data {
            encoder.singleValue = try encoder.wrapDataValue(data, for: nil)
        } else if let url = value as? URL {
            encoder.singleValue = encoder.wrapString(url.absoluteString)
        } else if let decimal = value as? Decimal {
            encoder.singleValue = yyjson_mut_rawcpy(doc, decimal.description)
        } else if value is _JSONStringDictionaryEncodableMarker, let dict = value as? [String: Encodable] {
            encoder.singleValue = try encoder.wrapStringKeyedDictValue(dict, for: nil)
        } else {
            try value.encode(to: encoder)
        }
        
        guard var root = encoder.takeValue() else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: [],
                debugDescription: "Top-level \(T.self) did not encode any values."
            ))
        }
        
        let sortKeys = outputFormatting.contains(.sortedKeys)
        
        if sortKeys {
            root = sortMutVal(root, doc: doc)
        }
        
        yyjson_mut_doc_set_root(doc, root)
        
        var writeFlag: yyjson_write_flag = YYJSON_WRITE_NOFLAG
        if outputFormatting.contains(.prettyPrinted) {
            writeFlag |= YYJSON_WRITE_PRETTY_TWO_SPACES
        }
        if #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) {
            if !outputFormatting.contains(.withoutEscapingSlashes) {
                writeFlag |= YYJSON_WRITE_ESCAPE_SLASHES
            }
        } else {
            writeFlag |= YYJSON_WRITE_ESCAPE_SLASHES
        }
        
        var len: Int = 0
        guard let cstr = yyjson_mut_write(doc, writeFlag, &len) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: [],
                debugDescription: "Unable to encode the given top-level value to JSON."
            ))
        }
        defer { free(cstr) }
        lowercaseUnicodeEscapes(cstr, len)
        
        if outputFormatting.contains(.prettyPrinted) {
            var data = Data(bytes: cstr, count: len)
            addSpaceBeforeColonInPrettyJSON(&data)
            return data
        }
        return Data(bytes: cstr, count: len)
    }
    
    private func addSpaceBeforeColonInPrettyJSON(_ data: inout Data) {
        // yyjson outputs "key": value but Foundation outputs "key" : value
        var result = Data()
        result.reserveCapacity(data.count + data.count / 10)
        
        var i = 0
        let bytes = Array(data)
        let count = bytes.count
        var inString = false
        var escaped = false
        
        while i < count {
            let byte = bytes[i]
            
            if escaped {
                result.append(byte)
                escaped = false
                i += 1
                continue
            }
            
            if byte == 0x5C /* \ */ && inString {
                result.append(byte)
                escaped = true
                i += 1
                continue
            }
            
            if byte == 0x22 /* " */ {
                inString = !inString
                result.append(byte)
                i += 1
                continue
            }
            
            if !inString && byte == 0x3A /* : */ && i > 0 && bytes[i-1] == 0x22 /* " */ {
                result.append(0x20) // space
                result.append(byte) // :
                i += 1
                continue
            }
            
            result.append(byte)
            i += 1
        }
        
        data = result
    }
    
    private func lowercaseUnicodeEscapes(_ buf: UnsafeMutablePointer<CChar>, _ len: Int) {
        let ptr = UnsafeMutableRawPointer(buf).assumingMemoryBound(to: UInt8.self)
        var i = 0
        while i < len - 5 {
            if ptr[i] == 0x5C /* \ */ && ptr[i+1] == 0x75 /* u */ {
                for j in (i+2)...(i+5) {
                    let c = ptr[j]
                    if c >= 0x41 && c <= 0x46 { // A-F
                        ptr[j] = c + 32 // a-f
                    }
                }
                i += 6
            } else {
                i += 1
            }
        }
    }
    
    private func sortMutVal(_ val: UnsafeMutablePointer<yyjson_mut_val>, doc: UnsafeMutablePointer<yyjson_mut_doc>) -> UnsafeMutablePointer<yyjson_mut_val> {
        if yyjson_mut_is_obj(val) {
            let newObj = yyjson_mut_obj(doc)!
            
            var pairs: [(key: String, keyVal: UnsafeMutablePointer<yyjson_mut_val>, valVal: UnsafeMutablePointer<yyjson_mut_val>)] = []
            
            var iter = yyjson_mut_obj_iter()
            yyjson_mut_obj_iter_init(val, &iter)
            while let keyPtr = yyjson_mut_obj_iter_next(&iter) {
                guard let valPtr = yyjson_mut_obj_iter_get_val(keyPtr) else { continue }
                let keyStr: String
                if let cStr = yyjson_mut_get_str(keyPtr) {
                    keyStr = String(cString: cStr)
                } else {
                    keyStr = ""
                }
                pairs.append((key: keyStr, keyVal: keyPtr, valVal: valPtr))
            }
            
            pairs.sort { a, b in
                a.key.utf8.lexicographicallyPrecedes(b.key.utf8)
            }
            
            for pair in pairs {
                let sortedVal = sortMutVal(pair.valVal, doc: doc)
                let newKey = yyjson_mut_strcpy(doc, pair.key)!
                yyjson_mut_obj_add(newObj, newKey, sortedVal)
            }
            
            return newObj
        } else if yyjson_mut_is_arr(val) {
            let newArr = yyjson_mut_arr(doc)!
            
            var iter = yyjson_mut_arr_iter()
            yyjson_mut_arr_iter_init(val, &iter)
            while let elemPtr = yyjson_mut_arr_iter_next(&iter) {
                let sortedElem = sortMutVal(elemPtr, doc: doc)
                yyjson_mut_arr_append(newArr, sortedElem)
            }
            
            return newArr
        }
        
        return val
    }
}
