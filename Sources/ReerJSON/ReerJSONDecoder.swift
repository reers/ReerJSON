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

open class ReerJSONDecoder {
    /// The strategy to use in decoding dates. Defaults to `.deferredToDate`.
    open var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.dateDecodingStrategy
        }
        _modify {
            optionsLock.lock()
            var value = options.dateDecodingStrategy
            defer {
                options.dateDecodingStrategy = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.dateDecodingStrategy = newValue
        }
    }

    /// The strategy to use in decoding binary data. Defaults to `.base64`.
    open var dataDecodingStrategy: JSONDecoder.DataDecodingStrategy {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.dataDecodingStrategy
        }
        _modify {
            optionsLock.lock()
            var value = options.dataDecodingStrategy
            defer {
                options.dataDecodingStrategy = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.dataDecodingStrategy = newValue
        }
    }

    /// The strategy to use in decoding non-conforming numbers. Defaults to `.throw`.
    open var nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.nonConformingFloatDecodingStrategy
        }
        _modify {
            optionsLock.lock()
            var value = options.nonConformingFloatDecodingStrategy
            defer {
                options.nonConformingFloatDecodingStrategy = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.nonConformingFloatDecodingStrategy = newValue
        }
    }

    /// The strategy to use for decoding keys. Defaults to `.useDefaultKeys`.
    open var keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.keyDecodingStrategy
        }
        _modify {
            optionsLock.lock()
            var value = options.keyDecodingStrategy
            defer {
                options.keyDecodingStrategy = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.keyDecodingStrategy = newValue
        }
    }

    /// Contextual user-provided information for use during decoding.
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
    
    /// Set to `true` to allow parsing of JSON5. Defaults to `false`.
    open var allowsJSON5: Bool {
        get {
            options.json5
        }
        set {
            options.json5 = newValue
        }
    }

    /// Options set on the top-level encoder to pass down the decoding hierarchy.
    struct Options {
        var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate
        var dataDecodingStrategy: JSONDecoder.DataDecodingStrategy = .base64
        var nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw
        var keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
        var userInfo: [CodingUserInfoKey: any Sendable] = [:]
        var json5: Bool = false
    }

    /// The options set on the top-level decoder.
    fileprivate var options = Options()
    fileprivate let optionsLock = LockedState<Void>()

    // MARK: - Constructing a JSON Decoder

    /// Initializes `self` with default strategies.
    public init() {}
    
    // MARK: - Decoding Values

    /// Decodes a top-level value of the given type from the given JSON representation.
    ///
    /// - parameter type: The type of the value to decode.
    /// - parameter data: The data to decode from.
    /// - parameter path: The decoding container path, `["user", "info"]`
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or if the given data is not valid JSON.
    /// - throws: An error if any value throws an error during decoding.
    open func decode<T: Decodable>(_ type: T.Type, from data: Data, path: [String] = []) throws -> T {
        var flag: yyjson_read_flag = YYJSON_READ_NUMBER_AS_RAW
        if options.json5 {
            flag |= YYJSON_READ_JSON5
        }
        let doc = data.withUnsafeBytes {
            yyjson_read(
                $0.bindMemory(to: CChar.self).baseAddress,
                data.count,
                flag
            )
        }
        guard let doc else {
            return try decodeWithFoundationDecoder(type, from: data)
        }
        
        defer {
            yyjson_doc_free(doc)
        }
        
        var pointer = yyjson_doc_get_root(doc)
        for key in path {
            pointer = key.withCString { yyjson_obj_get(pointer, $0) }
        }
        
        let json = JSON(pointer: pointer)
        let impl = JSONDecoderImpl(json: json, userInfo: userInfo, codingPathNode: .root, options: options)
        return try impl.unbox(json, as: type, for: .root, _CodingKey?.none)
    }
    
    /// Decodes a top-level value of the given type from the given JSON representation.
    ///
    /// - parameter type: The type of the value to decode.
    /// - parameter data: The data to decode from.
    /// - parameter path: The decoding container path, `"user.info"`
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or if the given data is not valid JSON.
    /// - throws: An error if any value throws an error during decoding.
    open func decode<T: Decodable>(_ type: T.Type, from data: Data, path: String) throws -> T {
        return try decode(
            type,
            from: data,
            path: path.components(separatedBy: CharacterSet(charactersIn: "."))
        )
    }
    
    #if !os(Linux)
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, visionOS 1, *)
    open func decode<T: DecodableWithConfiguration>(
        _ type: T.Type,
        from data: Data,
        path: [String] = [],
        configuration: T.DecodingConfiguration
    ) throws -> T {
        var flag: yyjson_read_flag = YYJSON_READ_NUMBER_AS_RAW
        if options.json5 {
            flag |= YYJSON_READ_JSON5
        }
        let doc = data.withUnsafeBytes {
            yyjson_read(
                $0.bindMemory(to: CChar.self).baseAddress,
                data.count,
                flag
            )
        }
        guard let doc else {
            if #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) {
                return try decodeWithFoundationDecoder(type, from: data, configuration: configuration)
            } else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [],
                    debugDescription: "Read yyjson_doc failed."
                ))
            }
        }
        
        defer {
            yyjson_doc_free(doc)
        }
        
        var pointer = yyjson_doc_get_root(doc)
        for key in path {
            pointer = key.withCString { yyjson_obj_get(pointer, $0) }
        }
        
        let json = JSON(pointer: pointer)
        let impl = JSONDecoderImpl(json: json, userInfo: userInfo, codingPathNode: .root, options: options)
        return try impl.unbox(json, as: type, configuration: configuration, for: .root,  _CodingKey?.none)
    }
    
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, visionOS 1, *)
    open func decode<T, C>(
        _ type: T.Type,
        from data: Data,
        path: [String] = [],
        configuration: C.Type
    ) throws -> T
    where T: DecodableWithConfiguration,
          C: DecodingConfigurationProviding,
          T.DecodingConfiguration == C.DecodingConfiguration {
        try decode(type, from: data, configuration: C.decodingConfiguration)
    }
    #endif
    
    func decodeWithFoundationDecoder<T : Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = Foundation.JSONDecoder()
        decoder.dataDecodingStrategy = dataDecodingStrategy
        decoder.dateDecodingStrategy = dateDecodingStrategy
        decoder.keyDecodingStrategy = keyDecodingStrategy
        decoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
        decoder.userInfo = userInfo
        return try decoder.decode(type, from: data)
    }
    
    #if !os(Linux)
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
    func decodeWithFoundationDecoder<T : DecodableWithConfiguration>(
        _ type: T.Type,
        from data: Data,
        configuration: T.DecodingConfiguration
    ) throws -> T {
        let decoder = Foundation.JSONDecoder()
        decoder.dataDecodingStrategy = dataDecodingStrategy
        decoder.dateDecodingStrategy = dateDecodingStrategy
        decoder.keyDecodingStrategy = keyDecodingStrategy
        decoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
        decoder.userInfo = userInfo
        return try decoder.decode(type, from: data, configuration: configuration)
    }
    #endif
}
