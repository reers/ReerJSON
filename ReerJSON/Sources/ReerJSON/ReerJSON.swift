import Foundation
import yyjson
//#if !os(Linux)
//import JJLISO8601DateFormatter
//#endif


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

    /// Options set on the top-level encoder to pass down the decoding hierarchy.
    fileprivate struct _Options {
        var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate
        var dataDecodingStrategy: JSONDecoder.DataDecodingStrategy = .base64
        var nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw
        var keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
        var userInfo: [CodingUserInfoKey : any Sendable] = [:]
        var json5: Bool = false
    }

    /// The options set on the top-level decoder.
    fileprivate var options = _Options()
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
//        try _decode({
//            try $0.unwrap($1, as: type, for: .root, _CodingKey?.none)
//        }, from: data)
    }
    
    func decodeWithFoundationDecoder<T : Decodable>(_ type: T.Type, from data: Data, reason: String?) throws -> T {
        let appleDecoder = Foundation.JSONDecoder()
        appleDecoder.dataDecodingStrategy = dataDecodingStrategy
        appleDecoder.dateDecodingStrategy = dateDecodingStrategy
        appleDecoder.keyDecodingStrategy = keyDecodingStrategy
        appleDecoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
        appleDecoder.userInfo = userInfo
        return try appleDecoder.decode(type, from: data)
    }
}


// MARK: - JSON Key

//struct JSONKey: CodingKey {
//    var stringValue: String
//    var intValue: Int?
//    
//    init?(stringValue: String) {
//        self.stringValue = stringValue
//        self.intValue = nil
//    }
//    
//    init?(intValue: Int) {
//        self.stringValue = String(intValue)
//        self.intValue = intValue
//    }
//    
//    init(index: Int) {
//        self.stringValue = String(index)
//        self.intValue = index
//    }
//}
//
//// MARK: - JSONDecodingStorage
//
//final class JSONDecodingStorage {
//    private(set) var containers: [yyjson_val] = []
//    
//    init() {}
//    
//    func createCopy() -> JSONDecodingStorage {
//        let copy = JSONDecodingStorage()
//        copy.containers = containers
//        return copy
//    }
//    
//    var topContainer: yyjson_val {
//        precondition(!containers.isEmpty, "Empty container stack.")
//        return containers.last!
//    }
//    
//    func push(container: yyjson_val) {
//        containers.append(container)
//    }
//    
//    func popContainer() {
//        precondition(!containers.isEmpty, "Empty container stack.")
//        containers.removeLast()
//    }
//}
//
//// MARK: - ReerJSONDecoder
//
//public final class ReerJSONDecoder {
//    
//    // MARK: - Properties
//    
//    /// 配置选项
//    public var userInfo: [CodingUserInfoKey: Any] = [:]
//    
//    /// 非标准浮点数处理策略
//    public var nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy = .throw
//    
//    /// 数据解码策略
//    public var dataDecodingStrategy: DataDecodingStrategy = .base64
//    
//    /// 键解码策略
//    public var keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys
//    
//    /// 日期解码策略
//    public var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate
//    
//    /// 是否启用完全精度浮点数解析
//    public var fullPrecisionFloatParsing = true
//    
//    /// 是否抑制警告
//    private static var _suppressWarnings: Bool = false
//    public static var suppressWarnings: Bool {
//        get {
//            return _suppressWarnings
//        }
//        set {
//            objc_sync_enter(self)
//            defer { objc_sync_exit(self) }
//            _suppressWarnings = newValue
//        }
//    }
//    
//    // MARK: - Initialization
//    
//    public init() {}
//    
//    // MARK: - Public Methods
//    
//    /// 解码 JSON 数据为指定类型
//    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
//        // 检查是否支持自定义键解码策略
//        if case .custom(_) = keyDecodingStrategy {
//            return try decodeWithAppleDecoder(type, from: data, reason: "Custom key decoding is not supported")
//        }
//        
//        return try data.withUnsafeBytes { bytes -> T in
//            guard let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress else {
//                throw DecodingError.dataCorrupted(DecodingError.Context(
//                    codingPath: [], 
//                    debugDescription: "Invalid data"
//                ))
//            }
//            
//            // 使用 yyjson 解析 JSON
//            let doc = yyjson_read(baseAddress, bytes.count, 0)
//            guard let document = doc else {
//                throw DecodingError.dataCorrupted(DecodingError.Context(
//                    codingPath: [], 
//                    debugDescription: "Invalid JSON data"
//                ))
//            }
//            
//            defer {
//                yyjson_doc_free(document)
//            }
//            
//            let root = yyjson_doc_get_root(document)
//            guard let rootValue = root else {
//                throw DecodingError.dataCorrupted(DecodingError.Context(
//                    codingPath: [], 
//                    debugDescription: "No root value in JSON"
//                ))
//            }
//            
//            // 创建内部解码器
//            let decoder = _ReerJSONDecoder(
//                value: rootValue.pointee,
//                containers: JSONDecodingStorage(),
//                keyDecodingStrategy: keyDecodingStrategy,
//                dataDecodingStrategy: dataDecodingStrategy,
//                dateDecodingStrategy: dateDecodingStrategy,
//                nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy,
//                userInfo: userInfo
//            )
//            
//            return try decoder.unbox(rootValue.pointee, as: type)
//        }
//    }
//    
//    // MARK: - Private Methods
//    
//    private func decodeWithAppleDecoder<T: Decodable>(_ type: T.Type, from data: Data, reason: String?) throws -> T {
//        let appleDecoder = Foundation.JSONDecoder()
//        appleDecoder.dataDecodingStrategy = ReerJSONDecoder.convertDataDecodingStrategy(dataDecodingStrategy)
//        appleDecoder.dateDecodingStrategy = ReerJSONDecoder.convertDateDecodingStrategy(dateDecodingStrategy)
//        appleDecoder.keyDecodingStrategy = ReerJSONDecoder.convertKeyDecodingStrategy(keyDecodingStrategy)
//        appleDecoder.nonConformingFloatDecodingStrategy = ReerJSONDecoder.convertNonConformingFloatDecodingStrategy(nonConformingFloatDecodingStrategy)
//        appleDecoder.userInfo = userInfo
//        
//        if !ReerJSONDecoder.suppressWarnings {
//            print("[ReerJSONDecoder] Warning: fell back to using Apple's JSONDecoder. Reason: \(reason ?? ""). This message will only be printed the first time this happens. To suppress this message entirely, use `ReerJSONDecoder.suppressWarnings = true`")
//            ReerJSONDecoder.suppressWarnings = true
//        }
//        
//        return try appleDecoder.decode(type, from: data)
//    }
//    
//    private var convertCase: Bool {
//        switch keyDecodingStrategy {
//        case .convertFromSnakeCase:
//            return true
//        default:
//            return false
//        }
//    }
//}
//
//// MARK: - _ReerJSONDecoder
//
//final class _ReerJSONDecoder {
//    let value: yyjson_val
//    let containers: JSONDecodingStorage
//    let keyDecodingStrategy: ReerJSONDecoder.KeyDecodingStrategy
//    let dataDecodingStrategy: ReerJSONDecoder.DataDecodingStrategy
//    let dateDecodingStrategy: ReerJSONDecoder.DateDecodingStrategy
//    let nonConformingFloatDecodingStrategy: ReerJSONDecoder.NonConformingFloatDecodingStrategy
//    let userInfo: [CodingUserInfoKey: Any]
//    
//    init(value: yyjson_val, 
//         containers: JSONDecodingStorage,
//         keyDecodingStrategy: ReerJSONDecoder.KeyDecodingStrategy,
//         dataDecodingStrategy: ReerJSONDecoder.DataDecodingStrategy,
//         dateDecodingStrategy: ReerJSONDecoder.DateDecodingStrategy,
//         nonConformingFloatDecodingStrategy: ReerJSONDecoder.NonConformingFloatDecodingStrategy,
//         userInfo: [CodingUserInfoKey: Any]) {
//        self.value = value
//        self.containers = containers
//        self.keyDecodingStrategy = keyDecodingStrategy
//        self.dataDecodingStrategy = dataDecodingStrategy
//        self.dateDecodingStrategy = dateDecodingStrategy
//        self.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
//        self.userInfo = userInfo
//    }
//    
//    func unbox<T: Decodable>(_ value: yyjson_val, as type: T.Type) throws -> T {
//        containers.push(container: value)
//        defer { containers.popContainer() }
//        
//        if type == Bool.self {
//            return try unboxBool(value) as! T
//        } else if type == Int.self {
//            return try unboxInt(value) as! T
//        } else if type == Int8.self {
//            return try unboxInt8(value) as! T
//        } else if type == Int16.self {
//            return try unboxInt16(value) as! T
//        } else if type == Int32.self {
//            return try unboxInt32(value) as! T
//        } else if type == Int64.self {
//            return try unboxInt64(value) as! T
//        } else if type == UInt.self {
//            return try unboxUInt(value) as! T
//        } else if type == UInt8.self {
//            return try unboxUInt8(value) as! T
//        } else if type == UInt16.self {
//            return try unboxUInt16(value) as! T
//        } else if type == UInt32.self {
//            return try unboxUInt32(value) as! T
//        } else if type == UInt64.self {
//            return try unboxUInt64(value) as! T
//        } else if type == Float.self {
//            return try unboxFloat(value) as! T
//        } else if type == Double.self {
//            return try unboxDouble(value) as! T
//        } else if type == String.self {
//            return try unboxString(value) as! T
//        } else if type == Data.self {
//            return try unboxData(value) as! T
//        } else if type == Date.self {
//            return try unboxDate(value) as! T
//        } else {
//            // 对于复杂类型，创建一个新的解码器
//            let decoder = JSONDecoderImpl(
//                value: value,
//                containers: containers,
//                keyDecodingStrategy: keyDecodingStrategy,
//                dataDecodingStrategy: dataDecodingStrategy,
//                dateDecodingStrategy: dateDecodingStrategy,
//                nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy,
//                userInfo: userInfo
//            )
//            
//            return try type.init(from: decoder)
//        }
//    }
//    
//    // MARK: - Unboxing Methods
//    
//    private func unboxBool(_ value: yyjson_val) throws -> Bool {
//        var mutableValue = value
//        if yyjson_is_bool(&mutableValue) {
//            return yyjson_get_bool(&mutableValue)
//        }
//        throw DecodingError.typeMismatch(Bool.self, DecodingError.Context(
//            codingPath: [], 
//            debugDescription: "Expected Bool value"
//        ))
//    }
//    
//    private func unboxInt(_ value: yyjson_val) throws -> Int {
//        var mutableValue = value
//        if yyjson_is_int(&mutableValue) {
//            return Int(yyjson_get_int(&mutableValue))
//        }
//        throw DecodingError.typeMismatch(Int.self, DecodingError.Context(
//            codingPath: [], 
//            debugDescription: "Expected Int value"
//        ))
//    }
//    
//    private func unboxInt8(_ value: yyjson_val) throws -> Int8 {
//        var mutableValue = value
//        if yyjson_is_int(&mutableValue) {
//            let intValue = yyjson_get_int(&mutableValue)
//            guard intValue >= Int64(Int8.min) && intValue <= Int64(Int8.max) else {
//                throw DecodingError.dataCorrupted(DecodingError.Context(
//                    codingPath: [], 
//                    debugDescription: "Value out of range for Int8"
//                ))
//            }
//            return Int8(intValue)
//        }
//        throw DecodingError.typeMismatch(Int8.self, DecodingError.Context(
//            codingPath: [], 
//            debugDescription: "Expected Int8 value"
//        ))
//    }
//    
//    private func unboxInt16(_ value: yyjson_val) throws -> Int16 {
//        var mutableValue = value
//        if yyjson_is_int(&mutableValue) {
//            let intValue = yyjson_get_int(&mutableValue)
//            guard intValue >= Int64(Int16.min) && intValue <= Int64(Int16.max) else {
//                throw DecodingError.dataCorrupted(DecodingError.Context(
//                    codingPath: [], 
//                    debugDescription: "Value out of range for Int16"
//                ))
//            }
//            return Int16(intValue)
//        }
//        throw DecodingError.typeMismatch(Int16.self, DecodingError.Context(
//            codingPath: [], 
//            debugDescription: "Expected Int16 value"
//        ))
//    }
//    
//    private func unboxInt32(_ value: yyjson_val) throws -> Int32 {
//        var mutableValue = value
//        if yyjson_is_int(&mutableValue) {
//            let intValue = yyjson_get_int(&mutableValue)
//            guard intValue >= Int64(Int32.min) && intValue <= Int64(Int32.max) else {
//                throw DecodingError.dataCorrupted(DecodingError.Context(
//                    codingPath: [], 
//                    debugDescription: "Value out of range for Int32"
//                ))
//            }
//            return Int32(intValue)
//        }
//        throw DecodingError.typeMismatch(Int32.self, DecodingError.Context(
//            codingPath: [], 
//            debugDescription: "Expected Int32 value"
//        ))
//    }
//    
//    private func unboxInt64(_ value: yyjson_val) throws -> Int64 {
//        var mutableValue = value
//        if yyjson_is_int(&mutableValue) {
//            return Int64(yyjson_get_int(&mutableValue))
//        }
//        throw DecodingError.typeMismatch(Int64.self, DecodingError.Context(
//            codingPath: [], 
//            debugDescription: "Expected Int64 value"
//        ))
//    }
//    
//    private func unboxUInt(_ value: yyjson_val) throws -> UInt {
//        var mutableValue = value
//        if yyjson_is_uint(&mutableValue) {
//            return UInt(yyjson_get_uint(&mutableValue))
//        }
//        throw DecodingError.typeMismatch(UInt.self, DecodingError.Context(
//            codingPath: [], 
//            debugDescription: "Expected UInt value"
//        ))
//    }
//    
//    private func unboxUInt8(_ value: yyjson_val) throws -> UInt8 {
//        var mutableValue = value
//        if yyjson_is_uint(&mutableValue) {
//            let uintValue = yyjson_get_uint(&mutableValue)
//            guard uintValue <= UInt64(UInt8.max) else {
//                throw DecodingError.dataCorrupted(DecodingError.Context(
//                    codingPath: [], 
//                    debugDescription: "Value out of range for UInt8"
//                ))
//            }
//            return UInt8(uintValue)
//        }
//        throw DecodingError.typeMismatch(UInt8.self, DecodingError.Context(
//            codingPath: [], 
//            debugDescription: "Expected UInt8 value"
//        ))
//    }
//    
//    private func unboxUInt16(_ value: yyjson_val) throws -> UInt16 {
//        var mutableValue = value
//        if yyjson_is_uint(&mutableValue) {
//            let uintValue = yyjson_get_uint(&mutableValue)
//            guard uintValue <= UInt64(UInt16.max) else {
//                throw DecodingError.dataCorrupted(DecodingError.Context(
//                    codingPath: [], 
//                    debugDescription: "Value out of range for UInt16"
//                ))
//            }
//            return UInt16(uintValue)
//        }
//        throw DecodingError.typeMismatch(UInt16.self, DecodingError.Context(
//            codingPath: [], 
//            debugDescription: "Expected UInt16 value"
//        ))
//    }
//    
//    private func unboxUInt32(_ value: yyjson_val) throws -> UInt32 {
//        var mutableValue = value
//        if yyjson_is_uint(&mutableValue) {
//            let uintValue = yyjson_get_uint(&mutableValue)
//            guard uintValue <= UInt64(UInt32.max) else {
//                throw DecodingError.dataCorrupted(DecodingError.Context(
//                    codingPath: [], 
//                    debugDescription: "Value out of range for UInt32"
//                ))
//            }
//            return UInt32(uintValue)
//        }
//        throw DecodingError.typeMismatch(UInt32.self, DecodingError.Context(
//            codingPath: [], 
//            debugDescription: "Expected UInt32 value"
//        ))
//    }
//    
//    private func unboxUInt64(_ value: yyjson_val) throws -> UInt64 {
//        var mutableValue = value
//        if yyjson_is_uint(&mutableValue) {
//            return yyjson_get_uint(&mutableValue)
//        }
//        throw DecodingError.typeMismatch(UInt64.self, DecodingError.Context(
//            codingPath: [], 
//            debugDescription: "Expected UInt64 value"
//        ))
//    }
//    
//    private func unboxFloat(_ value: yyjson_val) throws -> Float {
//        var mutableValue = value
//        if yyjson_is_real(&mutableValue) {
//            return Float(yyjson_get_real(&mutableValue))
//        }
//        throw DecodingError.typeMismatch(Float.self, DecodingError.Context(
//            codingPath: [], 
//            debugDescription: "Expected Float value"
//        ))
//    }
//    
//    private func unboxDouble(_ value: yyjson_val) throws -> Double {
//        var mutableValue = value
//        if yyjson_is_real(&mutableValue) {
//            return yyjson_get_real(&mutableValue)
//        }
//        throw DecodingError.typeMismatch(Double.self, DecodingError.Context(
//            codingPath: [], 
//            debugDescription: "Expected Double value"
//        ))
//    }
//    
//    private func unboxString(_ value: yyjson_val) throws -> String {
//        var mutableValue = value
//        if yyjson_is_str(&mutableValue) {
//            if let cString = yyjson_get_str(&mutableValue) {
//                return String(cString: cString)
//            }
//        }
//        throw DecodingError.typeMismatch(String.self, DecodingError.Context(
//            codingPath: [], 
//            debugDescription: "Expected String value"
//        ))
//    }
//    
//    private func unboxData(_ value: yyjson_val) throws -> Data {
//        let stringValue = try unboxString(value)
//        
//        switch dataDecodingStrategy {
//        case .base64:
//            guard let data = Data(base64Encoded: stringValue) else {
//                throw DecodingError.dataCorrupted(DecodingError.Context(
//                    codingPath: [], 
//                    debugDescription: "Invalid base64 data"
//                ))
//            }
//            return data
//        case .deferredToData:
//            return Data(stringValue.utf8)
//        case .custom(let converter):
//            let decoder = JSONDecoderImpl(
//                value: value,
//                containers: containers,
//                keyDecodingStrategy: keyDecodingStrategy,
//                dataDecodingStrategy: dataDecodingStrategy,
//                dateDecodingStrategy: dateDecodingStrategy,
//                nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy,
//                userInfo: userInfo
//            )
//            return try converter(decoder)
//        }
//    }
//    
//    private func unboxDate(_ value: yyjson_val) throws -> Date {
//        switch dateDecodingStrategy {
//        case .deferredToDate:
//            let decoder = JSONDecoderImpl(
//                value: value,
//                containers: containers,
//                keyDecodingStrategy: keyDecodingStrategy,
//                dataDecodingStrategy: dataDecodingStrategy,
//                dateDecodingStrategy: dateDecodingStrategy,
//                nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy,
//                userInfo: userInfo
//            )
//            return try Date(from: decoder)
//        case .secondsSince1970:
//            let doubleValue = try unboxDouble(value)
//            return Date(timeIntervalSince1970: doubleValue)
//        case .millisecondsSince1970:
//            let doubleValue = try unboxDouble(value)
//            return Date(timeIntervalSince1970: doubleValue / 1000.0)
//        #if !os(Linux)
//        case .iso8601:
//            let stringValue = try unboxString(value)
//            guard let date = _iso8601Formatter.date(from: stringValue) else {
//                throw DecodingError.dataCorrupted(DecodingError.Context(
//                    codingPath: [], 
//                    debugDescription: "Invalid ISO8601 date format"
//                ))
//            }
//            return date
//        #endif
//        case .formatted(let formatter):
//            let stringValue = try unboxString(value)
//            guard let date = formatter.date(from: stringValue) else {
//                throw DecodingError.dataCorrupted(DecodingError.Context(
//                    codingPath: [], 
//                    debugDescription: "Invalid date format"
//                ))
//            }
//            return date
//        case .custom(let converter):
//            let decoder = JSONDecoderImpl(
//                value: value,
//                containers: containers,
//                keyDecodingStrategy: keyDecodingStrategy,
//                dataDecodingStrategy: dataDecodingStrategy,
//                dateDecodingStrategy: dateDecodingStrategy,
//                nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy,
//                userInfo: userInfo
//            )
//            return try converter(decoder)
//        }
//    }
//}
//
//// MARK: - ISO8601 Date Formatter
//
//#if !os(Linux)
//@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
//fileprivate var _iso8601Formatter: JJLISO8601DateFormatter = {
//    let formatter = JJLISO8601DateFormatter()
//    formatter.formatOptions = .withInternetDateTime
//    return formatter
//}()
//#endif
//
//// MARK: - Strategy Enums
//
//extension ReerJSONDecoder {
//    
//    public enum NonConformingFloatDecodingStrategy {
//        case `throw`
//        case convertFromString(positiveInfinity: String, negativeInfinity: String, nan: String)
//    }
//    
//    public enum DataDecodingStrategy {
//        case deferredToData
//        case base64
//        case custom((Decoder) throws -> Data)
//    }
//    
//    public enum KeyDecodingStrategy {
//        case useDefaultKeys
//        case convertFromSnakeCase
//        case custom(([CodingKey]) -> CodingKey)
//    }
//    
//    public enum DateDecodingStrategy {
//        case deferredToDate
//        case secondsSince1970
//        case millisecondsSince1970
//        #if !os(Linux)
//        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
//        case iso8601
//        #endif
//        case formatted(DateFormatter)
//        case custom((Decoder) throws -> Date)
//    }
//}
//
//// MARK: - Strategy Converters
//
//extension ReerJSONDecoder {
//    
//    static func convertNonConformingFloatDecodingStrategy(_ strategy: NonConformingFloatDecodingStrategy) -> Foundation.JSONDecoder.NonConformingFloatDecodingStrategy {
//        switch strategy {
//        case .convertFromString(let positiveInfinity, let negativeInfinity, let nan):
//            return .convertFromString(positiveInfinity: positiveInfinity, negativeInfinity: negativeInfinity, nan: nan)
//        case .throw:
//            return .throw
//        }
//    }
//    
//    static func convertDataDecodingStrategy(_ strategy: DataDecodingStrategy) -> Foundation.JSONDecoder.DataDecodingStrategy {
//        switch strategy {
//        case .base64:
//            return .base64
//        case .custom(let converter):
//            return .custom(converter)
//        case .deferredToData:
//            return .deferredToData
//        }
//    }
//    
//    static func convertKeyDecodingStrategy(_ strategy: KeyDecodingStrategy) -> Foundation.JSONDecoder.KeyDecodingStrategy {
//        switch strategy {
//        case .convertFromSnakeCase:
//            return .convertFromSnakeCase
//        case .useDefaultKeys:
//            return .useDefaultKeys
//        case .custom(let converter):
//            return .custom(converter)
//        }
//    }
//    
//    static func convertDateDecodingStrategy(_ strategy: DateDecodingStrategy) -> Foundation.JSONDecoder.DateDecodingStrategy {
//        switch strategy {
//        case .custom(let converter):
//            return .custom(converter)
//        case .deferredToDate:
//            return .deferredToDate
//        #if !os(Linux)
//        case .iso8601:
//            if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
//                return .iso8601
//            } else {
//                fatalError("ISO8601 date formatter is unavailable on this platform.")
//            }
//        #endif
//        case .millisecondsSince1970:
//            return .millisecondsSince1970
//        case .secondsSince1970:
//            return .secondsSince1970
//        case .formatted(let formatter):
//            return .formatted(formatter)
//        }
//    }
//}
