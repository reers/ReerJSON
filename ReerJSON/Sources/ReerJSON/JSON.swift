//
//  JSON.swift
//  ReerJSON
//
//  Created by phoenix on 2025/7/17.
//

import yyjson

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

struct JSON {
    let pointer: UnsafeMutablePointer<yyjson_val>?
    
    init(pointer: UnsafeMutablePointer<yyjson_val>?) {
        self.pointer = pointer
    }
    
    subscript(key: String) -> Self {
        return .init(pointer: yyjson_obj_get(pointer, key))
    }

    subscript(index: Int) -> Self {
        return .init(pointer: yyjson_arr_get(pointer, index))
    }
}

extension JSON {
    var type: YYJSONType {
        return YYJSONType(rawValue: yyjson_get_type(pointer)) ?? .none
    }
    
    var subtype: YYJSONSubtype {
        return YYJSONSubtype(rawValue: yyjson_get_subtype(pointer))
    }
}

extension JSON {
    var isNull: Bool {
        return yyjson_is_null(pointer)
    }
    
    var bool: Bool? {
        return yyjson_is_bool(pointer) ? unsafe_yyjson_get_bool(pointer) : nil
    }
    
    var string: String? {
        guard let cString = yyjson_get_str(pointer) else { return nil }
        return String(cString: cString)
    }
    
    var double: Double? {
        return yyjson_is_num(pointer) ? yyjson_get_num(pointer) : nil
    }
    
    var isNumber: Bool {
        return yyjson_is_num(pointer)
    }
    
    var numberValue: Double {
        return yyjson_get_num(pointer)
    }
    
    var isSignedInteger: Bool {
        return yyjson_is_sint(pointer)
    }
    
    var signedIntegerValue: Int64 {
        return yyjson_get_sint(pointer)
    }
    
    var isUnsignedInteger: Bool {
        return yyjson_is_uint(pointer)
    }
    
    var unsignedIntegerValue: UInt64 {
        return yyjson_get_uint(pointer)
    }
    
    var realValue: Double {
        return yyjson_get_real(pointer)
    }
    
    var isObject: Bool {
        return yyjson_is_obj(pointer)
    }
    
    @inline(__always)
    func integer<T: FixedWidthInteger>() -> T? {
        if isUnsignedInteger {
            return T(exactly: unsignedIntegerValue)
        }
        if isSignedInteger {
            return T(exactly: signedIntegerValue)
        }
        if let double = double {
            return T(exactly: double)
        }
        return nil
    }
}

extension JSON {
    var debugDataTypeDescription : String {
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
