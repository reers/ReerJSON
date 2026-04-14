//
//  Adapted from swift-yyjson by Mattt (https://github.com/mattt/swift-yyjson)
//  Original code copyright 2026 Mattt (https://mat.tt), licensed under MIT License.
//
//  Modifications for ReerJSON:
//  - Renamed types: removed "YY" prefix (YYJSONValue → JSONValue, etc.)
//  - YYJSONSerialization → ReerJSONSerialization
//  - Changed `import Cyyjson` to `import yyjson`
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
//

import yyjson

// MARK: - Helper Functions

@inline(__always)
func yyObjGet(_ obj: UnsafeMutablePointer<yyjson_val>, key: String) -> UnsafeMutablePointer<yyjson_val>? {
    var tmp = key
    return tmp.withUTF8 { buf in
        guard let ptr = buf.baseAddress else { return nil }
        return yyjson_obj_getn(obj, ptr, buf.count)
    }
}

@inline(__always)
func yyFromString(_ string: String, in doc: UnsafeMutablePointer<yyjson_mut_doc>) -> UnsafeMutablePointer<
    yyjson_mut_val
> {
    var tmp = string
    return tmp.withUTF8 { buf in
        if let ptr = buf.baseAddress {
            return yyjson_mut_strncpy(doc, ptr, buf.count)
        }
        return yyjson_mut_strn(doc, "", 0)
    }
}

#if !YYJSON_DISABLE_WRITER

    /// Recursively sort object keys in-place using UTF-8 lexicographical comparison (strcmp).
    /// This matches Apple's JSONEncoder behavior for typical keys, but embedded null bytes
    /// may compare differently due to C string semantics.
    ///
    /// - Note: Uses direct C string comparison via `strcmp` for optimal performance,
    ///   avoiding Swift String allocations during sorting.
    func sortObjectKeys(_ val: UnsafeMutablePointer<yyjson_mut_val>) throws {
        typealias MutVal = UnsafeMutablePointer<yyjson_mut_val>

        if yyjson_mut_is_obj(val) {
            var pairs: [(keyVal: MutVal, val: MutVal, keyStr: UnsafePointer<CChar>)] = []
            pairs.reserveCapacity(Int(yyjson_mut_obj_size(val)))

            var iter = yyjson_mut_obj_iter()
            guard yyjson_mut_obj_iter_init(val, &iter) else {
                throw JSONError.invalidData("Failed to initialize object iterator during key sorting")
            }

            while let keyPtr = yyjson_mut_obj_iter_next(&iter) {
                guard let valPtr = yyjson_mut_obj_iter_get_val(keyPtr) else {
                    throw JSONError.invalidData("Object key has no associated value during key sorting")
                }
                guard let keyStr = yyjson_mut_get_str(keyPtr) else {
                    throw JSONError.invalidData("Object key is not a string during key sorting")
                }
                pairs.append((keyPtr, valPtr, keyStr))
            }

            pairs.sort { pair1, pair2 in
                return strcmp(pair1.keyStr, pair2.keyStr) < 0
            }

            guard yyjson_mut_obj_clear(val) else {
                throw JSONError.invalidData("Failed to clear object during key sorting")
            }

            for pair in pairs {
                try sortObjectKeys(pair.val)
                guard yyjson_mut_obj_add(val, pair.keyVal, pair.val) else {
                    throw JSONError.invalidData("Failed to add key back to object during key sorting")
                }
            }
        } else if yyjson_mut_is_arr(val) {
            var iter = yyjson_mut_arr_iter()
            guard yyjson_mut_arr_iter_init(val, &iter) else {
                throw JSONError.invalidData("Failed to initialize array iterator during key sorting")
            }
            while let elem = yyjson_mut_arr_iter_next(&iter) {
                try sortObjectKeys(elem)
            }
        }
    }
#endif  // !YYJSON_DISABLE_WRITER
