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
    
    @inline(__always)
    var type: YYJSONType {
        return YYJSONType(rawValue: yyjson_get_type(pointer)) ?? .none
    }
    
    @inline(__always)
    var subtype: YYJSONSubtype {
        return YYJSONSubtype(rawValue: yyjson_get_subtype(pointer))
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
    var double: Double? {
        return yyjson_is_num(pointer) ? yyjson_get_num(pointer) : nil
    }
    
    @inline(__always)
    var isNumber: Bool {
        return yyjson_is_num(pointer)
    }
    
    @inline(__always)
    var numberValue: Double {
        return yyjson_get_num(pointer)
    }
    
    @inline(__always)
    var isSignedInteger: Bool {
        return yyjson_is_sint(pointer)
    }
    
    @inline(__always)
    var signedIntegerValue: Int64 {
        return yyjson_get_sint(pointer)
    }
    
    @inline(__always)
    var isUnsignedInteger: Bool {
        return yyjson_is_uint(pointer)
    }
    
    @inline(__always)
    var unsignedIntegerValue: UInt64 {
        return yyjson_get_uint(pointer)
    }
    
    @inline(__always)
    var realValue: Double {
        return yyjson_get_real(pointer)
    }
    
    @inline(__always)
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
    
    var rawString: String? {
        if yyjson_is_raw(pointer) {
            print("~~~~ israw")
        }
        guard let cString = yyjson_get_raw(pointer) else { return nil }
//        yyjson_read_number(cString, pointer, 0, <#T##alc: UnsafePointer<yyjson_alc>!##UnsafePointer<yyjson_alc>!#>, <#T##err: UnsafeMutablePointer<yyjson_read_err>!##UnsafeMutablePointer<yyjson_read_err>!#>)
        
        
        // 创建转换后的值容器
            var convertedVal = yyjson_val()
            var error = yyjson_read_err()
            
            // 调用转换函数
            let result = yyjson_read_number(cString, &convertedVal, 0, nil, &error)
            
            if result != nil {
                // 转换成功，检查数字类型
                if yyjson_is_uint(&convertedVal) {
                    let number = yyjson_get_uint(&convertedVal)
                    print("Unsigned integer: \(number)")
                } else if yyjson_is_sint(&convertedVal) {
                    let number = yyjson_get_sint(&convertedVal)
                    print("Signed integer: \(number)")
                } else if yyjson_is_real(&convertedVal) {
                    let number = yyjson_get_real(&convertedVal)
                    print("Real number: \(number)")
                }
            } else {
                // 转换失败
                if let errorMsg = error.msg {
                    let errorString = String(cString: errorMsg)
                    print("Conversion failed: \(errorString)")
                }
            }
        
        
//        let val = UnsafeMutablePointer<yyjson_val>.allocate(capacity: 1)
//        defer { val.deallocate() }
        
        // 可选：设置错误处理
//        var err = yyjson_read_err()
//        
//        // 调用 yyjson_read_number
//        if let result = yyjson_read_number(
//            cString,                    // const char *dat (null-terminated)
//            val,                       // yyjson_val *val (输出)
//            YYJSON_READ_NUMBER_AS_RAW, // yyjson_read_flag flg
//            nil,                       // const yyjson_alc *alc (使用默认分配器)
//            &err                       // yyjson_read_err *err
//        ) {
//            let ss = String(cString: cString)
//            let num = yyjson_get_num(val)
//            print(num)
//        }
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
