import Foundation
import yyjson
import JJLISO8601DateFormatter

// MARK: - JSONDecoderImpl

final class JSONDecoderImpl: Decoder {
    
    var userInfo: [CodingUserInfoKey : Any]
    
//    let value: yyjson_val
    private let root: JSON
//    let containers: JSONDecodingStorage
    let options: ReerJSONDecoder.Options
    
    var codingPathNode: CodingPathNode
    var codingPath: [CodingKey] {
        codingPathNode.path
    }
    
    init(json: JSON, userInfo: [CodingUserInfoKey: Any], codingPathNode: CodingPathNode, options: ReerJSONDecoder.Options) {
        self.root = json
        push(value: json)
        self.codingPathNode = codingPathNode
//        self.containers = containers
        self.userInfo = userInfo
        self.options = options
    }
    
    var values: ContiguousArray<JSON> = []
    
    @inline(__always)
    var topValue : JSON { values.last! }
    
    func push(value: __owned JSON) {
        self.values.append(value)
    }
    
    func popValue() {
        self.values.removeLast()
    }
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        switch topValue.type {
        case .object:
            let container = try KeyedContainer<Key>(impl: self, codingPathNode: codingPathNode)
            return KeyedDecodingContainer(container)
        case .null:
            throw DecodingError.valueNotFound([String: Any].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Cannot get keyed decoding container -- found null value instead"
            ))
        default:
            throw DecodingError.typeMismatch([String: Any].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected to decode \([String: Any].self) but found \(debugDataTypeDescription) instead."
            ))
        }
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        switch topValue.type {
        case .array:
            return UnkeyedContainer(impl: self)
        case .null:
            throw DecodingError.valueNotFound([Any].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Cannot get unkeyed decoding container -- found null value instead"
            ))
        default:
            throw DecodingError.typeMismatch([Any].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected to decode \([Any].self) but found \(debugDataTypeDescription) instead."
            ))
        }
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return self
    }
    
    private func createTypeMismatchError(type: Any.Type, for path: [CodingKey]) -> DecodingError {
        return DecodingError.typeMismatch(type, .init(
            codingPath: path,
            debugDescription: "Expected to decode \(type) but found \(debugDataTypeDescription) instead."
        ))
    }
    
    private var debugDataTypeDescription : String {
        switch topValue.type {
        case .string: return "a string"
        case .number: return "number"
        case .bool: return "bool"
        case .null: return "null"
        case .object: return "a dictionary"
        case .array: return "an array"
        default: return "an unknown"
        }
    }
    
    // Instead of creating a new JSONDecoderImpl for passing to methods that take Decoder arguments, wrap the access in this method, which temporarily mutates this JSONDecoderImpl instance with the nested value and its coding path.
    @inline(__always)
    func with<T>(value: JSON, path: CodingPathNode?, perform closure: () throws -> T) rethrows -> T {
        let oldPath = codingPathNode
        if let path {
            codingPathNode = path
        }
        push(value: value)

        defer {
            if path != nil {
                codingPathNode = oldPath
            }
            popValue()
        }

        return try closure()
    }
    
    @inline(__always)
    func unbox<T: Decodable>(_ value: JSON, as type: T.Type) throws -> T {
        if type == Date.self {
            return try unboxDate() as! T
        }
        if type == Data.self {
            return try unboxData() as! T
        }
        if type == URL.self {
            return try unboxURL() as! T
        }
        if type == Decimal.self {
            return try unboxDecimal() as! T
        }
        if T.self is StringDecodableDictionary.Type {
            return try unboxDictionary()
        }

        return try type.init(from: self)
    }
    
    private func unboxDate() throws -> Date {
        switch options.dateDecodingStrategy {
        case .deferredToDate:
            return try Date(from: self)
        case .secondsSince1970:
            let double = try decode(Double.self)
            return Date(timeIntervalSince1970: double)
        case .millisecondsSince1970:
            let double = try decode(Double.self)
            return Date(timeIntervalSince1970: double / 1000.0)
        case .iso8601:
            let string = try decode(String.self)
            guard let date = _iso8601Formatter.date(from: string) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Expected date string to be ISO8601-formatted."
                ))
            }
            return date
        case .formatted(let formatter):
            let string = try decode(String.self)
            guard let date = formatter.date(from: string) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Date string does not match format expected by formatter."
                ))
            }
            return date
        case .custom(let closure):
            return try closure(self)
        @unknown default:
            fatalError()
        }
    }
    
    private func unboxData() throws -> Data {
        switch options.dataDecodingStrategy {
        case .deferredToData:
            return try Data(from: self)
        case .base64:
            let string = try decode(String.self)
            guard let data = Data(base64Encoded: string) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Encountered Data is not valid Base64."
                ))
            }
            return data
        case .custom(let closure):
            return try closure(self)
        @unknown default:
            fatalError()
        }
    }

    private func unboxURL() throws -> URL {
        let string = try decode(String.self)
        guard let url = URL(string: string) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "Invalid URL string."
            ))
        }
        return url
    }
    
    private func unboxDecimal() throws -> Decimal {
        guard topValue.isNull else {
            throw createTypeMismatchError(type: Decimal.self, for: codingPath)
        }
        
        switch topValue.subtype {
        case .uint:
            return Decimal(topValue.unsignedIntegerValue)
        case .sint:
            return Decimal(topValue.signedIntegerValue)
        case .real:
            let doubleValue = topValue.realValue
            guard doubleValue.isFinite else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Cannot convert non-finite floating point \(doubleValue) to Decimal."
                ))
            }
            return Decimal(doubleValue)
        default:
            throw createTypeMismatchError(type: Decimal.self, for: codingPath)
        }
    }
    
    private func unboxDictionary<T: Decodable>() throws -> T {
        guard let dictType = T.self as? StringDecodableDictionary.Type else {
            preconditionFailure("Must only be called if T implements StringDecodableDictionary")
        }
        
        guard topValue.isObject else {
            throw DecodingError.typeMismatch([String: Any].self, .init(
                codingPath: codingPath,
                debugDescription: "Expected to decode \([String: Any].self) but found \(debugDataTypeDescription) instead."
            ))
        }
        
        var result = [String: Any]()
        
        let objSize = yyjson_obj_size(topValue.pointer)
        result.reserveCapacity(Int(objSize))
        
        var iter = yyjson_obj_iter()
        guard yyjson_obj_iter_init(topValue.pointer, &iter) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "Failed to initialize object iterator."
            ))
        }
        
        while let keyPtr = yyjson_obj_iter_next(&iter) {
            guard let keyCString = yyjson_get_str(keyPtr) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Object key is not a valid string."
                ))
            }
            let key = String(cString: keyCString)
            
            guard let valuePtr = yyjson_obj_iter_get_val(keyPtr) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Failed to get value for key '\(key)'."
                ))
            }
#warning("fix")
            // TODO: - let keyPath = codingPath + [_CodingKey(stringValue: key)!]
            let keyPath = codingPath
            
            //  TODO: - 创建新的decoder来解码值, 性能????
            let valueDecoder = JSONDecoderImpl(
                json: topValue,
                userInfo: userInfo,
                codingPathNode: .root,
                options: options
            )
//            valueDecoder.codingPath = keyPath
            
            let decodedValue = try dictType.elementType.init(from: valueDecoder)
            result[key] = decodedValue
        }
        
        return result as! T
    }
}

// MARK: - SingleValueDecodingContainer

extension JSONDecoderImpl: SingleValueDecodingContainer {
    func decodeNil() -> Bool {
        return topValue.isNull
    }

    func decode(_: Bool.Type) throws -> Bool {
        guard let bool = topValue.bool else {
            throw createTypeMismatchError(type: Bool.self, for: codingPath)
        }
        return bool
    }

    func decode(_: String.Type) throws -> String {
        guard let string = topValue.string else {
            throw createTypeMismatchError(type: String.self, for: codingPath)
        }
        return string
    }

    func decode(_: Double.Type) throws -> Double {
        guard let double = topValue.double else {
            throw createTypeMismatchError(type: Double.self, for: codingPath)
        }
        return double
    }

    func decode(_: Float.Type) throws -> Float {
        guard topValue.isNumber else {
            throw createTypeMismatchError(type: Float.self, for: codingPath)
        }
        let doubleValue = topValue.numberValue
        guard let floatValue = Float(exactly: doubleValue) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "The JSON number \(doubleValue) cannot be represented as a Float without loss of precision."
            ))
        }
        return floatValue
    }

    func decode(_: Int.Type) throws -> Int {
        try decodeSignedInteger()
    }

    func decode(_: Int8.Type) throws -> Int8 {
        try decodeSignedInteger()
    }

    func decode(_: Int16.Type) throws -> Int16 {
        try decodeSignedInteger()
    }

    func decode(_: Int32.Type) throws -> Int32 {
        try decodeSignedInteger()
    }

    func decode(_: Int64.Type) throws -> Int64 {
        try decodeSignedInteger()
    }
  
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func decode(_: Int128.Type) throws -> Int128 {
        try decodeSignedInteger()
    }

    func decode(_: UInt.Type) throws -> UInt {
        try decodeUnsignedInteger()
    }

    func decode(_: UInt8.Type) throws -> UInt8 {
        try decodeUnsignedInteger()
    }

    func decode(_: UInt16.Type) throws -> UInt16 {
        try decodeUnsignedInteger()
    }

    func decode(_: UInt32.Type) throws -> UInt32 {
        try decodeUnsignedInteger()
    }

    func decode(_: UInt64.Type) throws -> UInt64 {
        try decodeUnsignedInteger()
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func decode(_: UInt128.Type) throws -> UInt128 {
        try decodeUnsignedInteger()
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try unbox(topValue, as: type)
    }
    
    @inline(__always)
    private func decodeSignedInteger<T: SignedInteger>() throws -> T {
        guard topValue.isSignedInteger else {
            throw createTypeMismatchError(type: T.self, for: codingPath)
        }
        let value = topValue.signedIntegerValue
        guard let int = T(exactly: value) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "Number \(value) is not representable in Swift."
            ))
        }
        return int
    }
    
    @inline(__always)
    private func decodeUnsignedInteger<T: UnsignedInteger>() throws -> T {
        guard topValue.isUnsignedInteger else {
            throw createTypeMismatchError(type: T.self, for: codingPath)
        }
        let value = topValue.unsignedIntegerValue
        guard let uint = T(exactly: value) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "Number \(value) is not representable in Swift."
            ))
        }
        return uint
    }

    
    
}

// MARK: - KeyedDecodingContainerProtocol

extension JSONDecoderImpl {
    struct KeyedContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
        typealias Key = K

        let impl: JSONDecoderImpl
        let codingPathNode: CodingPathNode
        let dictionary: [String: JSON]

        static func stringify(impl: JSONDecoderImpl) throws -> [String: JSON] {
            var iter = yyjson_obj_iter()
            guard yyjson_obj_iter_init(impl.topValue.pointer, &iter) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: impl.codingPath,
                    debugDescription: "Failed to initialize object iterator."
                ))
            }
            var result: [String: JSON] = [:]
            while let keyPtr = yyjson_obj_iter_next(&iter) {
                guard let keyCString = yyjson_get_str(keyPtr) else {
                    throw DecodingError.dataCorrupted(.init(
                        codingPath: impl.codingPath,
                        debugDescription: "Object key is not a valid string."
                    ))
                }
                let key = String(cString: keyCString)
                
                guard let valuePtr = yyjson_obj_iter_get_val(keyPtr) else {
                    throw DecodingError.dataCorrupted(.init(
                        codingPath: impl.codingPath,
                        debugDescription: "Failed to get value for key '\(key)'."
                    ))
                }
                result[key]._setIfNil(to: JSON(pointer: valuePtr))
            }
            return result
        }

        init(impl: JSONDecoderImpl, codingPathNode: CodingPathNode) throws {
            self.impl = impl
            self.codingPathNode = codingPathNode
            self.dictionary = try Self.stringify(impl: impl)
        }

        public var codingPath : [CodingKey] {
            impl.codingPath
        }

        var allKeys: [K] {
            return dictionary.keys.compactMap { K(stringValue: $0) }
        }

        func contains(_ key: K) -> Bool {
            return dictionary.keys.contains(key.stringValue)
        }

        func decodeNil(forKey key: K) throws -> Bool {
            return try getValue(forKey: key).isNull
        }

        func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
            let jsonValue = try getValue(forKey: key)
            guard let bool = jsonValue.bool else {
                throw createTypeMismatchError(type: Bool.self, for: codingPath)
            }
            return bool
        }

        func decodeIfPresent(_ type: Bool.Type, forKey key: K) throws -> Bool? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            guard let bool = jsonValue.bool else {
                throw createTypeMismatchError(type: Bool.self, for: codingPath)
            }
            return bool
        }

        func decode(_ type: String.Type, forKey key: K) throws -> String {
            let jsonValue = try getValue(forKey: key)
            guard let string = jsonValue.string else {
                throw createTypeMismatchError(type: String.self, for: codingPath)
            }
            return string
        }

        func decodeIfPresent(_ type: String.Type, forKey key: K) throws -> String? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            guard let string = jsonValue.string else {
                throw createTypeMismatchError(type: String.self, for: codingPath)
            }
            return string
        }

        func decode(_: Double.Type, forKey key: K) throws -> Double {
            let jsonValue = try getValue(forKey: key)
            guard let double = jsonValue.double else {
                throw createTypeMismatchError(type: Double.self, for: codingPath)
            }
            return double
        }

        func decodeIfPresent(_: Double.Type, forKey key: K) throws -> Double? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            guard let double = jsonValue.double else {
                throw createTypeMismatchError(type: Double.self, for: codingPath)
            }
            return double
        }

        func decode(_: Float.Type, forKey key: K) throws -> Float {
            let json = try getValue(forKey: key)
            guard json.isNumber else {
                throw createTypeMismatchError(type: Float.self, for: codingPath)
            }
            let doubleValue = json.numberValue
            guard let floatValue = Float(exactly: doubleValue) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "The JSON number \(doubleValue) cannot be represented as a Float without loss of precision."
                ))
            }
            return floatValue
        }

        func decodeIfPresent(_: Float.Type, forKey key: K) throws -> Float? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            guard jsonValue.isNumber else {
                throw createTypeMismatchError(type: Float.self, for: codingPath)
            }
            let doubleValue = jsonValue.numberValue
            guard let floatValue = Float(exactly: doubleValue) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "The JSON number \(doubleValue) cannot be represented as a Float without loss of precision."
                ))
            }
            return floatValue
        }
        
        func decode(_: Int.Type, forKey key: K) throws -> Int {
            let jsonValue = try getValue(forKey: key)
            return try decodeSignedInteger(jsonValue)
        }

        func decodeIfPresent(_: Int.Type, forKey key: K) throws -> Int? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeSignedInteger(jsonValue)
        }

        func decode(_: Int8.Type, forKey key: K) throws -> Int8 {
            let jsonValue = try getValue(forKey: key)
            return try decodeSignedInteger(jsonValue)
        }

        func decodeIfPresent(_: Int8.Type, forKey key: K) throws -> Int8? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeSignedInteger(jsonValue)
        }

        func decode(_: Int16.Type, forKey key: K) throws -> Int16 {
            let jsonValue = try getValue(forKey: key)
            return try decodeSignedInteger(jsonValue)
        }

        func decodeIfPresent(_: Int16.Type, forKey key: K) throws -> Int16? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeSignedInteger(jsonValue)
        }

        func decode(_: Int32.Type, forKey key: K) throws -> Int32 {
            let jsonValue = try getValue(forKey: key)
            return try decodeSignedInteger(jsonValue)
        }

        func decodeIfPresent(_: Int32.Type, forKey key: K) throws -> Int32? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeSignedInteger(jsonValue)
        }

        func decode(_: Int64.Type, forKey key: K) throws -> Int64 {
            let jsonValue = try getValue(forKey: key)
            return try decodeSignedInteger(jsonValue)
        }
      
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        func decode(_: Int128.Type, forKey key: K) throws -> Int128 {
            let jsonValue = try getValue(forKey: key)
            return try decodeSignedInteger(jsonValue)
        }

        func decodeIfPresent(_: Int64.Type, forKey key: K) throws -> Int64? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeSignedInteger(jsonValue)
        }

        func decode(_: UInt.Type, forKey key: K) throws -> UInt {
            let jsonValue = try getValue(forKey: key)
            return try decodeUnsignedInteger(jsonValue)
        }

        func decodeIfPresent(_: UInt.Type, forKey key: K) throws -> UInt? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeUnsignedInteger(jsonValue)
        }

        func decode(_: UInt8.Type, forKey key: K) throws -> UInt8 {
            let jsonValue = try getValue(forKey: key)
            return try decodeUnsignedInteger(jsonValue)
        }

        func decodeIfPresent(_: UInt8.Type, forKey key: K) throws -> UInt8? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeUnsignedInteger(jsonValue)
        }

        func decode(_: UInt16.Type, forKey key: K) throws -> UInt16 {
            let valuePointer = try getValue(forKey: key)
            return try decodeUnsignedInteger(valuePointer)
        }

        func decodeIfPresent(_: UInt16.Type, forKey key: K) throws -> UInt16? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeUnsignedInteger(jsonValue)
        }

        func decode(_: UInt32.Type, forKey key: K) throws -> UInt32 {
            let jsonValue = try getValue(forKey: key)
            return try decodeUnsignedInteger(jsonValue)
        }

        func decodeIfPresent(_: UInt32.Type, forKey key: K) throws -> UInt32? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeUnsignedInteger(jsonValue)
        }

        func decode(_: UInt64.Type, forKey key: K) throws -> UInt64 {
            let jsonValue = try getValue(forKey: key)
            return try decodeUnsignedInteger(jsonValue)
        }
      
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        func decode(_: UInt128.Type, forKey key: K) throws -> UInt128 {
            let jsonValue = try getValue(forKey: key)
            return try decodeUnsignedInteger(jsonValue)
        }

        func decodeIfPresent(_: UInt64.Type, forKey key: K) throws -> UInt64? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeUnsignedInteger(jsonValue)
        }

        func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
            return try impl.unbox(try getValue(forKey: key), as: type)
        }

        func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            if jsonValue.isNull { return nil }
            return try impl.unbox(jsonValue, as: type)
        }

        func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
            let value = try getValue(forKey: key)
            return try impl.with(value: value, path: codingPathNode.appending(key)) {
                try impl.container(keyedBy: type)
            }
        }

        func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
            let value = try getValue(forKey: key)
            return try impl.with(value: value, path: codingPathNode.appending(key)) {
                try impl.unkeyedContainer()
            }
        }

        func superDecoder() throws -> Decoder {
            return decoderForKeyNoThrow(_CodingKey.super)
        }

        func superDecoder(forKey key: K) throws -> Decoder {
            return decoderForKeyNoThrow(key)
        }

        private func decoderForKeyNoThrow(_ key: some CodingKey) -> JSONDecoderImpl {
            let value: JSON
            do {
                value = try getValue(forKey: key)
            } catch {
#warning("test")
                // if there no value for this key then return a null value
                value = .init(pointer: nil)
            }
            let impl = JSONDecoderImpl(json: value, userInfo: impl.userInfo, codingPathNode: impl.codingPathNode, options: impl.options)
            return impl
        }

        @inline(__always)
        private func getValue(forKey key: some CodingKey) throws -> JSON {
            guard let value = dictionary[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(
                    codingPath: codingPath,
                    debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."
                ))
            }
            return value
        }

        @inline(__always)
        private func getValueIfPresent(forKey key: some CodingKey) -> JSON? {
            dictionary[key.stringValue]
        }

        private func createTypeMismatchError(type: Any.Type, forKey key: K, value: JSON) -> DecodingError {
            return DecodingError.typeMismatch(type, .init(
                codingPath: self.codingPathNode.path(byAppending: key), debugDescription: "Expected to decode \(type) but found \(impl.debugDataTypeDescription) instead."
            ))
        }

        @inline(__always)
        private func decodeSignedInteger<T: SignedInteger>(_ jsonValue: JSON) throws -> T {
            guard jsonValue.isSignedInteger else {
                throw createTypeMismatchError(type: T.self, forKey: codingPath, value: <#T##JSON#>)
            }
            let value = jsonValue.signedIntegerValue
            guard let int = T(exactly: value) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Number \(value) is not representable in Swift."
                ))
            }
            return int
        }
        
        @inline(__always)
        private func decodeUnsignedInteger<T: UnsignedInteger>(_ jsonValue: JSON) throws -> T {
            guard jsonValue.isUnsignedInteger else {
                throw createTypeMismatchError(type: T.self, for: codingPath)
            }
            let value = jsonValue.unsignedIntegerValue
            guard let uint = T(exactly: value) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Number \(value) is not representable in Swift."
                ))
            }
            return uint
        }
    }
}

// MARK: - UnkeyedDecodingContainer

extension JSONDecoderImpl {
    struct UnkeyedContainer: UnkeyedDecodingContainer {
        let impl: JSONDecoderImpl
//        var valueIterator: JSONMap.ArrayIterator
//        var peekedValue: JSONMap.Value?
        let count: Int?

        var isAtEnd: Bool { self.currentIndex >= (self.count!) }
        var currentIndex = 0

        init(impl: JSONDecoderImpl, codingPathNode: _CodingPathNode, region: JSONMap.Region) {
            self.impl = impl
            self.codingPathNode = codingPathNode
            self.valueIterator = impl.jsonMap.makeArrayIterator(from: region.startOffset)
            self.count = region.count
        }

        let codingPathNode: CodingPathNode
        
        public var codingPath: [CodingKey] {
            codingPathNode.path
        }

        @inline(__always)
        var currentIndexKey : _CodingKey {
            .init(index: currentIndex)
        }

        @inline(__always)
        var currentCodingPath: [CodingKey] {
            codingPathNode.path(byAppendingIndex: currentIndex)
        }

        private mutating func advanceToNextValue() {
            currentIndex += 1
            peekedValue = nil
        }

        mutating func decodeNil() throws -> Bool {
            let value = try self.peekNextValue(ofType: Never.self)
            switch value {
            case .null:
                advanceToNextValue()
                return true
            default:
                // The protocol states:
                //   If the value is not null, does not increment currentIndex.
                return false
            }
        }

        mutating func decode(_ type: Bool.Type) throws -> Bool {
            let value = try self.peekNextValue(ofType: Bool.self)
            guard case .bool(let bool) = value else {
                throw impl.createTypeMismatchError(type: type, for: self.currentCodingPath, value: value)
            }

            advanceToNextValue()
            return bool
        }

        mutating func decodeIfPresent(_ type: Bool.Type) throws -> Bool? {
            let value = self.peekNextValueIfPresent(ofType: Bool.self)
            let result: Bool? = switch value {
            case nil, .null: nil
            case .bool(let bool): bool
            default: throw impl.createTypeMismatchError(type: type, for: self.currentCodingPath, value: value!)
            }
            advanceToNextValue()
            return result
        }

        mutating func decode(_ type: String.Type) throws -> String {
            let value = try self.peekNextValue(ofType: String.self)
            let string = try impl.unwrapString(from: value, for: codingPathNode, currentIndexKey)
            advanceToNextValue()
            return string
        }

        mutating func decodeIfPresent(_ type: String.Type) throws -> String? {
            let value = self.peekNextValueIfPresent(ofType: String.self)
            let result: String? = switch value {
            case nil, .null: nil
            default: try impl.unwrapString(from: value.unsafelyUnwrapped, for: codingPathNode, currentIndexKey)
            }
            advanceToNextValue()
            return result
        }

        mutating func decode(_: Double.Type) throws -> Double {
            try decodeFloatingPoint()
        }

        mutating func decodeIfPresent(_ type: Double.Type) throws -> Double? {
            try decodeFloatingPointIfPresent()
        }

        mutating func decode(_: Float.Type) throws -> Float {
            try decodeFloatingPoint()
        }

        mutating func decodeIfPresent(_ type: Float.Type) throws -> Float? {
            try decodeFloatingPointIfPresent()
        }

        mutating func decode(_: Int.Type) throws -> Int {
            try decodeFixedWidthInteger()
        }

        mutating func decodeIfPresent(_: Int.Type) throws -> Int? {
            try decodeFixedWidthIntegerIfPresent()
        }

        mutating func decode(_: Int8.Type) throws -> Int8 {
            try decodeFixedWidthInteger()
        }

        mutating func decodeIfPresent(_: Int8.Type) throws -> Int8? {
            try decodeFixedWidthIntegerIfPresent()
        }

        mutating func decode(_: Int16.Type) throws -> Int16 {
            try decodeFixedWidthInteger()
        }

        mutating func decodeIfPresent(_: Int16.Type) throws -> Int16? {
            try decodeFixedWidthIntegerIfPresent()
        }

        mutating func decode(_: Int32.Type) throws -> Int32 {
            try decodeFixedWidthInteger()
        }

        mutating func decodeIfPresent(_: Int32.Type) throws -> Int32? {
            try decodeFixedWidthIntegerIfPresent()
        }

        mutating func decode(_: Int64.Type) throws -> Int64 {
            try decodeFixedWidthInteger()
        }
      
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        mutating func decode(_: Int128.Type) throws -> Int128 {
          try decodeFixedWidthInteger()
        }

        mutating func decodeIfPresent(_: Int64.Type) throws -> Int64? {
            try decodeFixedWidthIntegerIfPresent()
        }

        mutating func decode(_: UInt.Type) throws -> UInt {
            try decodeFixedWidthInteger()
        }

        mutating func decodeIfPresent(_: UInt.Type) throws -> UInt? {
            try decodeFixedWidthIntegerIfPresent()
        }

        mutating func decode(_: UInt8.Type) throws -> UInt8 {
            try decodeFixedWidthInteger()
        }

        mutating func decodeIfPresent(_: UInt8.Type) throws -> UInt8? {
            try decodeFixedWidthIntegerIfPresent()
        }

        mutating func decode(_: UInt16.Type) throws -> UInt16 {
            try decodeFixedWidthInteger()
        }

        mutating func decodeIfPresent(_: UInt16.Type) throws -> UInt16? {
            try decodeFixedWidthIntegerIfPresent()
        }

        mutating func decode(_: UInt32.Type) throws -> UInt32 {
            try decodeFixedWidthInteger()
        }

        mutating func decodeIfPresent(_: UInt32.Type) throws -> UInt32? {
            try decodeFixedWidthIntegerIfPresent()
        }

        mutating func decode(_: UInt64.Type) throws -> UInt64 {
            try decodeFixedWidthInteger()
        }
      
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        mutating func decode(_: UInt128.Type) throws -> UInt128 {
          try decodeFixedWidthInteger()
        }

        mutating func decodeIfPresent(_: UInt64.Type) throws -> UInt64? {
            try decodeFixedWidthIntegerIfPresent()
        }

        mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
            let value = try self.peekNextValue(ofType: type)
            let result = try impl.unwrap(value, as: type, for: codingPathNode, currentIndexKey)

            advanceToNextValue()
            return result
        }

        mutating func decodeIfPresent<T: Decodable>(_ type: T.Type) throws -> T? {
            let value = self.peekNextValueIfPresent(ofType: type)
            let result: T? = switch value {
            case nil, .null: nil
            default: try impl.unwrap(value.unsafelyUnwrapped, as: type, for: codingPathNode, currentIndexKey)
            }
            advanceToNextValue()
            return result
        }

        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
            let value = try self.peekNextValue(ofType: KeyedDecodingContainer<NestedKey>.self)
            let container = try impl.with(value: value, path: codingPathNode.appending(index: currentIndex)) {
                try impl.container(keyedBy: type)
            }

            advanceToNextValue()
            return container
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            let value = try self.peekNextValue(ofType: UnkeyedDecodingContainer.self)
            let container = try impl.with(value: value, path: codingPathNode.appending(index: currentIndex)) {
                try impl.unkeyedContainer()
            }

            advanceToNextValue()
            return container
        }

        mutating func superDecoder() throws -> Decoder {
            let decoder = try decoderForNextElement(ofType: Decoder.self)
            advanceToNextValue()
            return decoder
        }

        private mutating func decoderForNextElement<T>(ofType type: T.Type) throws -> JSONDecoderImpl {
            let value = try self.peekNextValue(ofType: type)
            let impl = JSONDecoderImpl(
                userInfo: self.impl.userInfo,
                from: self.impl.jsonMap,
                codingPathNode: self.codingPathNode.appending(index: self.currentIndex),
                options: self.impl.options
            )
            impl.push(value: value)
            return impl
        }

        @inline(__always)
        private mutating func peekNextValueIfPresent<T>(ofType type: T.Type) -> JSONMap.Value? {
            if let value = peekedValue {
                return value
            }
            guard let nextValue = valueIterator.next() else {
                return nil
            }
            peekedValue = nextValue
            return nextValue
        }

        @inline(__always)
        private mutating func peekNextValue<T>(ofType type: T.Type) throws -> JSONMap.Value {
            guard let nextValue = peekNextValueIfPresent(ofType: type) else {
                var message = "Unkeyed container is at end."
                if T.self == UnkeyedContainer.self {
                    message = "Cannot get nested unkeyed container -- unkeyed container is at end."
                }
                if T.self == Decoder.self {
                    message = "Cannot get superDecoder() -- unkeyed container is at end."
                }

                var path = self.codingPath
                path.append(_CodingKey(index: self.currentIndex))

                throw DecodingError.valueNotFound(
                    type,
                    .init(codingPath: path,
                          debugDescription: message,
                          underlyingError: nil))
            }
            return nextValue
        }

        @inline(__always) private mutating func decodeFixedWidthInteger<T: FixedWidthInteger>() throws -> T {
            let value = try self.peekNextValue(ofType: T.self)
            let key = _CodingKey(index: self.currentIndex)
            let result = try self.impl.unwrapFixedWidthInteger(from: value, as: T.self, for: codingPathNode, key)
            advanceToNextValue()
            return result
        }

        @inline(__always) private mutating func decodeFloatingPoint<T: PrevalidatedJSONNumberBufferConvertible & BinaryFloatingPoint>() throws -> T {
            let value = try self.peekNextValue(ofType: T.self)
            let key = _CodingKey(index: self.currentIndex)
            let result = try self.impl.unwrapFloatingPoint(from: value, as: T.self, for: codingPathNode, key)
            advanceToNextValue()
            return result
        }

        @inline(__always) private mutating func decodeFixedWidthIntegerIfPresent<T: FixedWidthInteger>() throws -> T? {
            let value = self.peekNextValueIfPresent(ofType: T.self)
            let result: T? = switch value {
            case nil, .null: nil
            default: try impl.unwrapFixedWidthInteger(from: value.unsafelyUnwrapped, as: T.self, for: codingPathNode, currentIndexKey)
            }
            advanceToNextValue()
            return result
        }

        @inline(__always) private mutating func decodeFloatingPointIfPresent<T: PrevalidatedJSONNumberBufferConvertible & BinaryFloatingPoint>() throws -> T? {
            let value = self.peekNextValueIfPresent(ofType: T.self)
            let result: T? = switch value {
            case nil, .null: nil
            default: try impl.unwrapFloatingPoint(from: value.unsafelyUnwrapped, as: T.self, for: codingPathNode, currentIndexKey)
            }
            advanceToNextValue()
            return result
        }
    }
}



