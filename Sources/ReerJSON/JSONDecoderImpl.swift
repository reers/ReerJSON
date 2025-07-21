import Foundation
import yyjson
import JJLISO8601DateFormatter

// MARK: - JSONDecoderImpl

final class JSONDecoderImpl: Decoder {
    
    var userInfo: [CodingUserInfoKey: Any]
    let options: ReerJSONDecoder.Options
    
    var codingPathNode: CodingPathNode
    var codingPath: [CodingKey] {
        codingPathNode.path
    }
    
    init(json: JSON, userInfo: [CodingUserInfoKey: Any], codingPathNode: CodingPathNode, options: ReerJSONDecoder.Options) {

        self.codingPathNode = codingPathNode
        self.userInfo = userInfo
        self.options = options
        push(value: json)
    }
    
    var values: ContiguousArray<JSON> = []
    
    @inline(__always)
    var topValue : JSON { values.last! }
    
    @inline(__always)
    func push(value: __owned JSON) {
        values.append(value)
    }
    
    @inline(__always)
    func popValue() {
        values.removeLast()
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
                debugDescription: "Expected to decode \([String: Any].self) but found \(topValue.debugDataTypeDescription) instead."
            ))
        }
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        switch topValue.type {
        case .array:
            return UnkeyedContainer(impl: self, codingPathNode: codingPathNode)
        case .null:
            throw DecodingError.valueNotFound([Any].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Cannot get unkeyed decoding container -- found null value instead"
            ))
        default:
            throw DecodingError.typeMismatch([Any].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected to decode \([Any].self) but found \(topValue.debugDataTypeDescription) instead."
            ))
        }
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return self
    }
    
    private func createTypeMismatchError(type: Any.Type, for path: [CodingKey], value: JSON) -> DecodingError {
        return DecodingError.typeMismatch(type, .init(
            codingPath: path,
            debugDescription: "Expected to decode \(type) but found \(value.debugDataTypeDescription) instead."
        ))
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
    func checkNotNull<T>(
        _ value: JSON,
        expectedType: T.Type,
        for codingPathNode: CodingPathNode,
        _ additionalKey: (some CodingKey)? = nil
    ) throws {
        if value.isNull {
            throw DecodingError.valueNotFound(expectedType, DecodingError.Context(
                codingPath: codingPathNode.path(byAppending: additionalKey),
                debugDescription: "Cannot get value of type \(expectedType) -- found null value instead"
            ))
        }
    }
    
    @inline(__always)
    func unbox<T: Decodable>(
        _ value: JSON,
        as type: T.Type,
        for codingPathNode: CodingPathNode,
        _ additionalKey: (some CodingKey)? = nil
    ) throws -> T {
        if type == Date.self {
            return try unboxDate(from: value, for: codingPathNode, additionalKey) as! T
        }
        if type == Data.self {
            return try unboxData(from: value, for: codingPathNode, additionalKey) as! T
        }
        if type == URL.self {
            return try unboxURL(from: value, for: codingPathNode, additionalKey) as! T
        }
        if type == Decimal.self {
            return try unboxDecimal(from: value, for: codingPathNode, additionalKey) as! T
        }
        if T.self is StringDecodableDictionary.Type {
            return try unboxDictionary(from: value, for: codingPathNode, additionalKey)
        }
        
        return try with(value: value, path: codingPathNode.appending(additionalKey)) {
            try type.init(from: self)
        }
    }
    
    private func unboxDate<K: CodingKey>(from value: JSON, for codingPathNode: CodingPathNode, _ additionalKey: K? = nil) throws -> Date {
        try checkNotNull(value, expectedType: Date.self, for: codingPathNode, additionalKey)
        
        switch options.dateDecodingStrategy {
        case .deferredToDate:
            return try with(value: value, path: codingPathNode.appending(additionalKey)) {
                try Date(from: self)
            }
        case .secondsSince1970:
            let double = try unboxDouble(from: value, for: codingPathNode, additionalKey)
            return Date(timeIntervalSince1970: double)
        case .millisecondsSince1970:
            let double = try unboxDouble(from: value, for: codingPathNode, additionalKey)
            return Date(timeIntervalSince1970: double / 1000.0)
        case .iso8601:
            let string = try unboxString(from: value, for: codingPathNode, additionalKey)
            guard let date = _iso8601Formatter.date(from: string) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Expected date string to be ISO8601-formatted."
                ))
            }
            return date
        case .formatted(let formatter):
            let string = try unboxString(from: value, for: codingPathNode, additionalKey)
            guard let date = formatter.date(from: string) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Date string does not match format expected by formatter."
                ))
            }
            return date
        case .custom(let closure):
            return try with(value: value, path: codingPathNode.appending(additionalKey)) {
                try closure(self)
            }
        @unknown default:
            fatalError()
        }
    }
    
    private func unboxData<K: CodingKey>(from value: JSON, for codingPathNode: CodingPathNode, _ additionalKey: K? = nil) throws -> Data {
        try checkNotNull(value, expectedType: Data.self, for: codingPathNode, additionalKey)
        
        switch options.dataDecodingStrategy {
        case .deferredToData:
            return try with(value: value, path: codingPathNode.appending(additionalKey)) {
                try Data(from: self)
            }
        case .base64:
            let string = try unboxString(from: value, for: codingPathNode, additionalKey)
            guard let data = Data(base64Encoded: string) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Encountered Data is not valid Base64."
                ))
            }
            return data
        case .custom(let closure):
            return try with(value: value, path: codingPathNode.appending(additionalKey)) {
                try closure(self)
            }
        @unknown default:
            fatalError()
        }
    }

    private func unboxURL<K: CodingKey>(from value: JSON, for codingPathNode: CodingPathNode, _ additionalKey: K? = nil) throws -> URL {
        try checkNotNull(value, expectedType: URL.self, for: codingPathNode, additionalKey)
        
        let string = try unboxString(from: value, for: codingPathNode, additionalKey)
        guard let url = URL(string: string) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "Invalid URL string."
            ))
        }
        return url
    }
    
    private func unboxDecimal<K: CodingKey>(from value: JSON, for codingPathNode: CodingPathNode, _ additionalKey: K? = nil) throws -> Decimal {
        try checkNotNull(value, expectedType: Decimal.self, for: codingPathNode, additionalKey)
        
        switch value.subtype {
        case .uint:
            return Decimal(value.unsignedIntegerValue)
        case .sint:
            return Decimal(value.signedIntegerValue)
        case .real:
            let doubleValue = value.realValue
            guard doubleValue.isFinite else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Cannot convert non-finite floating point \(doubleValue) to Decimal."
                ))
            }
            return Decimal(doubleValue)
        default:
            throw createTypeMismatchError(type: Decimal.self, for: codingPath, value: topValue)
        }
    }
    
    private func unboxDictionary<T: Decodable, K: CodingKey>(from value: JSON, for codingPathNode: CodingPathNode, _ additionalKey: K? = nil) throws -> T {
        try checkNotNull(value, expectedType: [String: Any].self, for: codingPathNode, additionalKey)
        
        guard let dictType = T.self as? StringDecodableDictionary.Type else {
            preconditionFailure("Must only be called if T implements StringDecodableDictionary")
        }
        
        guard value.isObject else {
            throw DecodingError.typeMismatch([String: Any].self, .init(
                codingPath: codingPath,
                debugDescription: "Expected to decode \([String: Any].self) but found \(value.debugDataTypeDescription) instead."
            ))
        }
        
        var result = [String: Any]()
        
        let objSize = yyjson_obj_size(value.pointer)
        result.reserveCapacity(Int(objSize))
        
        var iter = yyjson_obj_iter()
        guard yyjson_obj_iter_init(value.pointer, &iter) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "Failed to initialize object iterator."
            ))
        }
        
        let valueType = dictType.elementType
        let dictCodingPathNode = codingPathNode.appending(additionalKey)
        
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
            let elementValue = JSON(pointer: valuePtr)
            
            let decodedValue = try unbox(elementValue, as: valueType, for: dictCodingPathNode, _CodingKey(stringValue: key))
            result[key] = decodedValue
        }
        
        return result as! T
    }
    
    func unboxString<K: CodingKey>(from value: JSON, for codingPathNode: CodingPathNode, _ additionalKey: K? = nil) throws -> String {
        try checkNotNull(value, expectedType: String.self, for: codingPathNode, additionalKey)
        
        guard let string = value.string else {
            throw createTypeMismatchError(type: String.self, for: codingPath, value: value)
        }
        return string
    }

    func unboxDouble<K: CodingKey>(from value: JSON, for codingPathNode: CodingPathNode, _ additionalKey: K? = nil) throws -> Double {
        try checkNotNull(value, expectedType: Double.self, for: codingPathNode, additionalKey)
        
        guard let double = value.double else {
            throw createTypeMismatchError(type: Double.self, for: codingPath, value: value)
        }
        return double
    }
}

// MARK: - SingleValueDecodingContainer

extension JSONDecoderImpl: SingleValueDecodingContainer {
    func decodeNil() -> Bool {
        return topValue.isNull
    }

    func decode(_: Bool.Type) throws -> Bool {
        guard let bool = topValue.bool else {
            throw createTypeMismatchError(type: Bool.self, for: codingPath, value: topValue)
        }
        return bool
    }

    func decode(_: String.Type) throws -> String {
        guard let string = topValue.string else {
            throw createTypeMismatchError(type: String.self, for: codingPath, value: topValue)
        }
        return string
    }

    func decode(_: Double.Type) throws -> Double {
        guard let double = topValue.double else {
            throw createTypeMismatchError(type: Double.self, for: codingPath, value: topValue)
        }
        return double
    }

    func decode(_: Float.Type) throws -> Float {
        guard topValue.isNumber else {
            throw createTypeMismatchError(type: Float.self, for: codingPath, value: topValue)
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
        try decodeInteger()
    }

    func decode(_: Int8.Type) throws -> Int8 {
        try decodeInteger()
    }

    func decode(_: Int16.Type) throws -> Int16 {
        try decodeInteger()
    }

    func decode(_: Int32.Type) throws -> Int32 {
        try decodeInteger()
    }

    func decode(_: Int64.Type) throws -> Int64 {
        try decodeInteger()
    }
  
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func decode(_: Int128.Type) throws -> Int128 {
        try decodeInteger()
    }

    func decode(_: UInt.Type) throws -> UInt {
        try decodeInteger()
    }

    func decode(_: UInt8.Type) throws -> UInt8 {
        try decodeInteger()
    }

    func decode(_: UInt16.Type) throws -> UInt16 {
        try decodeInteger()
    }

    func decode(_: UInt32.Type) throws -> UInt32 {
        try decodeInteger()
    }

    func decode(_: UInt64.Type) throws -> UInt64 {
        try decodeInteger()
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func decode(_: UInt128.Type) throws -> UInt128 {
        try decodeInteger()
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try unbox(topValue, as: type, for: codingPathNode, _CodingKey?.none)
    }
    
    @inline(__always)
    private func decodeInteger<T: FixedWidthInteger>() throws -> T {
        guard topValue.isNumber else {
            throw createTypeMismatchError(type: T.self, for: codingPath, value: topValue)
        }
        guard let int: T =  topValue.integer() else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "Number \(topValue.numberValue) is not representable in Swift."
            ))
        }
        return int
    }
}

// MARK: - KeyedDecodingContainerProtocol

extension JSONDecoderImpl {
    struct KeyedContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
        typealias Key = K

        let impl: JSONDecoderImpl
        let codingPathNode: CodingPathNode

        init(impl: JSONDecoderImpl, codingPathNode: CodingPathNode) throws {
            self.impl = impl
            self.codingPathNode = codingPathNode
        }

        public var codingPath : [CodingKey] {
            impl.codingPath
        }

        var allKeys: [K] {
            var keys: [K] = []
            var iter = yyjson_obj_iter()
            let topValuePtr = impl.topValue.pointer
            guard yyjson_obj_iter_init(topValuePtr, &iter) else {
                return []
            }
            keys.reserveCapacity(Int(yyjson_obj_size(topValuePtr)))
            while let keyPtr = yyjson_obj_iter_next(&iter) {
                if let keyCString = yyjson_get_str(keyPtr), let key = K(stringValue: String(cString: keyCString)) {
                    keys.append(key)
                }
            }
            return keys
        }

        func contains(_ key: K) -> Bool {
            return yyjson_obj_get(impl.topValue.pointer, key.stringValue) != nil
        }

        func decodeNil(forKey key: K) throws -> Bool {
            return try getValue(forKey: key).isNull
        }

        func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
            let jsonValue = try getValue(forKey: key)
            guard let bool = jsonValue.bool else {
                throw createTypeMismatchError(type: Bool.self, forKey: key, value: jsonValue)
            }
            return bool
        }

        func decodeIfPresent(_ type: Bool.Type, forKey key: K) throws -> Bool? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            if jsonValue.isNull { return nil }
            guard let bool = jsonValue.bool else {
                throw createTypeMismatchError(type: Bool.self, forKey: key, value: jsonValue)
            }
            return bool
        }

        func decode(_ type: String.Type, forKey key: K) throws -> String {
            let jsonValue = try getValue(forKey: key)
            guard let string = jsonValue.string else {
                throw createTypeMismatchError(type: String.self, forKey: key, value: jsonValue)
            }
            return string
        }

        func decodeIfPresent(_ type: String.Type, forKey key: K) throws -> String? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            if jsonValue.isNull { return nil }
            guard let string = jsonValue.string else {
                throw createTypeMismatchError(type: String.self, forKey: key, value: jsonValue)
            }
            return string
        }

        func decode(_: Double.Type, forKey key: K) throws -> Double {
            let jsonValue = try getValue(forKey: key)
            guard let double = jsonValue.double else {
                throw createTypeMismatchError(type: Double.self, forKey: key, value: jsonValue)
            }
            return double
        }

        func decodeIfPresent(_: Double.Type, forKey key: K) throws -> Double? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            if jsonValue.isNull { return nil }
            guard let double = jsonValue.double else {
                throw createTypeMismatchError(type: Double.self, forKey: key, value: jsonValue)
            }
            return double
        }

        func decode(_: Float.Type, forKey key: K) throws -> Float {
            let jsonValue = try getValue(forKey: key)
            guard jsonValue.isNumber else {
                throw createTypeMismatchError(type: Float.self, forKey: key, value: jsonValue)
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

        func decodeIfPresent(_: Float.Type, forKey key: K) throws -> Float? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            if jsonValue.isNull { return nil }
            guard jsonValue.isNumber else {
                throw createTypeMismatchError(type: Float.self, forKey: key, value: jsonValue)
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
            return try decodeInteger(jsonValue, forKey: key)
        }

        func decodeIfPresent(_: Int.Type, forKey key: K) throws -> Int? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeIntegerIfPresent(jsonValue, forKey: key)
        }

        func decode(_: Int8.Type, forKey key: K) throws -> Int8 {
            let jsonValue = try getValue(forKey: key)
            return try decodeInteger(jsonValue, forKey: key)
        }

        func decodeIfPresent(_: Int8.Type, forKey key: K) throws -> Int8? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeIntegerIfPresent(jsonValue, forKey: key)
        }

        func decode(_: Int16.Type, forKey key: K) throws -> Int16 {
            let jsonValue = try getValue(forKey: key)
            return try decodeInteger(jsonValue, forKey: key)
        }

        func decodeIfPresent(_: Int16.Type, forKey key: K) throws -> Int16? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeIntegerIfPresent(jsonValue, forKey: key)
        }

        func decode(_: Int32.Type, forKey key: K) throws -> Int32 {
            let jsonValue = try getValue(forKey: key)
            return try decodeInteger(jsonValue, forKey: key)
        }

        func decodeIfPresent(_: Int32.Type, forKey key: K) throws -> Int32? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeIntegerIfPresent(jsonValue, forKey: key)
        }

        func decode(_: Int64.Type, forKey key: K) throws -> Int64 {
            let jsonValue = try getValue(forKey: key)
            return try decodeInteger(jsonValue, forKey: key)
        }
      
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        func decode(_: Int128.Type, forKey key: K) throws -> Int128 {
            let jsonValue = try getValue(forKey: key)
            return try decodeInteger(jsonValue, forKey: key)
        }

        func decodeIfPresent(_: Int64.Type, forKey key: K) throws -> Int64? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeIntegerIfPresent(jsonValue, forKey: key)
        }

        func decode(_: UInt.Type, forKey key: K) throws -> UInt {
            let jsonValue = try getValue(forKey: key)
            return try decodeInteger(jsonValue, forKey: key)
        }

        func decodeIfPresent(_: UInt.Type, forKey key: K) throws -> UInt? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeIntegerIfPresent(jsonValue, forKey: key)
        }

        func decode(_: UInt8.Type, forKey key: K) throws -> UInt8 {
            let jsonValue = try getValue(forKey: key)
            return try decodeInteger(jsonValue, forKey: key)
        }

        func decodeIfPresent(_: UInt8.Type, forKey key: K) throws -> UInt8? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeIntegerIfPresent(jsonValue, forKey: key)
        }

        func decode(_: UInt16.Type, forKey key: K) throws -> UInt16 {
            let valuePointer = try getValue(forKey: key)
            return try decodeInteger(valuePointer, forKey: key)
        }

        func decodeIfPresent(_: UInt16.Type, forKey key: K) throws -> UInt16? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeIntegerIfPresent(jsonValue, forKey: key)
        }

        func decode(_: UInt32.Type, forKey key: K) throws -> UInt32 {
            let jsonValue = try getValue(forKey: key)
            return try decodeInteger(jsonValue, forKey: key)
        }

        func decodeIfPresent(_: UInt32.Type, forKey key: K) throws -> UInt32? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeIntegerIfPresent(jsonValue, forKey: key)
        }

        func decode(_: UInt64.Type, forKey key: K) throws -> UInt64 {
            let jsonValue = try getValue(forKey: key)
            return try decodeInteger(jsonValue, forKey: key)
        }
      
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        func decode(_: UInt128.Type, forKey key: K) throws -> UInt128 {
            let jsonValue = try getValue(forKey: key)
            return try decodeInteger(jsonValue, forKey: key)
        }

        func decodeIfPresent(_: UInt64.Type, forKey key: K) throws -> UInt64? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            return try decodeIntegerIfPresent(jsonValue, forKey: key)
        }

        func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
            return try impl.unbox(try getValue(forKey: key), as: type, for: codingPathNode, key)
        }

        func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T? {
            guard let jsonValue = getValueIfPresent(forKey: key) else {
                return nil
            }
            if jsonValue.isNull { return nil }
            return try impl.unbox(jsonValue, as: type, for: codingPathNode, key)
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
            let value: JSON = getValueIfPresent(forKey: key) ?? .init(pointer: nil)
            let impl = JSONDecoderImpl(json: value, userInfo: impl.userInfo, codingPathNode: impl.codingPathNode.appending(key), options: impl.options)
            return impl
        }

        @inline(__always)
        private func getValue(forKey key: some CodingKey) throws -> JSON {
            guard let valuePtr = yyjson_obj_get(impl.topValue.pointer, key.stringValue) else {
                throw DecodingError.keyNotFound(key, .init(
                    codingPath: codingPath,
                    debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."
                ))
            }
            return JSON(pointer: valuePtr)
        }

        @inline(__always)
        private func getValueIfPresent(forKey key: some CodingKey) -> JSON? {
            guard let valuePtr = yyjson_obj_get(impl.topValue.pointer, key.stringValue) else {
                return nil
            }
            return JSON(pointer: valuePtr)
        }

        private func createTypeMismatchError(type: Any.Type, forKey key: K, value: JSON) -> DecodingError {
            return DecodingError.typeMismatch(type, .init(
                codingPath: self.codingPathNode.path(byAppending: key), debugDescription: "Expected to decode \(type) but found \(value.debugDataTypeDescription) instead."
            ))
        }
        
        @inline(__always)
        private func decodeInteger<T: FixedWidthInteger>(_ jsonValue: JSON, forKey key: K) throws -> T {
            guard jsonValue.isNumber else {
                throw createTypeMismatchError(type: T.self, forKey: key, value: jsonValue)
            }
            guard let int: T =  jsonValue.integer() else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Number \(jsonValue.numberValue) is not representable in Swift."
                ))
            }
            return int
        }
        
        @inline(__always)
        private func decodeIntegerIfPresent<T: FixedWidthInteger>(_ jsonValue: JSON, forKey key: K) throws -> T? {
            if jsonValue.isNull { return nil }
            guard jsonValue.isNumber else {
                throw createTypeMismatchError(type: T.self, forKey: key, value: jsonValue)
            }
            guard let int: T =  jsonValue.integer() else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Number \(jsonValue.numberValue) is not representable in Swift."
                ))
            }
            return int
        }
    }
}

// MARK: - UnkeyedDecodingContainer

extension JSONDecoderImpl {
    struct UnkeyedContainer: UnkeyedDecodingContainer {
        let impl: JSONDecoderImpl
        var arrayPointer: UnsafeMutablePointer<yyjson_val>?
        var peekedValue: JSON?
        let count: Int?

        var isAtEnd: Bool { self.currentIndex >= (self.count ?? 0) }
        var currentIndex = 0

        init(impl: JSONDecoderImpl, codingPathNode: CodingPathNode) {
            self.impl = impl
            self.codingPathNode = codingPathNode
            self.arrayPointer = impl.topValue.pointer
            
            self.count = Int(yyjson_arr_size(arrayPointer))
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

        @inline(__always)
        private mutating func peekNextValueIfPresent<T>(ofType type: T.Type) -> JSON? {
            if let value = peekedValue {
                return value
            }
            
            guard currentIndex < (count ?? 0) else {
                return nil
            }
            
            guard let elementPtr = yyjson_arr_get(arrayPointer, currentIndex) else {
                return nil
            }
            
            let nextValue = JSON(pointer: elementPtr)
            if nextValue.isNull { return nil }
            peekedValue = nextValue
            return nextValue
        }

        @inline(__always)
        private mutating func peekNextValue<T>(ofType type: T.Type) throws -> JSON {
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

        mutating func decodeNil() throws -> Bool {
            let value = try self.peekNextValue(ofType: Never.self)
            if value.isNull {
                advanceToNextValue()
                return true
            } else {
                // The protocol states:
                // If the value is not null, does not increment currentIndex.
                return false
            }
        }

        mutating func decode(_ type: Bool.Type) throws -> Bool {
            let value = try self.peekNextValue(ofType: Bool.self)
            guard let bool = value.bool else {
                throw impl.createTypeMismatchError(type: type, for: codingPath, value: value)
            }
            advanceToNextValue()
            return bool
        }

        mutating func decodeIfPresent(_ type: Bool.Type) throws -> Bool? {
            guard let value = peekNextValueIfPresent(ofType: Bool.self) else {
                advanceToNextValue()
                return nil
            }
            guard let bool = value.bool else {
                throw impl.createTypeMismatchError(type: type, for: currentCodingPath, value: value)
            }
            
            advanceToNextValue()
            return bool
        }

        mutating func decode(_ type: String.Type) throws -> String {
            let value = try self.peekNextValue(ofType: String.self)
            guard let string = value.string else {
                throw impl.createTypeMismatchError(type: type, for: currentCodingPath, value: value)
            }
            advanceToNextValue()
            return string
        }

        mutating func decodeIfPresent(_ type: String.Type) throws -> String? {
            guard let value = peekNextValueIfPresent(ofType: String.self) else {
                advanceToNextValue()
                return nil
            }
            guard let string = value.string else {
                throw impl.createTypeMismatchError(type: type, for: currentCodingPath, value: value)
            }
            
            advanceToNextValue()
            return string
        }

        mutating func decode(_: Double.Type) throws -> Double {
            let value = try peekNextValue(ofType: Double.self)
            guard let double = value.double else {
                throw impl.createTypeMismatchError(type: Double.self, for: currentCodingPath, value: value)
            }
            advanceToNextValue()
            return double
        }

        mutating func decodeIfPresent(_ type: Double.Type) throws -> Double? {
            guard let value = peekNextValueIfPresent(ofType: Double.self) else {
                advanceToNextValue()
                return nil
            }
            guard let double = value.double else {
                throw impl.createTypeMismatchError(type: type, for: currentCodingPath, value: value)
            }
            advanceToNextValue()
            return double
        }

        mutating func decode(_: Float.Type) throws -> Float {
            let value = try peekNextValue(ofType: Float.self)
            guard value.isNumber else {
                throw impl.createTypeMismatchError(type: Float.self, for: currentCodingPath, value: value)
            }
            let doubleValue = value.numberValue
            guard let floatValue = Float(exactly: doubleValue) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "The JSON number \(doubleValue) cannot be represented as a Float without loss of precision."
                ))
            }
            advanceToNextValue()
            return floatValue
        }

        mutating func decodeIfPresent(_ type: Float.Type) throws -> Float? {
            guard let value = peekNextValueIfPresent(ofType: Float.self) else {
                advanceToNextValue()
                return nil
            }
            guard value.isNumber else {
                throw impl.createTypeMismatchError(type: Float.self, for: currentCodingPath, value: value)
            }
            let doubleValue = value.numberValue
            guard let floatValue = Float(exactly: doubleValue) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "The JSON number \(doubleValue) cannot be represented as a Float without loss of precision."
                ))
            }
            advanceToNextValue()
            return floatValue
        }
      

        mutating func decode(_: Int.Type) throws -> Int {
            let value = try peekNextValue(ofType: Int.self)
            return try decodeInteger(value)
        }

        mutating func decodeIfPresent(_: Int.Type) throws -> Int? {
            guard let value = peekNextValueIfPresent(ofType: Int.self) else {
                advanceToNextValue()
                return nil
            }
            return try decodeInteger(value)
        }

        mutating func decode(_: Int8.Type) throws -> Int8 {
            let value = try peekNextValue(ofType: Int8.self)
            return try decodeInteger(value)
        }

        mutating func decodeIfPresent(_: Int8.Type) throws -> Int8? {
            guard let value = peekNextValueIfPresent(ofType: Int8.self) else {
                advanceToNextValue()
                return nil
            }
            return try decodeInteger(value)
        }

        mutating func decode(_: Int16.Type) throws -> Int16 {
            let value = try peekNextValue(ofType: Int16.self)
            return try decodeInteger(value)
        }

        mutating func decodeIfPresent(_: Int16.Type) throws -> Int16? {
            guard let value = peekNextValueIfPresent(ofType: Int16.self) else {
                advanceToNextValue()
                return nil
            }
            return try decodeInteger(value)
        }

        mutating func decode(_: Int32.Type) throws -> Int32 {
            let value = try peekNextValue(ofType: Int32.self)
            return try decodeInteger(value)
        }

        mutating func decodeIfPresent(_: Int32.Type) throws -> Int32? {
            guard let value = peekNextValueIfPresent(ofType: Int32.self) else {
                advanceToNextValue()
                return nil
            }
            return try decodeInteger(value)
        }

        mutating func decode(_: Int64.Type) throws -> Int64 {
            let value = try peekNextValue(ofType: Int64.self)
            return try decodeInteger(value)
        }
      
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        mutating func decode(_: Int128.Type) throws -> Int128 {
            let value = try peekNextValue(ofType: Int128.self)
            return try decodeInteger(value)
        }

        mutating func decodeIfPresent(_: Int64.Type) throws -> Int64? {
            guard let value = peekNextValueIfPresent(ofType: Int64.self) else {
                advanceToNextValue()
                return nil
            }
            return try decodeInteger(value)
        }

        mutating func decode(_: UInt.Type) throws -> UInt {
            let value = try peekNextValue(ofType: UInt.self)
            return try decodeInteger(value)
        }

        mutating func decodeIfPresent(_: UInt.Type) throws -> UInt? {
            guard let value = peekNextValueIfPresent(ofType: UInt.self) else {
                advanceToNextValue()
                return nil
            }
            return try decodeInteger(value)
        }

        mutating func decode(_: UInt8.Type) throws -> UInt8 {
            let value = try peekNextValue(ofType: UInt.self)
            return try decodeInteger(value)
        }

        mutating func decodeIfPresent(_: UInt8.Type) throws -> UInt8? {
            guard let value = peekNextValueIfPresent(ofType: UInt.self) else {
                advanceToNextValue()
                return nil
            }
            return try decodeInteger(value)
        }

        mutating func decode(_: UInt16.Type) throws -> UInt16 {
            let value = try peekNextValue(ofType: UInt.self)
            return try decodeInteger(value)
        }

        mutating func decodeIfPresent(_: UInt16.Type) throws -> UInt16? {
            guard let value = peekNextValueIfPresent(ofType: UInt.self) else {
                advanceToNextValue()
                return nil
            }
            return try decodeInteger(value)
        }

        mutating func decode(_: UInt32.Type) throws -> UInt32 {
            let value = try peekNextValue(ofType: UInt.self)
            return try decodeInteger(value)
        }

        mutating func decodeIfPresent(_: UInt32.Type) throws -> UInt32? {
            guard let value = peekNextValueIfPresent(ofType: UInt.self) else {
                advanceToNextValue()
                return nil
            }
            return try decodeInteger(value)
        }

        mutating func decode(_: UInt64.Type) throws -> UInt64 {
            let value = try peekNextValue(ofType: UInt.self)
            return try decodeInteger(value)
        }
      
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        mutating func decode(_: UInt128.Type) throws -> UInt128 {
            let value = try peekNextValue(ofType: UInt.self)
            return try decodeInteger(value)
        }

        mutating func decodeIfPresent(_: UInt64.Type) throws -> UInt64? {
            guard let value = peekNextValueIfPresent(ofType: UInt.self) else {
                advanceToNextValue()
                return nil
            }
            return try decodeInteger(value)
        }

        mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
            let value = try self.peekNextValue(ofType: type)
            let result = try impl.unbox(value, as: type, for: codingPathNode, currentIndexKey)
            advanceToNextValue()
            return result
        }

        mutating func decodeIfPresent<T: Decodable>(_ type: T.Type) throws -> T? {
            guard let value = self.peekNextValueIfPresent(ofType: type) else {
                advanceToNextValue()
                return nil
            }
            if value.isNull {
                advanceToNextValue()
                return nil
            }
            let result = try impl.unbox(value, as: type, for: codingPathNode, currentIndexKey)
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
            let value = try self.peekNextValue(ofType: Decoder.self)
            let decoder = JSONDecoderImpl(
                json: value,
                userInfo: impl.userInfo,
                codingPathNode: codingPathNode.appending(index: currentIndex),
                options: impl.options
            )
            advanceToNextValue()
            return decoder
        }
        
        @inline(__always)
        private mutating func decodeInteger<T: FixedWidthInteger>(_ jsonValue: JSON) throws -> T {
            guard jsonValue.isNumber else {
                throw impl.createTypeMismatchError(type: T.self, for: currentCodingPath, value: jsonValue)
            }
            guard let int: T =  jsonValue.integer() else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Number \(jsonValue.numberValue) is not representable in Swift."
                ))
            }
            advanceToNextValue()
            return int
        }
    }
}
