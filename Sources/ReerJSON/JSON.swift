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
    
    @inline(__always)
    var type: YYJSONType {
        return YYJSONType(rawValue: yyjson_get_type(pointer)) ?? .none
    }
}

extension JSON {
    
    @inline(__always)
    var isNull: Bool {
        return yyjson_is_null(pointer)
    }
    
    @inline(__always)
    var bool: Bool? {
        return yyjson_is_bool(pointer) ? unsafe_yyjson_get_bool(pointer) : nil
    }
    
    @inline(__always)
    var string: String? {
        guard let cString = yyjson_get_str(pointer) else { return nil }
        return String(cString: cString)
    }
    
    @inline(__always)
    var isNumber: Bool {
        guard let cString = yyjson_get_raw(pointer) else { return false }
        var convertedVal = yyjson_val()
        var error = yyjson_read_err()
        guard let _ = yyjson_read_number(cString, &convertedVal, 0, nil, &error) else {
            return false
        }
        return yyjson_is_num(&convertedVal)
    }
    
    @inline(__always)
    var number: Double? {
        guard let cString = yyjson_get_raw(pointer) else { return nil }
        var convertedVal = yyjson_val()
        var error = yyjson_read_err()
        guard let _ = yyjson_read_number(cString, &convertedVal, 0, nil, &error),
              yyjson_is_num(&convertedVal) else {
            return nil
        }
        return yyjson_get_num(&convertedVal)
    }
    
    @inline(__always)
    var numberValue: Double {
        guard let cString = yyjson_get_raw(pointer) else { return 0 }
        var convertedVal = yyjson_val()
        var error = yyjson_read_err()
        guard let _ = yyjson_read_number(cString, &convertedVal, 0, nil, &error),
              yyjson_is_num(&convertedVal) else {
            return 0
        }
        return yyjson_get_num(&convertedVal)
    }
    
    @inline(__always)
    var isObject: Bool {
        return yyjson_is_obj(pointer)
    }
    
    @inline(__always)
    func integer<T: FixedWidthInteger>() -> T? {
        guard let cString = yyjson_get_raw(pointer) else { return nil }
        var convertedVal = yyjson_val()
        var error = yyjson_read_err()
        guard let _ = yyjson_read_number(cString, &convertedVal, 0, nil, &error) else {
            return nil
        }
        if yyjson_is_uint(&convertedVal) {
            return T(exactly: yyjson_get_uint(&convertedVal))
        } else if yyjson_is_sint(&convertedVal) {
            return T(exactly: yyjson_get_sint(&convertedVal))
        } else if yyjson_is_real(&convertedVal) {
            return T(exactly: unsafe_yyjson_get_real(&convertedVal))
        }
        return nil
    }
    
    var rawString: String? {
        guard let cString = yyjson_get_raw(pointer) else { return nil }
        return String(cString: cString)
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
