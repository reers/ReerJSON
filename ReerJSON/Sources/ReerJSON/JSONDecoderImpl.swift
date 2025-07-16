import Foundation
import yyjson

// MARK: - JSONDecoderImpl

final class JSONDecoderImpl: Decoder {
    let value: yyjson_val
    let containers: JSONDecodingStorage
    let keyDecodingStrategy: ReerJSONDecoder.KeyDecodingStrategy
    let dataDecodingStrategy: ReerJSONDecoder.DataDecodingStrategy
    let dateDecodingStrategy: ReerJSONDecoder.DateDecodingStrategy
    let nonConformingFloatDecodingStrategy: ReerJSONDecoder.NonConformingFloatDecodingStrategy
    
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any]
    
    init(value: yyjson_val, 
         containers: JSONDecodingStorage,
         keyDecodingStrategy: ReerJSONDecoder.KeyDecodingStrategy,
         dataDecodingStrategy: ReerJSONDecoder.DataDecodingStrategy,
         dateDecodingStrategy: ReerJSONDecoder.DateDecodingStrategy,
         nonConformingFloatDecodingStrategy: ReerJSONDecoder.NonConformingFloatDecodingStrategy,
         userInfo: [CodingUserInfoKey: Any]) {
        self.value = value
        self.containers = containers
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
        return JSONSingleValueDecodingContainer(
            value: value,
            decoder: self
        )
    }
}

// MARK: - JSONKeyedDecodingContainer

struct JSONKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let value: yyjson_val
    let decoder: JSONDecoderImpl
    let keyDecodingStrategy: ReerJSONDecoder.KeyDecodingStrategy
    
    var codingPath: [CodingKey] { return decoder.codingPath }
    
    var allKeys: [Key] {
        var keys: [Key] = []
        var mutableValue = value
        
        var iter = yyjson_obj_iter()
        
        yyjson_obj_iter_init(&mutableValue, &iter)
        while let keyPtr = yyjson_obj_iter_next(&iter) {
            if let keyStr = yyjson_get_str(keyPtr) {
                if let codingKey = Key(stringValue: String(cString: keyStr)) {
                    keys.append(codingKey)
                }
            }
        }
        
        return keys
    }
    
    func contains(_ key: Key) -> Bool {
        var mutableValue = value
        return key.stringValue.withCString { keyStr in
            return yyjson_obj_get(&mutableValue, keyStr) != nil
        }
    }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        var mutableValue = value
        return key.stringValue.withCString { keyStr in
            guard let val = yyjson_obj_get(&mutableValue, keyStr) else { return true }
            return yyjson_is_null(val)
        }
    }
    
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        return try _decode(type, forKey: key)
    }
    
    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        return try _decode(type, forKey: key)
    }
    
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        return try _decode(type, forKey: key)
    }
    
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        return try _decode(type, forKey: key)
    }
    
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        return try _decode(type, forKey: key)
    }
    
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return try _decode(type, forKey: key)
    }
    
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return try _decode(type, forKey: key)
    }
    
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return try _decode(type, forKey: key)
    }
    
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        return try _decode(type, forKey: key)
    }
    
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        return try _decode(type, forKey: key)
    }
    
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return try _decode(type, forKey: key)
    }
    
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return try _decode(type, forKey: key)
    }
    
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return try _decode(type, forKey: key)
    }
    
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        return try _decode(type, forKey: key)
    }
    
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        return try _decode(type, forKey: key)
    }
    
    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        let nestedValue = try getValue(forKey: key)
        let nestedDecoder = JSONDecoderImpl(
            value: nestedValue,
            containers: decoder.containers,
            keyDecodingStrategy: decoder.keyDecodingStrategy,
            dataDecodingStrategy: decoder.dataDecodingStrategy,
            dateDecodingStrategy: decoder.dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: decoder.nonConformingFloatDecodingStrategy,
            userInfo: decoder.userInfo
        )
        return try nestedDecoder.container(keyedBy: type)
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let nestedValue = try getValue(forKey: key)
        let nestedDecoder = JSONDecoderImpl(
            value: nestedValue,
            containers: decoder.containers,
            keyDecodingStrategy: decoder.keyDecodingStrategy,
            dataDecodingStrategy: decoder.dataDecodingStrategy,
            dateDecodingStrategy: decoder.dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: decoder.nonConformingFloatDecodingStrategy,
            userInfo: decoder.userInfo
        )
        return try nestedDecoder.unkeyedContainer()
    }
    
    func superDecoder() throws -> Decoder {
        return try superDecoder(forKey: JSONKey(stringValue: "super")! as! Key)
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        let superValue = try getValue(forKey: key)
        return JSONDecoderImpl(
            value: superValue,
            containers: decoder.containers,
            keyDecodingStrategy: decoder.keyDecodingStrategy,
            dataDecodingStrategy: decoder.dataDecodingStrategy,
            dateDecodingStrategy: decoder.dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: decoder.nonConformingFloatDecodingStrategy,
            userInfo: decoder.userInfo
        )
    }
    
    private func _decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let value = try getValue(forKey: key)
        let unboxer = _ReerJSONDecoder(
            value: value,
            containers: decoder.containers,
            keyDecodingStrategy: decoder.keyDecodingStrategy,
            dataDecodingStrategy: decoder.dataDecodingStrategy,
            dateDecodingStrategy: decoder.dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: decoder.nonConformingFloatDecodingStrategy,
            userInfo: decoder.userInfo
        )
        return try unboxer.unbox(value, as: type)
    }
    
    private func getValue(forKey key: Key) throws -> yyjson_val {
        var mutableValue = value
        return key.stringValue.withCString { keyStr in
            guard let val = yyjson_obj_get(&mutableValue, keyStr) else {
                // 返回一个空的 yyjson_val
                return yyjson_val()
            }
            return val.pointee
        }
    }
}

// MARK: - JSONUnkeyedDecodingContainer

struct JSONUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let value: yyjson_val
    let decoder: JSONDecoderImpl
    
    var codingPath: [CodingKey] { return decoder.codingPath }
    
    var count: Int? {
        var mutableValue = value
        return Int(yyjson_arr_size(&mutableValue))
    }
    
    var isAtEnd: Bool {
        return currentIndex >= (count ?? 0)
    }
    
    private(set) var currentIndex: Int = 0
    
    mutating func decodeNil() throws -> Bool {
        let val = try getCurrentValue()
        var mutableVal = val
        return yyjson_is_null(&mutableVal)
    }
    
    mutating func decode(_ type: Bool.Type) throws -> Bool {
        return try _decode(type)
    }
    
    mutating func decode(_ type: String.Type) throws -> String {
        return try _decode(type)
    }
    
    mutating func decode(_ type: Double.Type) throws -> Double {
        return try _decode(type)
    }
    
    mutating func decode(_ type: Float.Type) throws -> Float {
        return try _decode(type)
    }
    
    mutating func decode(_ type: Int.Type) throws -> Int {
        return try _decode(type)
    }
    
    mutating func decode(_ type: Int8.Type) throws -> Int8 {
        return try _decode(type)
    }
    
    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        return try _decode(type)
    }
    
    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        return try _decode(type)
    }
    
    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        return try _decode(type)
    }
    
    mutating func decode(_ type: UInt.Type) throws -> UInt {
        return try _decode(type)
    }
    
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        return try _decode(type)
    }
    
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        return try _decode(type)
    }
    
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        return try _decode(type)
    }
    
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        return try _decode(type)
    }
    
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try _decode(type)
    }
    
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        let nestedValue = try getCurrentValue()
        let nestedDecoder = JSONDecoderImpl(
            value: nestedValue,
            containers: decoder.containers,
            keyDecodingStrategy: decoder.keyDecodingStrategy,
            dataDecodingStrategy: decoder.dataDecodingStrategy,
            dateDecodingStrategy: decoder.dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: decoder.nonConformingFloatDecodingStrategy,
            userInfo: decoder.userInfo
        )
        currentIndex += 1
        return try nestedDecoder.container(keyedBy: type)
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let nestedValue = try getCurrentValue()
        let nestedDecoder = JSONDecoderImpl(
            value: nestedValue,
            containers: decoder.containers,
            keyDecodingStrategy: decoder.keyDecodingStrategy,
            dataDecodingStrategy: decoder.dataDecodingStrategy,
            dateDecodingStrategy: decoder.dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: decoder.nonConformingFloatDecodingStrategy,
            userInfo: decoder.userInfo
        )
        currentIndex += 1
        return try nestedDecoder.unkeyedContainer()
    }
    
    mutating func superDecoder() throws -> Decoder {
        let superValue = try getCurrentValue()
        currentIndex += 1
        return JSONDecoderImpl(
            value: superValue,
            containers: decoder.containers,
            keyDecodingStrategy: decoder.keyDecodingStrategy,
            dataDecodingStrategy: decoder.dataDecodingStrategy,
            dateDecodingStrategy: decoder.dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: decoder.nonConformingFloatDecodingStrategy,
            userInfo: decoder.userInfo
        )
    }
    
    private mutating func _decode<T: Decodable>(_ type: T.Type) throws -> T {
        let value = try getCurrentValue()
        let unboxer = _ReerJSONDecoder(
            value: value,
            containers: decoder.containers,
            keyDecodingStrategy: decoder.keyDecodingStrategy,
            dataDecodingStrategy: decoder.dataDecodingStrategy,
            dateDecodingStrategy: decoder.dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: decoder.nonConformingFloatDecodingStrategy,
            userInfo: decoder.userInfo
        )
        currentIndex += 1
        return try unboxer.unbox(value, as: type)
    }
    
    private mutating func getCurrentValue() throws -> yyjson_val {
        var mutableValue = value
        guard let val = yyjson_arr_get(&mutableValue, currentIndex) else {
            // 返回一个空的 yyjson_val
            return yyjson_val()
        }
        return val.pointee
    }
}

// MARK: - JSONSingleValueDecodingContainer

struct JSONSingleValueDecodingContainer: SingleValueDecodingContainer {
    let value: yyjson_val
    let decoder: JSONDecoderImpl
    
    var codingPath: [CodingKey] { return decoder.codingPath }
    
    func decodeNil() -> Bool {
        var mutableValue = value
        return yyjson_is_null(&mutableValue)
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        return try _decode(type)
    }
    
    func decode(_ type: String.Type) throws -> String {
        return try _decode(type)
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        return try _decode(type)
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        return try _decode(type)
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        return try _decode(type)
    }
    
    func decode(_ type: Int8.Type) throws -> Int8 {
        return try _decode(type)
    }
    
    func decode(_ type: Int16.Type) throws -> Int16 {
        return try _decode(type)
    }
    
    func decode(_ type: Int32.Type) throws -> Int32 {
        return try _decode(type)
    }
    
    func decode(_ type: Int64.Type) throws -> Int64 {
        return try _decode(type)
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        return try _decode(type)
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        return try _decode(type)
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        return try _decode(type)
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        return try _decode(type)
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        return try _decode(type)
    }
    
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try _decode(type)
    }
    
    private func _decode<T: Decodable>(_ type: T.Type) throws -> T {
        let unboxer = _ReerJSONDecoder(
            value: value,
            containers: decoder.containers,
            keyDecodingStrategy: decoder.keyDecodingStrategy,
            dataDecodingStrategy: decoder.dataDecodingStrategy,
            dateDecodingStrategy: decoder.dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: decoder.nonConformingFloatDecodingStrategy,
            userInfo: decoder.userInfo
        )
        return try unboxer.unbox(value, as: type)
    }
} 