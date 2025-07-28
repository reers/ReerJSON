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

open class ReerJSONEncoder {
    // MARK: Options
    
    /// The output format to produce. Defaults to `[]`.
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
    
    /// The strategy to use in encoding dates. Defaults to `.deferredToDate`.
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
    
    /// The strategy to use in encoding binary data. Defaults to `.base64`.
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
    
    /// The strategy to use in encoding non-conforming numbers. Defaults to `.throw`.
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
    
    /// The strategy to use for encoding keys. Defaults to `.useDefaultKeys`.
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
    
    /// Contextual user-provided information for use during encoding.
    @preconcurrency
    open var userInfo: [CodingUserInfoKey : any Sendable] {
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
    
    /// Options set on the top-level encoder to pass down the encoding hierarchy.
    struct Options {
        var outputFormatting: JSONEncoder.OutputFormatting = []
        var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate
        var dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64
        var nonConformingFloatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .throw
        var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys
        var userInfo: [CodingUserInfoKey : any Sendable] = [:]
    }
    
    /// The options set on the top-level encoder.
    fileprivate var options = Options()
    fileprivate let optionsLock = LockedState<Void>()
    
    // MARK: - Constructing a JSON Encoder
    
    /// Initializes `self` with default strategies.
    public init() {}
    
    
    // MARK: - Encoding Values
    
    /// Encodes the given top-level value and returns its JSON representation.
    ///
    /// - parameter value: The value to encode.
    /// - returns: A new `Data` value containing the encoded JSON data.
    /// - throws: `EncodingError.invalidValue` if a non-conforming floating-point value is encountered during encoding, and the encoding strategy is `.throw`.
    /// - throws: An error if any value throws an error during encoding.
    open func encode<T : Encodable>(_ value: T) throws -> Data {
        guard let doc = yyjson_mut_doc_new(nil) else {
            return try encodeWithFoundationEncoder(value)
        }
        defer {
            yyjson_mut_doc_free(doc)
        }
        let encoder = JSONEncoderImpl(options: options, ownerEncoder: nil, mutDoc: doc)
        
        guard let topLevelValue = try encoder.box(value) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: [],
                debugDescription: "Top-level \(T.self) did not encode any values."
            ))
        }
        
        yyjson_mut_doc_set_root(doc, topLevelValue)
        
        var writeFlags: yyjson_write_flag = 0
        if options.outputFormatting.contains(.prettyPrinted) {
            writeFlags |= YYJSON_WRITE_PRETTY
        }
//        if options.outputFormatting.contains(.sortedKeys) {
//            writeFlags |= YYJSON_WRITE_SORTED_KEYS
//        }
        
        var length: Int = 0
        guard let jsonCString = yyjson_mut_write(doc, writeFlags, &length) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: [],
                debugDescription: "Unable to write JSON from document"
            ))
        }
        defer {
            free(jsonCString)
        }
        
        return Data(bytes: jsonCString, count: length)
    }
    
    func encodeWithFoundationEncoder<T : Encodable>(_ value: T) throws -> Data {
        let encoder = Foundation.JSONEncoder()
        encoder.outputFormatting = outputFormatting
        encoder.dateEncodingStrategy = dateEncodingStrategy
        encoder.dataEncodingStrategy = dataEncodingStrategy
        encoder.nonConformingFloatEncodingStrategy = nonConformingFloatEncodingStrategy
        encoder.keyEncodingStrategy = keyEncodingStrategy
        encoder.userInfo = userInfo
        return try encoder.encode(value)
    }
}

