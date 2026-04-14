//
//  Adapted from swift-yyjson by Mattt (https://github.com/mattt/swift-yyjson)
//  Original code copyright 2026 Mattt (https://mat.tt), licensed under MIT License.
//  Converted from Swift Testing to XCTest for ReerJSON.
//

import Foundation
import XCTest

@testable import ReerJSON

// MARK: - JSONObject Reading Tests

class SerializationReadingTests: XCTestCase {
    func testReadDictionary() throws {
        let json = #"{"name": "Alice", "age": 30}"#
        let data = json.data(using: .utf8)!
        let result = try ReerJSONSerialization.jsonObject(with: data) as? NSDictionary
        XCTAssertEqual(result?["name"] as? String, "Alice")
        XCTAssertEqual(result?["age"] as? Int, 30)
    }

    func testReadArray() throws {
        let json = "[1, 2, 3, 4, 5]"
        let data = json.data(using: .utf8)!
        let result = try ReerJSONSerialization.jsonObject(with: data) as? NSArray
        XCTAssertEqual(result?.count, 5)
        XCTAssertEqual(result?[0] as? Int, 1)
    }

    func testReadNestedStructure() throws {
        let json = """
            {
                "users": [
                    {"name": "Alice"},
                    {"name": "Bob"}
                ]
            }
            """
        let data = json.data(using: .utf8)!
        let result = try ReerJSONSerialization.jsonObject(with: data) as? NSDictionary
        let users = result?["users"] as? NSArray
        XCTAssertEqual(users?.count, 2)
        let alice = users?[0] as? NSDictionary
        XCTAssertEqual(alice?["name"] as? String, "Alice")
    }

    func testReadWithMutableContainers() throws {
        let json = #"{"key": "value"}"#
        let data = json.data(using: .utf8)!
        let result =
            try ReerJSONSerialization.jsonObject(
                with: data,
                options: .mutableContainers
            ) as? NSMutableDictionary
        XCTAssertNotNil(result)
        result?["newKey"] = "newValue"
        XCTAssertEqual(result?["newKey"] as? String, "newValue")
    }

    // Note: On Linux, swift-corelibs-foundation's NSDictionary returns values as NSString
    // even when NSMutableString was stored. The .mutableLeaves option still works correctly
    // (strings are mutable), but the type cast verification in this test fails.
    #if canImport(Darwin)
        func testReadWithMutableLeaves() throws {
            let json = #"{"key": "value"}"#
            let data = json.data(using: .utf8)!
            let result =
                try ReerJSONSerialization.jsonObject(
                    with: data,
                    options: .mutableLeaves
                ) as? NSDictionary
            let stringValue = result?["key"] as? NSMutableString
            XCTAssertNotNil(stringValue)
        }
    #endif

    func testReadFragmentString() throws {
        let json = #""hello world""#
        let data = json.data(using: .utf8)!
        let result = try ReerJSONSerialization.jsonObject(
            with: data,
            options: .fragmentsAllowed
        )
        XCTAssertEqual((result as? NSString), "hello world")
    }

    func testReadFragmentNumber() throws {
        let json = "42"
        let data = json.data(using: .utf8)!
        let result = try ReerJSONSerialization.jsonObject(
            with: data,
            options: .fragmentsAllowed
        )
        XCTAssertEqual((result as? NSNumber)?.intValue, 42)
    }

    func testReadFragmentBool() throws {
        let json = "true"
        let data = json.data(using: .utf8)!
        let result = try ReerJSONSerialization.jsonObject(
            with: data,
            options: .fragmentsAllowed
        )
        XCTAssertEqual((result as? NSNumber)?.boolValue, true)
    }

    func testReadFragmentNull() throws {
        let json = "null"
        let data = json.data(using: .utf8)!
        let result = try ReerJSONSerialization.jsonObject(
            with: data,
            options: .fragmentsAllowed
        )
        XCTAssertTrue(result is NSNull)
    }

    func testReadFragmentWithoutOption() throws {
        let json = #""just a string""#
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(
            try ReerJSONSerialization.jsonObject(with: data)
        )
    }

    #if !YYJSON_DISABLE_NON_STANDARD

        func testReadWithJSON5() throws {
            let json = #"{"key": "value",}"#
            let data = json.data(using: .utf8)!
            let result =
                try ReerJSONSerialization.jsonObject(
                    with: data,
                    options: .json5Allowed
                ) as? NSDictionary
            XCTAssertEqual(result?["key"] as? String, "value")
        }

    #endif  // !YYJSON_DISABLE_NON_STANDARD

    func testReadInvalidJSON() throws {
        let json = "not valid json"
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(
            try ReerJSONSerialization.jsonObject(with: data)
        )
    }
}

// MARK: - JSONObject Writing Tests

class SerializationWritingTests: XCTestCase {
    func testWriteDictionary() throws {
        let dict: NSDictionary = ["name": "Alice", "age": 30]
        let data = try ReerJSONSerialization.data(withJSONObject: dict)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("name"))
        XCTAssertTrue(json.contains("Alice"))
        XCTAssertTrue(json.contains("age"))
    }

    func testWriteArray() throws {
        let array: NSArray = [1, 2, 3, 4, 5]
        let data = try ReerJSONSerialization.data(withJSONObject: array)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertEqual(json, "[1,2,3,4,5]")
    }

    #if !YYJSON_DISABLE_NON_STANDARD

        func testWriteAllowsInfAndNaNLiterals() throws {
            let dict: NSDictionary = [
                "inf": Double.infinity,
                "nan": Double.nan,
            ]
            let data = try ReerJSONSerialization.data(
                withJSONObject: dict,
                options: .allowInfAndNaN
            )
            let json = String(data: data, encoding: .utf8)!
            XCTAssertTrue(json.contains("Infinity") || json.contains("inf"))
            XCTAssertTrue(json.contains("NaN") || json.contains("nan"))
        }

        func testWriteInfAndNaNAsNull() throws {
            let dict: NSDictionary = [
                "inf": Double.infinity,
                "nan": Double.nan,
            ]
            let data = try ReerJSONSerialization.data(
                withJSONObject: dict,
                options: .infAndNaNAsNull
            )
            let json = String(data: data, encoding: .utf8)!
            XCTAssertTrue(json.contains("\"inf\":null"))
            XCTAssertTrue(json.contains("\"nan\":null"))
        }

        func testWriteInfAndNaNAsNullOverridesAllowInfAndNaN() throws {
            let dict: NSDictionary = [
                "inf": Double.infinity,
                "nan": Double.nan,
            ]
            let data = try ReerJSONSerialization.data(
                withJSONObject: dict,
                options: [.allowInfAndNaN, .infAndNaNAsNull]
            )
            let json = String(data: data, encoding: .utf8)!
            XCTAssertTrue(json.contains("\"inf\":null"))
            XCTAssertTrue(json.contains("\"nan\":null"))
        }

        func testWriteNonFiniteWithoutOptionThrows() throws {
            let dict: NSDictionary = ["value": Double.nan]
            XCTAssertThrowsError(
                try ReerJSONSerialization.data(withJSONObject: dict)
            )
        }

    #endif  // !YYJSON_DISABLE_NON_STANDARD

    private static func jsonString(
        for object: Any,
        options: ReerJSONSerialization.WritingOptions = []
    ) throws -> String {
        let data = try ReerJSONSerialization.data(
            withJSONObject: object,
            options: options
        )
        return String(data: data, encoding: .utf8)!
    }

    func testWriteJSONValue() throws {
        let value = try JSONValue(string: #"{"name":"Alice","age":30}"#)
        let data = try ReerJSONSerialization.data(withJSONObject: value)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"name\""))
        XCTAssertTrue(json.contains("\"age\""))
    }

    func testWriteJSONObject() throws {
        let value = try JSONValue(string: #"{"name":"Alice"}"#)
        guard let object = value.object else {
            XCTFail("Expected object")
            return
        }
        let data = try ReerJSONSerialization.data(withJSONObject: object)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"name\""))
    }

    func testWriteJSONArray() throws {
        let value = try JSONValue(string: "[1,2,3]")
        guard let array = value.array else {
            XCTFail("Expected array")
            return
        }
        let data = try ReerJSONSerialization.data(withJSONObject: array)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertEqual(json, "[1,2,3]")
    }

    func testWriteJSONValueFragmentWithoutOption() throws {
        let value = try JSONValue(string: "true")
        XCTAssertThrowsError(
            try ReerJSONSerialization.data(withJSONObject: value)
        )
    }

    func testWriteJSONValueFragmentWithOption() throws {
        let value = try JSONValue(string: "true")
        let data = try ReerJSONSerialization.data(
            withJSONObject: value,
            options: .fragmentsAllowed
        )
        let json = String(data: data, encoding: .utf8)!
        XCTAssertEqual(json, "true")
    }

    func testWriteJSONValueSortedKeys() throws {
        let value = try JSONValue(string: #"{"z":1,"a":{"b":1,"a":2}}"#)
        let data = try ReerJSONSerialization.data(
            withJSONObject: value,
            options: .sortedKeys
        )
        let json = String(data: data, encoding: .utf8)!
        let outerA = json.range(of: "\"a\"")!.lowerBound
        let outerZ = json.range(of: "\"z\"")!.lowerBound
        XCTAssertTrue(outerA < outerZ)
        let innerA = json.range(of: "\"a\":2")!.lowerBound
        let innerB = json.range(of: "\"b\":1")!.lowerBound
        XCTAssertTrue(innerA < innerB)
    }

    func testWriteJSONValuePrettyPrinted() throws {
        let value = try JSONValue(string: #"{"key":"value"}"#)
        let data = try ReerJSONSerialization.data(
            withJSONObject: value,
            options: .prettyPrinted
        )
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\n"))
    }

    func testWriteJSONValueIndentationTwoSpaces() throws {
        let value = try JSONValue(string: #"{"key":"value"}"#)
        let json = try Self.jsonString(
            for: value,
            options: [.indentationTwoSpaces]
        )
        XCTAssertTrue(json.contains("  \"key\""))
        XCTAssertFalse(json.contains("    \"key\""))
    }

    func testWriteJSONObjectIndentationTwoSpaces() throws {
        let value = try JSONValue(string: #"{"key":"value"}"#)
        guard let object = value.object else {
            XCTFail("Expected object")
            return
        }
        let json = try Self.jsonString(
            for: object,
            options: [.indentationTwoSpaces]
        )
        XCTAssertTrue(json.contains("  \"key\""))
        XCTAssertFalse(json.contains("    \"key\""))
    }

    func testWriteJSONArrayIndentationTwoSpaces() throws {
        let value = try JSONValue(string: #"[{"key":"value"}]"#)
        guard let array = value.array else {
            XCTFail("Expected array")
            return
        }
        let json = try Self.jsonString(
            for: array,
            options: [.indentationTwoSpaces]
        )
        XCTAssertTrue(json.contains("\n  {"))
        XCTAssertFalse(json.contains("\n    {"))
    }

    func testWriteJSONValueIndentationTwoSpacesOverridesPrettyPrinted() throws {
        let value = try JSONValue(string: #"{"key":"value"}"#)
        let json = try Self.jsonString(
            for: value,
            options: [.prettyPrinted, .indentationTwoSpaces]
        )
        XCTAssertTrue(json.contains("  \"key\""))
        XCTAssertFalse(json.contains("    \"key\""))
    }

    func testWriteJSONValueEscapeUnicode() throws {
        let value = try JSONValue(string: #"{"emoji":"🎉"}"#)
        let json = try Self.jsonString(
            for: value,
            options: [.escapeUnicode]
        )
        XCTAssertFalse(json.contains("🎉"))
        XCTAssertTrue(json.contains("\\u"))
    }

    func testWriteJSONObjectEscapeUnicode() throws {
        let value = try JSONValue(string: #"{"emoji":"🎉"}"#)
        guard let object = value.object else {
            XCTFail("Expected object")
            return
        }
        let json = try Self.jsonString(
            for: object,
            options: [.escapeUnicode]
        )
        XCTAssertFalse(json.contains("🎉"))
        XCTAssertTrue(json.contains("\\u"))
    }

    func testWriteJSONArrayEscapeUnicode() throws {
        let value = try JSONValue(string: #"["🎉"]"#)
        guard let array = value.array else {
            XCTFail("Expected array")
            return
        }
        let json = try Self.jsonString(
            for: array,
            options: [.escapeUnicode]
        )
        XCTAssertFalse(json.contains("🎉"))
        XCTAssertTrue(json.contains("\\u"))
    }

    func testWriteJSONValueNewlineAtEnd() throws {
        let value = try JSONValue(string: #"{"key":"value"}"#)
        let json = try Self.jsonString(
            for: value,
            options: [.newlineAtEnd]
        )
        XCTAssertTrue(json.hasSuffix("\n"))
    }

    func testWriteJSONObjectNewlineAtEnd() throws {
        let value = try JSONValue(string: #"{"key":"value"}"#)
        guard let object = value.object else {
            XCTFail("Expected object")
            return
        }
        let json = try Self.jsonString(
            for: object,
            options: [.newlineAtEnd]
        )
        XCTAssertTrue(json.hasSuffix("\n"))
    }

    func testWriteJSONArrayNewlineAtEnd() throws {
        let value = try JSONValue(string: #"[1,2,3]"#)
        guard let array = value.array else {
            XCTFail("Expected array")
            return
        }
        let json = try Self.jsonString(
            for: array,
            options: [.newlineAtEnd]
        )
        XCTAssertTrue(json.hasSuffix("\n"))
    }

    func testWriteJSONValueIndentationTwoSpacesSortedKeys() throws {
        let value = try JSONValue(string: #"{"b":2,"a":1}"#)
        let json = try Self.jsonString(
            for: value,
            options: [.indentationTwoSpaces, .sortedKeys]
        )
        let aIndex = json.range(of: "\"a\"")!.lowerBound
        let bIndex = json.range(of: "\"b\"")!.lowerBound
        XCTAssertTrue(aIndex < bIndex)
        XCTAssertTrue(json.contains("  \"a\""))
    }

    func testWriteJSONObjectIndentationTwoSpacesSortedKeys() throws {
        let value = try JSONValue(string: #"{"b":2,"a":1}"#)
        guard let object = value.object else {
            XCTFail("Expected object")
            return
        }
        let json = try Self.jsonString(
            for: object,
            options: [.indentationTwoSpaces, .sortedKeys]
        )
        let aIndex = json.range(of: "\"a\"")!.lowerBound
        let bIndex = json.range(of: "\"b\"")!.lowerBound
        XCTAssertTrue(aIndex < bIndex)
        XCTAssertTrue(json.contains("  \"a\""))
    }

    func testWriteJSONArrayIndentationTwoSpacesSortedKeys() throws {
        let value = try JSONValue(string: #"[{"b":2,"a":1}]"#)
        guard let array = value.array else {
            XCTFail("Expected array")
            return
        }
        let json = try Self.jsonString(
            for: array,
            options: [.indentationTwoSpaces, .sortedKeys]
        )
        let aIndex = json.range(of: "\"a\"")!.lowerBound
        let bIndex = json.range(of: "\"b\"")!.lowerBound
        XCTAssertTrue(aIndex < bIndex)
        XCTAssertTrue(json.contains("\n  {"))
    }

    func testWriteNestedStructure() throws {
        let dict: NSDictionary = [
            "users": [
                ["name": "Alice"],
                ["name": "Bob"],
            ]
        ]
        let data = try ReerJSONSerialization.data(withJSONObject: dict)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("users"))
        XCTAssertTrue(json.contains("Alice"))
        XCTAssertTrue(json.contains("Bob"))
    }

    func testWritePrettyPrinted() throws {
        let dict: NSDictionary = ["key": "value"]
        let data = try ReerJSONSerialization.data(
            withJSONObject: dict,
            options: .prettyPrinted
        )
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\n"))
    }

    func testWriteSortedKeys() throws {
        let dict: NSDictionary = ["z": 1, "a": 2, "m": 3]
        let data = try ReerJSONSerialization.data(
            withJSONObject: dict,
            options: .sortedKeys
        )
        let json = String(data: data, encoding: .utf8)!
        let aIndex = json.range(of: "\"a\"")!.lowerBound
        let mIndex = json.range(of: "\"m\"")!.lowerBound
        let zIndex = json.range(of: "\"z\"")!.lowerBound
        XCTAssertTrue(aIndex < mIndex)
        XCTAssertTrue(mIndex < zIndex)
    }

    func testWriteWithoutEscapingSlashes() throws {
        let dict: NSDictionary = ["path": "/usr/bin"]
        let data = try ReerJSONSerialization.data(
            withJSONObject: dict,
            options: .withoutEscapingSlashes
        )
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("/usr/bin"))
        XCTAssertFalse(json.contains("\\/"))
    }

    func testWriteWithEscapingSlashes() throws {
        let dict: NSDictionary = ["path": "/usr/bin"]
        let data = try ReerJSONSerialization.data(withJSONObject: dict)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\\/usr\\/bin"))
    }

    func testWriteFragmentString() throws {
        let data = try ReerJSONSerialization.data(
            withJSONObject: NSString(string: "hello"),
            options: .fragmentsAllowed
        )
        let json = String(data: data, encoding: .utf8)!
        XCTAssertEqual(json, #""hello""#)
    }

    func testWriteFragmentNumber() throws {
        let data = try ReerJSONSerialization.data(
            withJSONObject: NSNumber(value: 42),
            options: .fragmentsAllowed
        )
        let json = String(data: data, encoding: .utf8)!
        XCTAssertEqual(json, "42")
    }

    func testWriteFragmentBool() throws {
        let data = try ReerJSONSerialization.data(
            withJSONObject: NSNumber(value: true),
            options: .fragmentsAllowed
        )
        let json = String(data: data, encoding: .utf8)!
        XCTAssertEqual(json, "true")
    }

    func testWriteFragmentNull() throws {
        let data = try ReerJSONSerialization.data(
            withJSONObject: NSNull(),
            options: .fragmentsAllowed
        )
        let json = String(data: data, encoding: .utf8)!
        XCTAssertEqual(json, "null")
    }

    func testWriteFragmentWithoutOption() throws {
        XCTAssertThrowsError(
            try ReerJSONSerialization.data(
                withJSONObject: NSString(string: "hello")
            )
        )
    }

    func testWriteInvalidObject() throws {
        class CustomClass {}
        XCTAssertThrowsError(
            try ReerJSONSerialization.data(withJSONObject: CustomClass())
        )
    }

    // MARK: - indentationTwoSpaces

    func testWriteIndentationTwoSpaces() throws {
        let dict: NSDictionary = ["key": "value"]
        let data = try ReerJSONSerialization.data(
            withJSONObject: dict,
            options: [.indentationTwoSpaces]
        )
        let json = String(data: data, encoding: .utf8)!
        // Should use 2-space indentation (not 4-space)
        XCTAssertTrue(json.contains("  \"key\""))
        XCTAssertFalse(json.contains("    \"key\""))
    }

    func testWriteIndentationTwoSpacesOverridesPrettyPrinted() throws {
        let dict: NSDictionary = ["a": 1]
        let data = try ReerJSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .indentationTwoSpaces]
        )
        let json = String(data: data, encoding: .utf8)!
        // 2-space should take priority
        XCTAssertTrue(json.contains("  \"a\""))
        XCTAssertFalse(json.contains("    \"a\""))
    }

    func testWriteIndentationTwoSpacesWithSortedKeys() throws {
        let dict: NSDictionary = ["b": 2, "a": 1]
        let data = try ReerJSONSerialization.data(
            withJSONObject: dict,
            options: [.indentationTwoSpaces, .sortedKeys]
        )
        let json = String(data: data, encoding: .utf8)!
        // Check key order and indentation
        let aIndex = json.range(of: "\"a\"")!.lowerBound
        let bIndex = json.range(of: "\"b\"")!.lowerBound
        XCTAssertTrue(aIndex < bIndex)  // a before b
        XCTAssertTrue(json.contains("  \"a\""))  // 2-space indent
    }

    func testWriteIndentationTwoSpacesNestedStructure() throws {
        let dict: NSDictionary = ["outer": ["inner": ["deep": 1]]]
        let data = try ReerJSONSerialization.data(
            withJSONObject: dict,
            options: [.indentationTwoSpaces]
        )
        let json = String(data: data, encoding: .utf8)!
        // Verify 2-space indentation at each nesting level
        XCTAssertTrue(json.contains("  \"outer\""))  // Level 1: 2 spaces
        XCTAssertTrue(json.contains("    \"inner\""))  // Level 2: 4 spaces
        XCTAssertTrue(json.contains("      \"deep\""))  // Level 3: 6 spaces
    }

    // MARK: - escapeUnicode

    func testWriteEscapeUnicode() throws {
        let dict: NSDictionary = ["emoji": "🎉"]
        let data = try ReerJSONSerialization.data(
            withJSONObject: dict,
            options: [.escapeUnicode]
        )
        let json = String(data: data, encoding: .utf8)!
        // Emoji should be escaped as \uXXXX
        XCTAssertFalse(json.contains("🎉"))
        XCTAssertTrue(json.contains("\\u"))
    }

    func testWriteEscapeUnicodeWithChinese() throws {
        let dict: NSDictionary = ["text": "你好"]
        let data = try ReerJSONSerialization.data(
            withJSONObject: dict,
            options: [.escapeUnicode]
        )
        let json = String(data: data, encoding: .utf8)!
        // Chinese characters should be escaped
        XCTAssertFalse(json.contains("你好"))
        XCTAssertTrue(json.contains("\\u"))
    }

    // MARK: - newlineAtEnd

    func testWriteNewlineAtEnd() throws {
        let dict: NSDictionary = ["a": 1]
        let data = try ReerJSONSerialization.data(
            withJSONObject: dict,
            options: [.newlineAtEnd]
        )
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.hasSuffix("\n"))
    }

    func testWriteNoNewlineAtEndByDefault() throws {
        let dict: NSDictionary = ["a": 1]
        let data = try ReerJSONSerialization.data(
            withJSONObject: dict,
            options: []
        )
        let json = String(data: data, encoding: .utf8)!
        XCTAssertFalse(json.hasSuffix("\n"))
    }

    func testWriteNewlineAtEndWithPrettyPrinted() throws {
        let dict: NSDictionary = ["a": 1]
        let data = try ReerJSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .newlineAtEnd]
        )
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.hasSuffix("\n"))
        XCTAssertTrue(json.contains("    \"a\""))  // 4-space indent
    }
}

// MARK: - isValidJSONObject Tests

class SerializationValidationTests: XCTestCase {
    func testValidDictionary() {
        let dict: NSDictionary = ["key": "value"]
        XCTAssertTrue(ReerJSONSerialization.isValidJSONObject(dict))
    }

    func testValidArray() {
        let array: NSArray = [1, 2, 3]
        XCTAssertTrue(ReerJSONSerialization.isValidJSONObject(array))
    }

    func testValidNestedStructure() {
        let dict: NSDictionary = [
            "array": [1, 2, 3],
            "nested": ["key": "value"],
        ]
        XCTAssertTrue(ReerJSONSerialization.isValidJSONObject(dict))
    }

    func testInvalidTopLevelString() {
        XCTAssertFalse(ReerJSONSerialization.isValidJSONObject(NSString(string: "hello")))
    }

    func testInvalidTopLevelNumber() {
        XCTAssertFalse(ReerJSONSerialization.isValidJSONObject(NSNumber(value: 42)))
    }

    func testInvalidTopLevelNull() {
        XCTAssertFalse(ReerJSONSerialization.isValidJSONObject(NSNull()))
    }

    func testInvalidNonStringKey() {
        let dict: NSDictionary = [NSNumber(value: 1): "value"]
        XCTAssertFalse(ReerJSONSerialization.isValidJSONObject(dict))
    }

    func testInvalidNaNValue() {
        let dict: NSDictionary = ["key": NSNumber(value: Double.nan)]
        XCTAssertFalse(ReerJSONSerialization.isValidJSONObject(dict))
    }

    func testInvalidInfinityValue() {
        let dict: NSDictionary = ["key": NSNumber(value: Double.infinity)]
        XCTAssertFalse(ReerJSONSerialization.isValidJSONObject(dict))
    }

    func testInvalidNestedNaN() {
        let dict: NSDictionary = [
            "nested": ["value": NSNumber(value: Double.nan)]
        ]
        XCTAssertFalse(ReerJSONSerialization.isValidJSONObject(dict))
    }

    func testInvalidArrayWithNaN() {
        let array: NSArray = [1, 2, NSNumber(value: Double.nan)]
        XCTAssertFalse(ReerJSONSerialization.isValidJSONObject(array))
    }

    func testValidMixedTypes() {
        let dict: NSDictionary = [
            "string": "hello",
            "number": 42,
            "bool": true,
            "null": NSNull(),
            "array": [1, 2, 3],
            "object": ["nested": "value"],
        ]
        XCTAssertTrue(ReerJSONSerialization.isValidJSONObject(dict))
    }
}

// MARK: - Roundtrip Tests

class SerializationRoundtripTests: XCTestCase {
    func testRoundtripDictionary() throws {
        let original: NSDictionary = [
            "string": "hello",
            "number": 42,
            "bool": true,
            "null": NSNull(),
            "array": [1, 2, 3],
        ]
        let data = try ReerJSONSerialization.data(withJSONObject: original)
        let decoded = try ReerJSONSerialization.jsonObject(with: data) as? NSDictionary
        XCTAssertEqual(decoded?["string"] as? String, "hello")
        XCTAssertEqual(decoded?["number"] as? Int, 42)
        XCTAssertEqual(decoded?["bool"] as? Bool, true)
        XCTAssertTrue(decoded?["null"] is NSNull)
    }

    func testRoundtripArray() throws {
        let original: NSArray = [1, "two", true, NSNull(), ["nested": "value"]]
        let data = try ReerJSONSerialization.data(withJSONObject: original)
        let decoded = try ReerJSONSerialization.jsonObject(with: data) as? NSArray
        XCTAssertEqual(decoded?.count, 5)
        XCTAssertEqual(decoded?[0] as? Int, 1)
        XCTAssertEqual(decoded?[1] as? String, "two")
        XCTAssertEqual(decoded?[2] as? Bool, true)
        XCTAssertTrue(decoded?[3] is NSNull)
    }

    func testRoundtripComplexStructure() throws {
        let original: NSDictionary = [
            "users": [
                ["id": 1, "name": "Alice", "active": true],
                ["id": 2, "name": "Bob", "active": false],
            ],
            "meta": [
                "total": 2,
                "page": 1,
            ],
        ]
        let data = try ReerJSONSerialization.data(withJSONObject: original)
        let decoded = try ReerJSONSerialization.jsonObject(with: data) as? NSDictionary

        let users = decoded?["users"] as? NSArray
        XCTAssertEqual(users?.count, 2)

        let alice = users?[0] as? NSDictionary
        XCTAssertEqual(alice?["name"] as? String, "Alice")

        let meta = decoded?["meta"] as? NSDictionary
        XCTAssertEqual(meta?["total"] as? Int, 2)
    }
}

// MARK: - Number Type Handling Tests

class SerializationNumberTests: XCTestCase {
    func testWriteSignedIntegers() throws {
        let dict: NSDictionary = [
            "int8": NSNumber(value: Int8(-128)),
            "int16": NSNumber(value: Int16(-32768)),
            "int32": NSNumber(value: Int32(-2147483648)),
            "int64": NSNumber(value: Int64(-9223372036854775808)),
        ]
        let data = try ReerJSONSerialization.data(withJSONObject: dict)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("-128"))
        XCTAssertTrue(json.contains("-32768"))
    }

    func testWriteUnsignedIntegers() throws {
        let dict: NSDictionary = [
            "uint8": NSNumber(value: UInt8(255)),
            "uint16": NSNumber(value: UInt16(65535)),
            "uint32": NSNumber(value: UInt32(4294967295)),
        ]
        let data = try ReerJSONSerialization.data(withJSONObject: dict)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("255"))
        XCTAssertTrue(json.contains("65535"))
    }

    func testWriteFloatingPoint() throws {
        let dict: NSDictionary = [
            "float": NSNumber(value: Float(3.14)),
            "double": NSNumber(value: Double(2.71828)),
        ]
        let data = try ReerJSONSerialization.data(withJSONObject: dict)
        let decoded = try ReerJSONSerialization.jsonObject(with: data) as? NSDictionary
        let floatValue = (decoded?["float"] as? NSNumber)?.doubleValue ?? 0
        XCTAssertTrue(abs(floatValue - 3.14) < 0.01)
    }

    func testWriteBooleans() throws {
        let dict: NSDictionary = [
            "true": NSNumber(value: true),
            "false": NSNumber(value: false),
        ]
        let data = try ReerJSONSerialization.data(withJSONObject: dict)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("true"))
        XCTAssertTrue(json.contains("false"))
    }
}

// MARK: - Edge Cases Tests

class SerializationEdgeCasesTests: XCTestCase {
    func testEmptyDictionary() throws {
        let dict: NSDictionary = [:]
        let data = try ReerJSONSerialization.data(withJSONObject: dict)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertEqual(json, "{}")
    }

    func testEmptyArray() throws {
        let array: NSArray = []
        let data = try ReerJSONSerialization.data(withJSONObject: array)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertEqual(json, "[]")
    }

    func testUnicodeStrings() throws {
        let dict: NSDictionary = [
            "emoji": "🎉🎊🎁",
            "chinese": "你好世界",
            "japanese": "こんにちは",
        ]
        let data = try ReerJSONSerialization.data(withJSONObject: dict)
        let decoded = try ReerJSONSerialization.jsonObject(with: data) as? NSDictionary
        XCTAssertEqual(decoded?["emoji"] as? String, "🎉🎊🎁")
        XCTAssertEqual(decoded?["chinese"] as? String, "你好世界")
        XCTAssertEqual(decoded?["japanese"] as? String, "こんにちは")
    }

    func testSpecialCharactersInStrings() throws {
        let dict: NSDictionary = [
            "newline": "line1\nline2",
            "tab": "col1\tcol2",
            "quote": "say \"hello\"",
            "backslash": "path\\to\\file",
        ]
        let data = try ReerJSONSerialization.data(withJSONObject: dict)
        let decoded = try ReerJSONSerialization.jsonObject(with: data) as? NSDictionary
        XCTAssertEqual(decoded?["newline"] as? String, "line1\nline2")
        XCTAssertEqual(decoded?["tab"] as? String, "col1\tcol2")
        XCTAssertEqual(decoded?["quote"] as? String, "say \"hello\"")
        XCTAssertEqual(decoded?["backslash"] as? String, "path\\to\\file")
    }

    func testVeryLongString() throws {
        let longString = String(repeating: "a", count: 100_000)
        let dict: NSDictionary = ["long": longString]
        let data = try ReerJSONSerialization.data(withJSONObject: dict)
        let decoded = try ReerJSONSerialization.jsonObject(with: data) as? NSDictionary
        XCTAssertEqual((decoded?["long"] as? String)?.count, 100_000)
    }

    func testDeeplyNestedStructure() throws {
        var current: NSDictionary = ["value": "deep"]
        for i in 0 ..< 50 {
            current = ["level\(i)": current]
        }
        let data = try ReerJSONSerialization.data(withJSONObject: current)
        let decoded = try ReerJSONSerialization.jsonObject(with: data) as? NSDictionary
        XCTAssertNotNil(decoded)
    }
}
