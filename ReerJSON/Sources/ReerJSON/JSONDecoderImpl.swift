import Foundation
import yyjson
import JJLISO8601DateFormatter

// MARK: - JSONDecoderImpl

final class JSONDecoderImpl: Decoder {
    var userInfo: [CodingUserInfoKey : Any]
    
//    let value: yyjson_val
    private let valuePointer: UnsafeMutablePointer<yyjson_val>?
//    let containers: JSONDecodingStorage
    let options: ReerJSONDecoder.Options
    
    var codingPath: [CodingKey] = []
    
    init(valuePointer: UnsafeMutablePointer<yyjson_val>, userInfo: [CodingUserInfoKey: Any], options: ReerJSONDecoder.Options) {
        self.valuePointer = valuePointer
//        self.containers = containers
        self.userInfo = userInfo
        self.options = options
    }
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        let type = YYJSONType(rawValue: yyjson_get_type(valuePointer)) ?? .none
        switch type {
        case .object:
            let container = try KeyedContainer<Key>(impl: self)
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
        let type = YYJSONType(rawValue: yyjson_get_type(valuePointer)) ?? .none
        switch type {
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
        let type = YYJSONType(rawValue: yyjson_get_type(valuePointer)) ?? .none
        switch type {
        case .string: return "a string"
        case .number: return "number"
        case .bool: return "bool"
        case .null: return "null"
        case .object: return "a dictionary"
        case .array: return "an array"
        default: return "an unknown"
        }
    }
}

// MARK: - SingleValueDecodingContainer

extension JSONDecoderImpl: SingleValueDecodingContainer {
    func decodeNil() -> Bool {
        return yyjson_is_null(valuePointer)
    }

    func decode(_: Bool.Type) throws -> Bool {
        guard yyjson_is_bool(valuePointer) else {
            throw createTypeMismatchError(type: Bool.self, for: codingPath)
        }
        return yyjson_get_bool(valuePointer)
    }

    func decode(_: String.Type) throws -> String {
        guard let cCharPointer = yyjson_get_str(valuePointer) else {
            throw createTypeMismatchError(type: String.self, for: codingPath)
        }
        return String(cString: cCharPointer)
    }

    func decode(_: Double.Type) throws -> Double {
        guard yyjson_is_num(valuePointer) else {
            throw createTypeMismatchError(type: Double.self, for: codingPath)
        }
        return yyjson_get_num(valuePointer)
    }

    func decode(_: Float.Type) throws -> Float {
        guard yyjson_is_num(valuePointer) else {
            throw createTypeMismatchError(type: Float.self, for: codingPath)
        }
        let doubleValue = yyjson_get_num(valuePointer)
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
        return try unbox(as: type)
    }
    
    @inline(__always)
    private func decodeSignedInteger<T: SignedInteger>() throws -> T {
        guard yyjson_is_sint(valuePointer) else {
            throw createTypeMismatchError(type: Int.self, for: codingPath)
        }
        let value = yyjson_get_sint(valuePointer)
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
        guard yyjson_is_uint(valuePointer) else {
            throw createTypeMismatchError(type: Int.self, for: codingPath)
        }
        let value = yyjson_get_uint(valuePointer)
        guard let uint = T(exactly: value) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "Number \(value) is not representable in Swift."
            ))
        }
        return uint
    }
    
    @inline(__always)
    private func unbox<T: Decodable>(as type: T.Type) throws -> T {
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
        if let cString = yyjson_get_str(valuePointer), let decimal = Decimal(string: String(cString: cString)) {
            return decimal
        }
        
        guard yyjson_is_num(valuePointer) else {
            throw createTypeMismatchError(type: Decimal.self, for: codingPath)
        }
        
        let subtype = YYJSONSubtype(rawValue: yyjson_get_subtype(valuePointer))
        
        switch subtype {
        case .uint:
            return Decimal(yyjson_get_uint(valuePointer))
        case .sint:
            return Decimal(yyjson_get_sint(valuePointer))
        case .real:
            let doubleValue = yyjson_get_real(valuePointer)
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
        
        guard yyjson_is_obj(valuePointer) else {
            throw DecodingError.typeMismatch([String: Decodable].self, .init(
                codingPath: codingPath,
                debugDescription: "Expected to decode \([String: Decodable].self) but found \(debugDataTypeDescription) instead."
            ))
        }
        
        var result = [String: Decodable]()
        
        let objSize = yyjson_obj_size(valuePointer)
        result.reserveCapacity(Int(objSize))
        
        var iter = yyjson_obj_iter()
        guard yyjson_obj_iter_init(valuePointer, &iter) else {
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
            // TODO: - let keyPath = codingPath + [_CodingKey(stringValue: key)!]
            let keyPath = codingPath
            
            //  TODO: - 创建新的decoder来解码值, 性能????
            let valueDecoder = JSONDecoderImpl(
                valuePointer: valuePtr,
                userInfo: userInfo,
                options: options
            )
            valueDecoder.codingPath = keyPath
            
            let decodedValue = try dictType.elementType.init(from: valueDecoder)
            result[key] = decodedValue
        }
        
        return result as! T
    }
}

extension JSONDecoderImpl {
    struct KeyedContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
        typealias Key = K

        let impl: JSONDecoderImpl
//        let codingPathNode: _CodingPathNode
//        let dictionary: [String:JSONMap.Value]

        static func stringify(objectRegion: JSONMap.Region, using impl: JSONDecoderImpl, codingPathNode: _CodingPathNode, keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy) throws -> [String:JSONMap.Value] {
            var result = [String:JSONMap.Value]()
            result.reserveCapacity(objectRegion.count / 2)

            var iter = impl.jsonMap.makeObjectIterator(from: objectRegion.startOffset)
            switch keyDecodingStrategy {
            case .useDefaultKeys:
                while let (keyValue, value) = iter.next() {
                    // We know these values are keys, but UTF-8 decoding could still fail.
                    let key = try impl.unwrapString(from: keyValue, for: codingPathNode, _CodingKey?.none)
                    result[key]._setIfNil(to: value)
                }
            case .convertFromSnakeCase:
                while let (keyValue, value) = iter.next() {
                    // We know these values are keys, but UTF-8 decoding could still fail.
                    let key = try impl.unwrapString(from: keyValue, for: codingPathNode, _CodingKey?.none)

                    // Convert the snake case keys in the container to camel case.
                    // If we hit a duplicate key after conversion, then we'll use the first one we saw.
                    // Effectively an undefined behavior with JSON dictionaries.
                    result[JSONDecoder.KeyDecodingStrategy._convertFromSnakeCase(key)]._setIfNil(to: value)
                }
            case .custom(let converter):
                let codingPathForCustomConverter = codingPathNode.path
                while let (keyValue, value) = iter.next() {
                    // We know these values are keys, but UTF-8 decoding could still fail.
                    let key = try impl.unwrapString(from: keyValue, for: codingPathNode, _CodingKey?.none)

                    var pathForKey = codingPathForCustomConverter
                    pathForKey.append(_CodingKey(stringValue: key)!)
                    result[converter(pathForKey).stringValue]._setIfNil(to: value)
                }
            }

            return result
        }

        init(impl: JSONDecoderImpl) throws {
            self.impl = impl
//            self.codingPathNode = codingPathNode
            self.dictionary = try Self.stringify(objectRegion: region, using: impl, codingPathNode: codingPathNode, keyDecodingStrategy: impl.options.keyDecodingStrategy)
        }

        public var codingPath : [CodingKey] {
            codingPathNode.path
        }

        var allKeys: [K] {
            self.dictionary.keys.compactMap { K(stringValue: $0) }
        }

        func contains(_ key: K) -> Bool {
            dictionary.keys.contains(key.stringValue)
        }

        func decodeNil(forKey key: K) throws -> Bool {
            guard case .null = try getValue(forKey: key) else {
                return false
            }
            return true
        }

        func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
            let value = try getValue(forKey: key)

            guard case .bool(let bool) = value else {
                throw createTypeMismatchError(type: type, forKey: key, value: value)
            }

            return bool
        }

        func decodeIfPresent(_ type: Bool.Type, forKey key: K) throws -> Bool? {
            guard let value = getValueIfPresent(forKey: key) else {
                return nil
            }
            switch value {
            case .null: return nil
            case .bool(let result): return result
            default: throw createTypeMismatchError(type: type, forKey: key, value: value)
            }
        }

        func decode(_ type: String.Type, forKey key: K) throws -> String {
            let value = try getValue(forKey: key)
            return try impl.unwrapString(from: value, for: self.codingPathNode, key)
        }

        func decodeIfPresent(_ type: String.Type, forKey key: K) throws -> String? {
            guard let value = getValueIfPresent(forKey: key) else {
                return nil
            }
            switch value {
            case .null: return nil
            default: return try impl.unwrapString(from: value, for: self.codingPathNode, key)
            }
        }

        func decode(_: Double.Type, forKey key: K) throws -> Double {
            try decodeFloatingPoint(key: key)
        }

        func decodeIfPresent(_: Double.Type, forKey key: K) throws -> Double? {
            try decodeFloatingPointIfPresent(key: key)
        }

        func decode(_: Float.Type, forKey key: K) throws -> Float {
            try decodeFloatingPoint(key: key)
        }

        func decodeIfPresent(_: Float.Type, forKey key: K) throws -> Float? {
            try decodeFloatingPointIfPresent(key: key)
        }

        func decode(_: Int.Type, forKey key: K) throws -> Int {
            try decodeFixedWidthInteger(key: key)
        }

        func decodeIfPresent(_: Int.Type, forKey key: K) throws -> Int? {
            try decodeFixedWidthIntegerIfPresent(key: key)
        }

        func decode(_: Int8.Type, forKey key: K) throws -> Int8 {
            try decodeFixedWidthInteger(key: key)
        }

        func decodeIfPresent(_: Int8.Type, forKey key: K) throws -> Int8? {
            try decodeFixedWidthIntegerIfPresent(key: key)
        }

        func decode(_: Int16.Type, forKey key: K) throws -> Int16 {
            try decodeFixedWidthInteger(key: key)
        }

        func decodeIfPresent(_: Int16.Type, forKey key: K) throws -> Int16? {
            try decodeFixedWidthIntegerIfPresent(key: key)
        }

        func decode(_: Int32.Type, forKey key: K) throws -> Int32 {
            try decodeFixedWidthInteger(key: key)
        }

        func decodeIfPresent(_: Int32.Type, forKey key: K) throws -> Int32? {
            try decodeFixedWidthIntegerIfPresent(key: key)
        }

        func decode(_: Int64.Type, forKey key: K) throws -> Int64 {
            try decodeFixedWidthInteger(key: key)
        }
      
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        func decode(_: Int128.Type, forKey key: K) throws -> Int128 {
          try decodeFixedWidthInteger(key: key)
        }

        func decodeIfPresent(_: Int64.Type, forKey key: K) throws -> Int64? {
            try decodeFixedWidthIntegerIfPresent(key: key)
        }

        func decode(_: UInt.Type, forKey key: K) throws -> UInt {
            try decodeFixedWidthInteger(key: key)
        }

        func decodeIfPresent(_: UInt.Type, forKey key: K) throws -> UInt? {
            try decodeFixedWidthIntegerIfPresent(key: key)
        }

        func decode(_: UInt8.Type, forKey key: K) throws -> UInt8 {
            try decodeFixedWidthInteger(key: key)
        }

        func decodeIfPresent(_: UInt8.Type, forKey key: K) throws -> UInt8? {
            try decodeFixedWidthIntegerIfPresent(key: key)
        }

        func decode(_: UInt16.Type, forKey key: K) throws -> UInt16 {
            try decodeFixedWidthInteger(key: key)
        }

        func decodeIfPresent(_: UInt16.Type, forKey key: K) throws -> UInt16? {
            try decodeFixedWidthIntegerIfPresent(key: key)
        }

        func decode(_: UInt32.Type, forKey key: K) throws -> UInt32 {
            try decodeFixedWidthInteger(key: key)
        }

        func decodeIfPresent(_: UInt32.Type, forKey key: K) throws -> UInt32? {
            try decodeFixedWidthIntegerIfPresent(key: key)
        }

        func decode(_: UInt64.Type, forKey key: K) throws -> UInt64 {
            try decodeFixedWidthInteger(key: key)
        }
      
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        func decode(_: UInt128.Type, forKey key: K) throws -> UInt128 {
          try decodeFixedWidthInteger(key: key)
        }

        func decodeIfPresent(_: UInt64.Type, forKey key: K) throws -> UInt64? {
            try decodeFixedWidthIntegerIfPresent(key: key)
        }

        func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
            try self.impl.unwrap(try getValue(forKey: key), as: type, for: codingPathNode, key)
        }

        func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T? {
            guard let value = getValueIfPresent(forKey: key) else {
                return nil
            }
            switch value {
            case .null: return nil
            default: return try self.impl.unwrap(value, as: type, for: codingPathNode, key)
            }
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
            let value: JSONMap.Value
            do {
                value = try getValue(forKey: key)
            } catch {
                // if there no value for this key then return a null value
                value = .null
            }
            let impl = JSONDecoderImpl(userInfo: self.impl.userInfo, from: self.impl.jsonMap, codingPathNode: self.codingPathNode.appending(key), options: self.impl.options)
            impl.push(value: value)
            return impl
        }

        @inline(__always) private func getValue(forKey key: some CodingKey) throws -> JSONMap.Value {
            guard let value = dictionary[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(
                    codingPath: self.codingPath,
                    debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."
                ))
            }
            return value
        }

        @inline(__always) private func getValueIfPresent(forKey key: some CodingKey) -> JSONMap.Value? {
            dictionary[key.stringValue]
        }

        private func createTypeMismatchError(type: Any.Type, forKey key: K, value: JSONMap.Value) -> DecodingError {
            return DecodingError.typeMismatch(type, .init(
                codingPath: self.codingPathNode.path(byAppending: key), debugDescription: "Expected to decode \(type) but found \(value.debugDataTypeDescription) instead."
            ))
        }

        @inline(__always) private func decodeFixedWidthInteger<T: FixedWidthInteger>(key: Self.Key) throws -> T {
            let value = try getValue(forKey: key)
            return try self.impl.unwrapFixedWidthInteger(from: value, as: T.self, for: codingPathNode, key)
        }

        @inline(__always) private func decodeFloatingPoint<T: PrevalidatedJSONNumberBufferConvertible & BinaryFloatingPoint>(key: K) throws -> T {
            let value = try getValue(forKey: key)
            return try self.impl.unwrapFloatingPoint(from: value, as: T.self, for: codingPathNode, key)
        }

        @inline(__always) private func decodeFixedWidthIntegerIfPresent<T: FixedWidthInteger>(key: Self.Key) throws -> T? {
            guard let value = getValueIfPresent(forKey: key) else {
                return nil
            }
            switch value {
            case .null: return nil
            default: return try self.impl.unwrapFixedWidthInteger(from: value, as: T.self, for: codingPathNode, key)
            }
        }

        @inline(__always) private func decodeFloatingPointIfPresent<T: PrevalidatedJSONNumberBufferConvertible & BinaryFloatingPoint>(key: K) throws -> T? {
            guard let value = getValueIfPresent(forKey: key) else {
                return nil
            }
            switch value {
            case .null: return nil
            default: return try self.impl.unwrapFloatingPoint(from: value, as: T.self, for: codingPathNode, key)
            }
        }
    }
}

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

        let codingPathNode: _CodingPathNode
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

enum YYJSONType: UInt8 {
    case none = 0
    case raw = 1
    case null = 2
    case bool = 3
    case number = 4
    case string = 5
    case array = 6
    case object = 7
}

struct YYJSONSubtype: RawRepresentable, Equatable {
    let rawValue: UInt8
    
    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    static let none = YYJSONSubtype(rawValue: 0 << 3)
    static let `false` = YYJSONSubtype(rawValue: 0 << 3)
    static let `true` = YYJSONSubtype(rawValue: 1 << 3)
    static let uint = YYJSONSubtype(rawValue: 0 << 3)
    static let sint = YYJSONSubtype(rawValue: 1 << 3)
    static let real = YYJSONSubtype(rawValue: 2 << 3)
    static let noesc = YYJSONSubtype(rawValue: 1 << 3)
}

fileprivate var _iso8601Formatter: JJLISO8601DateFormatter = {
    let formatter = JJLISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()

protocol StringDecodableDictionary {
    static var elementType: Decodable.Type { get }
}

extension Dictionary : StringDecodableDictionary where Key == String, Value: Decodable {
    static var elementType: Decodable.Type { return Value.self }
}
