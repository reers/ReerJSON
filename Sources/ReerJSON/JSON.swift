//
//  Copyright © 2025 reers.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

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
    var stringWhenJSON5: String? {
        guard let cString = yyjson_get_str(pointer) else { return nil }
        let length = yyjson_get_len(pointer)
        if memchr(cString, 0, length) != nil {
            return nil
        }
        return String(cString: cString)
    }
    
    @inline(__always)
    var string: String? {
        guard let cString = yyjson_get_str(pointer) else { return nil }
        let length = yyjson_get_len(pointer)
        if memchr(cString, 0, length) != nil {
            let rawBuffer = UnsafeRawBufferPointer(start: cString, count: length)
            return String(bytes: rawBuffer, encoding: .utf8)
        }
        return String(cString: cString)
    }
    
    @inline(__always)
    var isNumber: Bool {
        guard let cString = yyjson_get_raw(pointer) else { return false }
        var convertedVal = yyjson_val()
        var error = yyjson_read_err()
        guard let _ = yyjson_read_number(
            cString,
            &convertedVal,
            YYJSON_READ_ALLOW_EXT_NUMBER | YYJSON_READ_ALLOW_INF_AND_NAN,
            nil,
            &error
        ) else {
            return false
        }
        return yyjson_is_num(&convertedVal)
    }
    
    @inline(__always)
    var number: Double? {
        guard let cString = yyjson_get_raw(pointer) else { return nil }
        var convertedVal = yyjson_val()
        var error = yyjson_read_err()
        guard
            let _ = yyjson_read_number(
                cString,
                &convertedVal,
                YYJSON_READ_ALLOW_EXT_NUMBER | YYJSON_READ_ALLOW_INF_AND_NAN,
                nil,
                &error
            ),
            yyjson_is_num(&convertedVal)
        else {
            return nil
        }
        return yyjson_get_num(&convertedVal)
    }
    
    @inline(__always)
    var numberValue: Double {
        guard let cString = yyjson_get_raw(pointer) else { return 0 }
        var convertedVal = yyjson_val()
        var error = yyjson_read_err()
        guard
            let _ = yyjson_read_number(
                cString,
                &convertedVal,
                YYJSON_READ_ALLOW_EXT_NUMBER | YYJSON_READ_ALLOW_INF_AND_NAN,
                nil,
                &error
            ),
            yyjson_is_num(&convertedVal)
        else {
            return 0
        }
        return yyjson_get_num(&convertedVal)
    }
    
    @inline(__always)
    var isObject: Bool {
        return yyjson_is_obj(pointer)
    }
    
    @inline(__always)
    var isArray: Bool {
        return yyjson_is_arr(pointer)
    }
    
    @inline(__always)
    func integer<T: FixedWidthInteger>() -> T? {
        guard let cString = yyjson_get_raw(pointer) else { return nil }
        var convertedVal = yyjson_val()
        var error = yyjson_read_err()
        guard let _ = yyjson_read_number(cString, &convertedVal, YYJSON_READ_ALLOW_EXT_NUMBER, nil, &error) else {
            return nil
        }
        if yyjson_is_uint(&convertedVal) {
            return T(exactly: yyjson_get_uint(&convertedVal))
        } else if yyjson_is_sint(&convertedVal) {
            return T(exactly: yyjson_get_sint(&convertedVal))
        } else if yyjson_is_real(&convertedVal) {
            let real = unsafe_yyjson_get_real(&convertedVal)
            if let value = T(exactly: real) { return value }
            // try Int128/UInt128
            return T(String(cString: cString))
        }
        return nil
    }
    
    var rawString: String? {
        guard let cString = yyjson_get_raw(pointer) else { return nil }
        return String(cString: cString)
    }
}

extension JSON {
    var debugDataTypeDescription: String {
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
