//
//  JSON.swift
//  ReerJSON
//
//  Created by phoenix on 2025/7/17.
//

import yyjson

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
}
