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
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or if the given data is not valid JSON.
    /// - throws: An error if any value throws an error during decoding.
    open func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let doc = data.withUnsafeBytes {
            yyjson_read($0.bindMemory(to: CChar.self).baseAddress, data.count, YYJSON_READ_NUMBER_AS_RAW)
        }
        guard let doc else {
            return try decodeWithFoundationDecoder(type, from: data)
        }
        
        defer {
            yyjson_doc_free(doc)
        }
        
        let json = JSON(pointer: yyjson_doc_get_root(doc))
        let impl = JSONDecoderImpl(json: json, userInfo: userInfo, codingPathNode: .root, options: options)
        return try impl.unbox(json, as: type, for: .root, _CodingKey?.none)
    }
    
    func decodeWithFoundationDecoder<T : Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = Foundation.JSONDecoder()
        decoder.dataDecodingStrategy = dataDecodingStrategy
        decoder.dateDecodingStrategy = dateDecodingStrategy
        decoder.keyDecodingStrategy = keyDecodingStrategy
        decoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
        decoder.userInfo = userInfo
        return try decoder.decode(type, from: data)
    }
}
