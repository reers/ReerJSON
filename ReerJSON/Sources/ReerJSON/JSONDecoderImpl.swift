import Foundation
import yyjson
import JJLISO8601DateFormatter

// MARK: - JSONDecoderImpl

final class JSONDecoderImpl: Decoder {
//    let value: yyjson_val
    private let valuePointer: UnsafeMutablePointer<yyjson_val>?
//    let containers: JSONDecodingStorage
    let keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy
    let dataDecodingStrategy: JSONDecoder.DataDecodingStrategy
    let dateDecodingStrategy: JSONDecoder.DateDecodingStrategy
    let nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy
    
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any]
    
    init(valuePointer: UnsafeMutablePointer<yyjson_val>,
         keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy,
         dataDecodingStrategy: JSONDecoder.DataDecodingStrategy,
         dateDecodingStrategy: JSONDecoder.DateDecodingStrategy,
         nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy,
         userInfo: [CodingUserInfoKey: Any]) {
        self.valuePointer = valuePointer
//        self.containers = containers
        self.keyDecodingStrategy = keyDecodingStrategy
        self.dataDecodingStrategy = dataDecodingStrategy
        self.dateDecodingStrategy = dateDecodingStrategy
        self.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
        self.userInfo = userInfo
    }
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        let container = JSONKeyedDecodingContainer<Key>(
            value: value,
            decoder: self,
            keyDecodingStrategy: keyDecodingStrategy
        )
        return KeyedDecodingContainer(container)
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return JSONUnkeyedDecodingContainer(
            value: value,
            decoder: self
        )
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
        switch dateDecodingStrategy {
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
        switch dataDecodingStrategy {
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
                keyDecodingStrategy: keyDecodingStrategy,
                dataDecodingStrategy: dataDecodingStrategy,
                dateDecodingStrategy: dateDecodingStrategy,
                nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy,
                userInfo: userInfo
            )
            valueDecoder.codingPath = keyPath
            
            let decodedValue = try dictType.elementType.init(from: valueDecoder)
            result[key] = decodedValue
        }
        
        return result as! T
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
