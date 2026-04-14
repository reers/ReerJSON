//
//  Copyright © 2026 Mattt (https://github.com/mattt)
//  Copyright © 2026 reers.
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
import Foundation

/// Errors that can occur when parsing, decoding, or encoding JSON.
public struct JSONError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The kind of error that occurred.
    public enum Kind: Equatable, Sendable {
        /// The JSON data was malformed.
        case invalidJSON
        /// The value was not of the expected type.
        case typeMismatch(expected: String, actual: String)
        /// A required key was not found.
        case missingKey(String)
        /// A required value was null or missing.
        case missingValue
        /// The data is corrupted or invalid.
        case invalidData
        /// An error occurred while writing JSON.
        case writeError
    }

    /// The kind of error.
    public let kind: Kind

    /// A detailed message describing the error.
    public let message: String

    /// The coding path where the error occurred (for decoding errors).
    public let path: String

    public var description: String {
        if path.isEmpty {
            return message
        }
        return "\(message) (at \(path))"
    }

    private init(kind: Kind, message: String, path: String = "") {
        self.kind = kind
        self.message = message
        self.path = path
    }

    // MARK: - Public Factory Methods

    /// Create an invalid JSON error.
    public static func invalidJSON(_ message: String) -> JSONError {
        JSONError(kind: .invalidJSON, message: message)
    }

    /// Create a type mismatch error.
    public static func typeMismatch(expected: String, actual: String, path: String = "") -> JSONError {
        JSONError(
            kind: .typeMismatch(expected: expected, actual: actual),
            message: "Expected \(expected), got \(actual)",
            path: path
        )
    }

    /// Create a missing key error.
    public static func missingKey(_ key: String, path: String = "") -> JSONError {
        JSONError(
            kind: .missingKey(key),
            message: "Missing key '\(key)'",
            path: path
        )
    }

    /// Create a missing value error.
    public static func missingValue(path: String = "") -> JSONError {
        JSONError(
            kind: .missingValue,
            message: "Value is null or missing",
            path: path
        )
    }

    /// Create an invalid data error.
    public static func invalidData(_ message: String, path: String = "") -> JSONError {
        JSONError(kind: .invalidData, message: message, path: path)
    }

    /// Create a write error.
    public static func writeError(_ message: String) -> JSONError {
        JSONError(kind: .writeError, message: message)
    }

    // MARK: - Internal Initializers

    /// Create an error from a yyjson read error.
    internal init(parsing error: yyjson_read_err) {
        let detail = error.msg.map { String(cString: $0) }
        let message: String
        switch error.code {
        case YYJSON_READ_ERROR_INVALID_PARAMETER:
            message = detail ?? "Invalid parameter"
        case YYJSON_READ_ERROR_MEMORY_ALLOCATION:
            message = detail ?? "Memory allocation failed"
        case YYJSON_READ_ERROR_EMPTY_CONTENT:
            message = detail ?? "Empty content"
        case YYJSON_READ_ERROR_UNEXPECTED_CONTENT:
            message = detail ?? "Unexpected content"
        case YYJSON_READ_ERROR_UNEXPECTED_END:
            message = detail ?? "Unexpected end of input"
        case YYJSON_READ_ERROR_UNEXPECTED_CHARACTER:
            message = detail ?? "Unexpected character at position \(error.pos)"
        case YYJSON_READ_ERROR_JSON_STRUCTURE:
            message = detail ?? "Invalid JSON structure"
        case YYJSON_READ_ERROR_INVALID_COMMENT:
            message = detail ?? "Invalid comment"
        case YYJSON_READ_ERROR_INVALID_NUMBER:
            message = detail ?? "Invalid number"
        case YYJSON_READ_ERROR_INVALID_STRING:
            message = detail ?? "Invalid string"
        case YYJSON_READ_ERROR_LITERAL:
            message = detail ?? "Invalid literal"
        default:
            message = detail ?? "Unknown read error (code: \(error.code))"
        }

        self.kind = .invalidJSON
        self.message = message
        self.path = ""
    }

    /// Create an error from a yyjson write error.
    internal init(writing error: yyjson_write_err) {
        let detail = error.msg.map { String(cString: $0) }
        let message: String
        switch error.code {
        case YYJSON_WRITE_ERROR_INVALID_PARAMETER:
            message = detail ?? "Invalid parameter"
        case YYJSON_WRITE_ERROR_MEMORY_ALLOCATION:
            message = detail ?? "Memory allocation failed"
        case YYJSON_WRITE_ERROR_INVALID_VALUE_TYPE:
            message = detail ?? "Invalid value type"
        case YYJSON_WRITE_ERROR_NAN_OR_INF:
            message = detail ?? "NaN or Infinity not allowed in JSON"
        case YYJSON_WRITE_ERROR_INVALID_STRING:
            message = detail ?? "Invalid string"
        default:
            message = detail ?? "Unknown write error (code: \(error.code))"
        }

        self.kind = .writeError
        self.message = message
        self.path = ""
    }
}
