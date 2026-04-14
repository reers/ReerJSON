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
import Foundation

/// Options for reading JSON data.
public struct JSONReadOptions: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Default option (RFC 8259 compliant).
    public static let `default` = JSONReadOptions([])

    /// Stops when done instead of issuing an error if there's additional content
    /// after a JSON document.
    public static let stopWhenDone = JSONReadOptions(rawValue: YYJSON_READ_STOP_WHEN_DONE)

    /// Read all numbers as raw strings.
    public static let numberAsRaw = JSONReadOptions(rawValue: YYJSON_READ_NUMBER_AS_RAW)

    /// Allow reading invalid unicode when parsing string values.
    public static let allowInvalidUnicode = JSONReadOptions(rawValue: YYJSON_READ_ALLOW_INVALID_UNICODE)

    /// Read big numbers as raw strings.
    public static let bigNumberAsRaw = JSONReadOptions(rawValue: YYJSON_READ_BIGNUM_AS_RAW)

    #if !YYJSON_DISABLE_NON_STANDARD

        /// Allow single trailing comma at the end of an object or array.
        public static let allowTrailingCommas = JSONReadOptions(rawValue: YYJSON_READ_ALLOW_TRAILING_COMMAS)

        /// Allow C-style single-line and multi-line comments.
        public static let allowComments = JSONReadOptions(rawValue: YYJSON_READ_ALLOW_COMMENTS)

        /// Allow inf/nan number and literal, case-insensitive.
        public static let allowInfAndNaN = JSONReadOptions(rawValue: YYJSON_READ_ALLOW_INF_AND_NAN)

        /// Allow UTF-8 BOM and skip it before parsing.
        public static let allowBOM = JSONReadOptions(rawValue: YYJSON_READ_ALLOW_BOM)

        /// Allow extended number formats (hex, leading/trailing decimal point, leading plus).
        public static let allowExtendedNumbers = JSONReadOptions(rawValue: YYJSON_READ_ALLOW_EXT_NUMBER)

        /// Allow extended escape sequences in strings.
        public static let allowExtendedEscapes = JSONReadOptions(rawValue: YYJSON_READ_ALLOW_EXT_ESCAPE)

        /// Allow extended whitespace characters.
        public static let allowExtendedWhitespace = JSONReadOptions(rawValue: YYJSON_READ_ALLOW_EXT_WHITESPACE)

        /// Allow strings enclosed in single quotes.
        public static let allowSingleQuotedStrings = JSONReadOptions(rawValue: YYJSON_READ_ALLOW_SINGLE_QUOTED_STR)

        /// Allow object keys without quotes.
        public static let allowUnquotedKeys = JSONReadOptions(rawValue: YYJSON_READ_ALLOW_UNQUOTED_KEY)

        /// Allow JSON5 format.
        ///
        /// This includes trailing commas, comments, inf/nan, extended numbers,
        /// extended escapes, extended whitespace, single-quoted strings, and unquoted keys.
        public static let json5 = JSONReadOptions(rawValue: YYJSON_READ_JSON5)

    #endif  // !YYJSON_DISABLE_NON_STANDARD

    /// Convert to yyjson read flags.
    internal var yyjsonFlags: yyjson_read_flag {
        yyjson_read_flag(rawValue)
    }
}

/// Options for writing JSON data.
public struct JSONWriteOptions: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Default option (minified output).
    public static let `default` = JSONWriteOptions([])

    /// Write JSON pretty with 4 space indent.
    public static let prettyPrinted = JSONWriteOptions(rawValue: YYJSON_WRITE_PRETTY)

    /// Write JSON pretty with 2 space indent (implies `prettyPrinted`).
    public static let indentationTwoSpaces = JSONWriteOptions(rawValue: YYJSON_WRITE_PRETTY_TWO_SPACES)

    /// Escape unicode as `\uXXXX`, making the output ASCII only.
    public static let escapeUnicode = JSONWriteOptions(rawValue: YYJSON_WRITE_ESCAPE_UNICODE)

    /// Escape '/' as '\/'.
    public static let escapeSlashes = JSONWriteOptions(rawValue: YYJSON_WRITE_ESCAPE_SLASHES)

    #if !YYJSON_DISABLE_NON_STANDARD

        /// Writes infinity and NaN values as `Infinity` and `NaN` literals.
        ///
        /// If you set `infAndNaNAsNull`, it takes precedence.
        public static let allowInfAndNaN = JSONWriteOptions(rawValue: YYJSON_WRITE_ALLOW_INF_AND_NAN)

        /// Writes infinity and NaN values as `null` literals.
        ///
        /// This option takes precedence over `allowInfAndNaN`.
        public static let infAndNaNAsNull = JSONWriteOptions(rawValue: YYJSON_WRITE_INF_AND_NAN_AS_NULL)

    #endif  // !YYJSON_DISABLE_NON_STANDARD

    /// Allow invalid unicode when encoding string values.
    public static let allowInvalidUnicode = JSONWriteOptions(rawValue: YYJSON_WRITE_ALLOW_INVALID_UNICODE)

    /// Add a newline character at the end of the JSON.
    public static let newlineAtEnd = JSONWriteOptions(rawValue: YYJSON_WRITE_NEWLINE_AT_END)

    /// Sorts object keys lexicographically.
    public static let sortedKeys = JSONWriteOptions(rawValue: 1 << 16)

    // Mask for Swift-only flags (bits 16+) that should not be passed to yyjson C library
    private static let swiftOnlyFlagsMask: UInt32 = 0xFFFF_0000

    /// Convert to yyjson write flags, excluding Swift-only flags.
    internal var yyjsonFlags: yyjson_write_flag {
        // Only pass bits 0-15 to yyjson C library; bits 16+ are Swift-only flags
        yyjson_write_flag(rawValue & ~JSONWriteOptions.swiftOnlyFlagsMask)
    }
}
