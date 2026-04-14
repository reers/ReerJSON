//
//  Adapted from swift-yyjson by Mattt (https://github.com/mattt/swift-yyjson)
//  Original code copyright 2026 Mattt (https://mat.tt), licensed under MIT License.
//  Converted from Swift Testing to XCTest for ReerJSON.
//

import Foundation
import XCTest

@testable import ReerJSON

// MARK: - JSONValue Basic Tests
class ValueBasicTypesTests: XCTestCase {
    func testParseNull() throws {
        let value = try JSONValue(string: "null")
        XCTAssertTrue(value.isNull)
        XCTAssertNil(value.string)
        XCTAssertNil(value.number)
        XCTAssertNil(value.bool)
        XCTAssertNil(value.array)
        XCTAssertNil(value.object)
    }

    func testParseBoolTrue() throws {
        let value = try JSONValue(string: "true")
        XCTAssertEqual(value.bool, true)
        XCTAssertFalse(value.isNull)
    }

    func testParseBoolFalse() throws {
        let value = try JSONValue(string: "false")
        XCTAssertEqual(value.bool, false)
        XCTAssertFalse(value.isNull)
    }

    func testParseInteger() throws {
        let value = try JSONValue(string: "42")
        XCTAssertEqual(value.number, 42.0)
        XCTAssertFalse(value.isNull)
    }

    func testParseNegativeInteger() throws {
        let value = try JSONValue(string: "-123")
        XCTAssertEqual(value.number, -123.0)
    }

    func testParseZero() throws {
        let value = try JSONValue(string: "0")
        XCTAssertEqual(value.number, 0.0)
    }

    func testParseFloat() throws {
        let value = try JSONValue(string: "3.14159")
        XCTAssertNotNil(value.number)
        XCTAssertTrue(abs(value.number! - 3.14159) < 0.00001)
    }

    func testParseNegativeFloat() throws {
        let value = try JSONValue(string: "-2.718")
        XCTAssertNotNil(value.number)
        XCTAssertTrue(abs(value.number! - (-2.718)) < 0.001)
    }

    func testParseScientificNotation() throws {
        let value = try JSONValue(string: "1.23e10")
        XCTAssertNotNil(value.number)
        XCTAssertTrue(abs(value.number! - 1.23e10) < 1e5)
    }

    func testParseString() throws {
        let value = try JSONValue(string: #""hello world""#)
        XCTAssertEqual(value.string, "hello world")
        XCTAssertFalse(value.isNull)
    }

    func testParseEmptyString() throws {
        let value = try JSONValue(string: #""""#)
        XCTAssertEqual(value.string, "")
    }

    func testParseStringWithUnicode() throws {
        let value = try JSONValue(string: #""Hello 你好 🌍""#)
        XCTAssertEqual(value.string, "Hello 你好 🌍")
    }

    func testParseStringWithEscapes() throws {
        let value = try JSONValue(string: #""line1\nline2\ttab""#)
        XCTAssertEqual(value.string, "line1\nline2\ttab")
    }

    func testParseStringWithQuotes() throws {
        let value = try JSONValue(string: #""say \"hello\"""#)
        XCTAssertEqual(value.string, #"say "hello""#)
    }
}

// MARK: - JSONValue Array Tests
class ValueArrayTests: XCTestCase {
    func testParseEmptyArray() throws {
        let value = try JSONValue(string: "[]")
        XCTAssertNotNil(value.array)
        XCTAssertEqual(value.array?.count, 0)
    }

    func testParseIntArray() throws {
        let value = try JSONValue(string: "[1, 2, 3, 4, 5]")
        guard let array = value.array else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(array.count, 5)
        XCTAssertEqual(array[0]?.number, 1.0)
        XCTAssertEqual(array[1]?.number, 2.0)
        XCTAssertEqual(array[2]?.number, 3.0)
        XCTAssertEqual(array[3]?.number, 4.0)
        XCTAssertEqual(array[4]?.number, 5.0)
    }

    func testParseStringArray() throws {
        let value = try JSONValue(string: #"["a", "b", "c"]"#)
        guard let array = value.array else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(array.count, 3)
        XCTAssertEqual(array[0]?.string, "a")
        XCTAssertEqual(array[1]?.string, "b")
        XCTAssertEqual(array[2]?.string, "c")
    }

    func testParseMixedArray() throws {
        let value = try JSONValue(string: #"[1, "two", true, null, 3.14]"#)
        guard let array = value.array else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(array.count, 5)
        XCTAssertEqual(array[0]?.number, 1.0)
        XCTAssertEqual(array[1]?.string, "two")
        XCTAssertEqual(array[2]?.bool, true)
        XCTAssertEqual(array[3]?.isNull, true)
        XCTAssertNotNil(array[4]?.number)
    }

    func testParseNestedArray() throws {
        let value = try JSONValue(string: "[[1, 2], [3, 4], [5, 6]]")
        guard let array = value.array else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(array.count, 3)
        XCTAssertEqual(array[0]?.array?[0]?.number, 1.0)
        XCTAssertEqual(array[0]?.array?[1]?.number, 2.0)
        XCTAssertEqual(array[1]?.array?[0]?.number, 3.0)
        XCTAssertEqual(array[2]?.array?[1]?.number, 6.0)
    }

    func testArraySubscriptOutOfBounds() throws {
        let value = try JSONValue(string: "[1, 2, 3]")
        XCTAssertNil(value[10])
        XCTAssertNil(value[-1])
    }

    func testArrayIteration() throws {
        let value = try JSONValue(string: "[1, 2, 3, 4, 5]")
        guard let array = value.array else {
            XCTFail("Expected array")
            return
        }

        var sum = 0.0
        for element in array {
            sum += element.number ?? 0
        }
        XCTAssertEqual(sum, 15.0)
    }

    func testArraySubscriptOnNonArray() throws {
        let value = try JSONValue(string: #""not an array""#)
        XCTAssertNil(value[0])
    }
}

// MARK: - JSONValue Object Tests
class ValueObjectTests: XCTestCase {
    func testParseEmptyObject() throws {
        let value = try JSONValue(string: "{}")
        XCTAssertNotNil(value.object)
        XCTAssertEqual(value.object?.keys.isEmpty, true)
    }

    func testParseSimpleObject() throws {
        let value = try JSONValue(string: #"{"name": "Alice", "age": 30}"#)
        XCTAssertEqual(value["name"]?.string, "Alice")
        XCTAssertEqual(value["age"]?.number, 30.0)
    }

    func testParseNestedObject() throws {
        let json = """
            {
                "person": {
                    "name": "Bob",
                    "address": {
                        "city": "New York",
                        "zip": "10001"
                    }
                }
            }
            """
        let value = try JSONValue(string: json)
        XCTAssertEqual(value["person"]?["name"]?.string, "Bob")
        XCTAssertEqual(value["person"]?["address"]?["city"]?.string, "New York")
        XCTAssertEqual(value["person"]?["address"]?["zip"]?.string, "10001")
    }

    func testObjectWithArray() throws {
        let json = #"{"items": [1, 2, 3]}"#
        let value = try JSONValue(string: json)
        guard let items = value["items"]?.array else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0]?.number, 1.0)
    }

    func testObjectKeys() throws {
        let json = #"{"a": 1, "b": 2, "c": 3}"#
        let value = try JSONValue(string: json)
        guard let obj = value.object else {
            XCTFail("Expected object")
            return
        }
        let keys = obj.keys.sorted()
        XCTAssertEqual(keys, ["a", "b", "c"])
    }

    func testObjectContains() throws {
        let json = #"{"a": 1, "b": 2}"#
        let value = try JSONValue(string: json)
        guard let obj = value.object else {
            XCTFail("Expected object")
            return
        }
        XCTAssertTrue(obj.contains("a"))
        XCTAssertTrue(obj.contains("b"))
        XCTAssertFalse(obj.contains("c"))
    }

    func testObjectIteration() throws {
        let json = #"{"a": 1, "b": 2, "c": 3}"#
        let value = try JSONValue(string: json)
        guard let obj = value.object else {
            XCTFail("Expected object")
            return
        }

        var dict: [String: Double] = [:]
        for (key, val) in obj {
            dict[key] = val.number
        }
        XCTAssertEqual(dict, ["a": 1.0, "b": 2.0, "c": 3.0])
    }

    func testObjectSubscriptMissingKey() throws {
        let value = try JSONValue(string: #"{"a": 1}"#)
        XCTAssertNil(value["missing"])
    }

    func testObjectSubscriptOnNonObject() throws {
        let value = try JSONValue(string: "[1, 2, 3]")
        XCTAssertNil(value["key"])
    }
}

// MARK: - JSONValue Description Tests
class ValueDescriptionTests: XCTestCase {
    func testNullDescription() throws {
        let value = try JSONValue(string: "null")
        XCTAssertEqual(value.description, "null")
    }

    func testBoolDescription() throws {
        let trueValue = try JSONValue(string: "true")
        let falseValue = try JSONValue(string: "false")
        XCTAssertEqual(trueValue.description, "true")
        XCTAssertEqual(falseValue.description, "false")
    }

    func testNumberDescription() throws {
        let value = try JSONValue(string: "42")
        XCTAssertTrue(value.description.contains("42"))
    }

    func testLargeIntegerDescription() throws {
        let value = try JSONValue(string: "9007199254740993")
        XCTAssertEqual(value.description, "9007199254740993")
    }

    func testStringDescription() throws {
        let value = try JSONValue(string: #""hello""#)
        XCTAssertEqual(value.description, #""hello""#)
    }

    func testArrayDescription() throws {
        let value = try JSONValue(string: "[1, 2, 3]")
        let desc = value.description
        XCTAssertTrue(desc.contains("["))
        XCTAssertTrue(desc.contains("]"))
    }

    func testObjectDescription() throws {
        let value = try JSONValue(string: #"{"a": 1}"#)
        let desc = value.description
        XCTAssertTrue(desc.contains("{"))
        XCTAssertTrue(desc.contains("}"))
        XCTAssertTrue(desc.contains("a"))
    }
}

// MARK: - JSONValue Parsing Options Tests
class ValueParsingOptionsTests: XCTestCase {
    func testParseWithDefaultOptions() throws {
        let json = #"{"key": "value"}"#
        let value = try JSONValue(string: json, options: .default)
        XCTAssertEqual(value["key"]?.string, "value")
    }

    func testParseFromData() throws {
        let json = #"{"key": "value"}"#
        let data = json.data(using: .utf8)!
        let value = try JSONValue(data: data)
        XCTAssertEqual(value["key"]?.string, "value")
    }

    func testParseInvalidJSON() throws {
        XCTAssertThrowsError(try JSONValue(string: "not valid json"))
    }

    func testParseEmptyString() throws {
        XCTAssertThrowsError(try JSONValue(string: ""))
    }

    func testParseIncompleteJSON() throws {
        XCTAssertThrowsError(try JSONValue(string: #"{"key": "#))
    }
}

// MARK: - JSONObject Tests
class JSONObjectTests: XCTestCase {
    func testObjectSubscript() throws {
        let value = try JSONValue(string: #"{"a": 1, "b": "two"}"#)
        guard let obj = value.object else {
            XCTFail("Expected object")
            return
        }
        XCTAssertEqual(obj["a"]?.number, 1.0)
        XCTAssertEqual(obj["b"]?.string, "two")
        XCTAssertNil(obj["c"])
    }

    func testObjectKeysProperty() throws {
        let value = try JSONValue(string: #"{"x": 1, "y": 2, "z": 3}"#)
        guard let obj = value.object else {
            XCTFail("Expected object")
            return
        }
        XCTAssertEqual(Set(obj.keys), Set(["x", "y", "z"]))
    }

    func testObjectContainsMethod() throws {
        let value = try JSONValue(string: #"{"exists": true}"#)
        guard let obj = value.object else {
            XCTFail("Expected object")
            return
        }
        XCTAssertTrue(obj.contains("exists"))
        XCTAssertFalse(obj.contains("missing"))
    }
}

// MARK: - JSONArray Tests
class JSONArrayTests: XCTestCase {
    func testArraySubscript() throws {
        let value = try JSONValue(string: "[10, 20, 30]")
        guard let arr = value.array else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(arr[0]?.number, 10.0)
        XCTAssertEqual(arr[1]?.number, 20.0)
        XCTAssertEqual(arr[2]?.number, 30.0)
        XCTAssertNil(arr[3])
    }

    func testArrayCount() throws {
        let value = try JSONValue(string: "[1, 2, 3, 4, 5]")
        guard let arr = value.array else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(arr.count, 5)
    }

    func testEmptyArrayCount() throws {
        let value = try JSONValue(string: "[]")
        guard let arr = value.array else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(arr.count, 0)
    }

    func testArrayMap() throws {
        let value = try JSONValue(string: "[1, 2, 3]")
        guard let arr = value.array else {
            XCTFail("Expected array")
            return
        }
        let doubled = arr.map { ($0.number ?? 0) * 2 }
        XCTAssertEqual(doubled, [2.0, 4.0, 6.0])
    }

    func testArrayFilter() throws {
        let value = try JSONValue(string: "[1, 2, 3, 4, 5]")
        guard let arr = value.array else {
            XCTFail("Expected array")
            return
        }
        let evens = arr.filter { Int($0.number ?? 0) % 2 == 0 }
        XCTAssertEqual(evens.count, 2)
    }
}

// MARK: - Complex JSON Tests
class ValueComplexJSONTests: XCTestCase {
    func testParseComplexJSON() throws {
        let json = """
            {
                "users": [
                    {
                        "id": 1,
                        "name": "Alice",
                        "email": "alice@example.com",
                        "active": true,
                        "roles": ["admin", "user"]
                    },
                    {
                        "id": 2,
                        "name": "Bob",
                        "email": "bob@example.com",
                        "active": false,
                        "roles": ["user"]
                    }
                ],
                "meta": {
                    "total": 2,
                    "page": 1,
                    "perPage": 10
                }
            }
            """
        let value = try JSONValue(string: json)

        XCTAssertEqual(value["meta"]?["total"]?.number, 2.0)
        XCTAssertEqual(value["meta"]?["page"]?.number, 1.0)

        guard let users = value["users"]?.array else {
            XCTFail("Expected users array")
            return
        }
        XCTAssertEqual(users.count, 2)

        let alice = users[0]
        XCTAssertEqual(alice?["id"]?.number, 1.0)
        XCTAssertEqual(alice?["name"]?.string, "Alice")
        XCTAssertEqual(alice?["active"]?.bool, true)
        XCTAssertEqual(alice?["roles"]?.array?.count, 2)

        let bob = users[1]
        XCTAssertEqual(bob?["id"]?.number, 2.0)
        XCTAssertEqual(bob?["active"]?.bool, false)
    }

    func testParseDeeplyNestedJSON() throws {
        let json = """
            {
                "level1": {
                    "level2": {
                        "level3": {
                            "level4": {
                                "level5": {
                                    "value": "deep"
                                }
                            }
                        }
                    }
                }
            }
            """
        let value = try JSONValue(string: json)
        let deep = value["level1"]?["level2"]?["level3"]?["level4"]?["level5"]?["value"]?.string
        XCTAssertEqual(deep, "deep")
    }

    func testParseLargeArray() throws {
        var elements: [String] = []
        for i in 0 ..< 1000 {
            elements.append(String(i))
        }
        let json = "[\(elements.joined(separator: ", "))]"
        let value = try JSONValue(string: json)
        guard let arr = value.array else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(arr.count, 1000)
        XCTAssertEqual(arr[0]?.number, 0.0)
        XCTAssertEqual(arr[999]?.number, 999.0)
    }
}

// MARK: - JSONValue cString Tests
class ValueCStringTests: XCTestCase {
    func testCStringForBasicString() throws {
        let value = try JSONValue(string: #""hello world""#)
        guard let cString = value.cString else {
            XCTFail("Expected cString to be non-nil for string value")
            return
        }
        let swiftString = String(cString: cString)
        XCTAssertEqual(swiftString, "hello world")
    }

    func testCStringForEmptyString() throws {
        let value = try JSONValue(string: #""""#)
        guard let cString = value.cString else {
            XCTFail("Expected cString to be non-nil for empty string")
            return
        }
        let swiftString = String(cString: cString)
        XCTAssertEqual(swiftString, "")
    }

    func testCStringForUnicodeString() throws {
        let value = try JSONValue(string: #""Hello 你好 🌍""#)
        guard let cString = value.cString else {
            XCTFail("Expected cString to be non-nil for Unicode string")
            return
        }
        let swiftString = String(cString: cString)
        XCTAssertEqual(swiftString, "Hello 你好 🌍")
    }

    func testCStringForStringWithEscapes() throws {
        let value = try JSONValue(string: #""line1\nline2\ttab""#)
        guard let cString = value.cString else {
            XCTFail("Expected cString to be non-nil for string with escapes")
            return
        }
        let swiftString = String(cString: cString)
        XCTAssertEqual(swiftString, "line1\nline2\ttab")
    }

    func testCStringForStringWithQuotes() throws {
        let value = try JSONValue(string: #""say \"hello\"""#)
        guard let cString = value.cString else {
            XCTFail("Expected cString to be non-nil for string with quotes")
            return
        }
        let swiftString = String(cString: cString)
        XCTAssertEqual(swiftString, #"say "hello""#)
    }

    func testCStringForNull() throws {
        let value = try JSONValue(string: "null")
        XCTAssertNil(value.cString)
    }

    func testCStringForBool() throws {
        let trueValue = try JSONValue(string: "true")
        let falseValue = try JSONValue(string: "false")
        XCTAssertNil(trueValue.cString)
        XCTAssertNil(falseValue.cString)
    }

    func testCStringForNumber() throws {
        let intValue = try JSONValue(string: "42")
        let floatValue = try JSONValue(string: "3.14")
        XCTAssertNil(intValue.cString)
        XCTAssertNil(floatValue.cString)
    }

    func testCStringForArray() throws {
        let value = try JSONValue(string: "[1, 2, 3]")
        XCTAssertNil(value.cString)
    }

    func testCStringForObject() throws {
        let value = try JSONValue(string: #"{"key": "value"}"#)
        XCTAssertNil(value.cString)
    }

    func testCStringMatchesStringProperty() throws {
        let testCases: [(json: String, expected: String)] = [
            (#""hello world""#, "hello world"),
            (#""""#, ""),
            (#""Hello 你好 🌍""#, "Hello 你好 🌍"),
            (#""line1\nline2\ttab""#, "line1\nline2\ttab"),
            (#""say \"hello\"""#, #"say "hello""#),
        ]

        for (json, expected) in testCases {
            let value = try JSONValue(string: json)
            guard let cString = value.cString else {
                XCTFail("Expected cString for: \(expected)")
                continue
            }
            let cStringValue = String(cString: cString)
            let stringValue = value.string
            XCTAssertEqual(cStringValue, expected)
            XCTAssertEqual(cStringValue, stringValue)
        }
    }

    func testCStringPointerIsValid() throws {
        let value = try JSONValue(string: #""test string""#)
        guard let cString = value.cString else {
            XCTFail("Expected cString to be non-nil")
            return
        }

        // Verify the pointer is valid by reading from it
        let length = strlen(cString)
        XCTAssertEqual(length, 11)  // "test string" length

        // Verify we can read the entire string (excluding null terminator)
        let buffer = UnsafeBufferPointer(start: cString, count: length)
        let data = Data(buffer: buffer)
        let reconstructed = String(data: data, encoding: .utf8)
        XCTAssertEqual(reconstructed, "test string")
    }

    func testCStringInNestedStructure() throws {
        let json = #"{"name": "Alice", "message": "Hello\nWorld"}"#
        let value = try JSONValue(string: json)

        guard let nameCString = value["name"]?.cString else {
            XCTFail("Expected cString for name")
            return
        }
        XCTAssertEqual(String(cString: nameCString), "Alice")

        guard let messageCString = value["message"]?.cString else {
            XCTFail("Expected cString for message")
            return
        }
        XCTAssertEqual(String(cString: messageCString), "Hello\nWorld")
    }

    func testCStringInArray() throws {
        let json = #"["first", "second", "third"]"#
        let value = try JSONValue(string: json)
        guard let array = value.array else {
            XCTFail("Expected array")
            return
        }

        guard let firstCString = array[0]?.cString else {
            XCTFail("Expected cString for first element")
            return
        }
        XCTAssertEqual(String(cString: firstCString), "first")

        guard let secondCString = array[1]?.cString else {
            XCTFail("Expected cString for second element")
            return
        }
        XCTAssertEqual(String(cString: secondCString), "second")
    }
}

// MARK: - In-Place Parsing Tests
class ValueInPlaceTests: XCTestCase {
    func testParseInPlace() throws {
        let json = #"{"name": "test", "value": 42}"#
        var data = json.data(using: .utf8)!
        let value = try JSONValue.parseInPlace(consuming: &data)
        XCTAssertEqual(value["name"]?.string, "test")
        XCTAssertEqual(value["value"]?.number, 42.0)
    }

    func testParseInPlaceEmptyData() throws {
        var data = Data()
        XCTAssertThrowsError(try JSONValue.parseInPlace(consuming: &data))
    }

    func testParseInPlaceInvalidJSON() throws {
        var data = "not valid json".data(using: .utf8)!
        XCTAssertThrowsError(try JSONValue.parseInPlace(consuming: &data))
    }

    func testParseInPlaceArray() throws {
        let json = "[1, 2, 3, 4, 5]"
        var data = json.data(using: .utf8)!
        let value = try JSONValue.parseInPlace(consuming: &data)
        guard let array = value.array else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(array.count, 5)
        XCTAssertEqual(array[0]?.number, 1.0)
        XCTAssertEqual(array[4]?.number, 5.0)
    }

    func testParseInPlacePrimitive() throws {
        var data = "42".data(using: .utf8)!
        let value = try JSONValue.parseInPlace(consuming: &data)
        XCTAssertEqual(value.number, 42.0)
    }

    func testParseInPlaceString() throws {
        var data = #""hello world""#.data(using: .utf8)!
        let value = try JSONValue.parseInPlace(consuming: &data)
        XCTAssertEqual(value.string, "hello world")
    }

    func testParseInPlaceDataRetained() throws {
        let json = #"{"key": "value"}"#
        var data = json.data(using: .utf8)!
        let value = try JSONValue.parseInPlace(consuming: &data)
        // Verify the value is still accessible after data is consumed
        XCTAssertEqual(value["key"]?.string, "value")
        // Access multiple times to ensure data is retained
        XCTAssertEqual(value["key"]?.string, "value")
        XCTAssertEqual(value["key"]?.string, "value")
    }
}

// MARK: - JSONDocument Tests
class JSONDocumentInitTests: XCTestCase {
    func testInitFromData() throws {
        let json = #"{"name": "Alice", "age": 30}"#
        let data = json.data(using: .utf8)!
        let document = try JSONDocument(data: data)
        XCTAssertNotNil(document.root)
        XCTAssertEqual(document.root?["name"]?.string, "Alice")
        XCTAssertEqual(document.root?["age"]?.number, 30.0)
    }

    func testInitFromString() throws {
        let json = #"{"key": "value"}"#
        let document = try JSONDocument(string: json)
        XCTAssertNotNil(document.root)
        XCTAssertEqual(document.root?["key"]?.string, "value")
    }

    func testInitFromDataWithOptions() throws {
        let json = #"{"key": "value"}"#
        let data = json.data(using: .utf8)!
        let document = try JSONDocument(data: data, options: .default)
        XCTAssertNotNil(document.root)
        XCTAssertEqual(document.root?["key"]?.string, "value")
    }

    func testInitFromStringWithOptions() throws {
        let json = #"{"key": "value"}"#
        let document = try JSONDocument(string: json, options: .default)
        XCTAssertNotNil(document.root)
        XCTAssertEqual(document.root?["key"]?.string, "value")
    }

    func testInitFromEmptyData() throws {
        let data = Data()
        do {
            let _ = try JSONDocument(data: data)
            XCTFail("Expected error")
        } catch {
            // expected
        }
    }

    func testInitFromEmptyString() throws {
        do {
            let _ = try JSONDocument(string: "")
            XCTFail("Expected error")
        } catch {
            // expected
        }
    }

    func testInitFromInvalidJSON() throws {
        let data = "not valid json".data(using: .utf8)!
        do {
            let _ = try JSONDocument(data: data)
            XCTFail("Expected error")
        } catch {
            // expected
        }
    }

    func testParsingInPlace() throws {
        let json = #"{"name": "test", "value": 42}"#
        var data = json.data(using: .utf8)!
        let document = try JSONDocument(parsingInPlace: &data)
        XCTAssertNotNil(document.root)
        XCTAssertEqual(document.root?["name"]?.string, "test")
        XCTAssertEqual(document.root?["value"]?.number, 42.0)
    }

    func testParsingInPlaceEmptyData() throws {
        var data = Data()
        do {
            let _ = try JSONDocument(parsingInPlace: &data)
            XCTFail("Expected error")
        } catch {
            // expected
        }
    }

    func testParsingInPlaceInvalidJSON() throws {
        var data = "not valid json".data(using: .utf8)!
        do {
            let _ = try JSONDocument(parsingInPlace: &data)
            XCTFail("Expected error")
        } catch {
            // expected
        }
    }
}

class JSONDocumentRootTests: XCTestCase {
    func testRootProperty() throws {
        let document = try JSONDocument(string: #"{"key": "value"}"#)
        XCTAssertNotNil(document.root)
        XCTAssertEqual(document.root?["key"]?.string, "value")
    }

    func testRootObjectProperty() throws {
        let document = try JSONDocument(string: #"{"key": "value"}"#)
        XCTAssertNotNil(document.rootObject)
        XCTAssertEqual(document.rootObject?["key"]?.string, "value")
    }

    func testRootArrayProperty() throws {
        let document = try JSONDocument(string: "[1, 2, 3]")
        XCTAssertNotNil(document.rootArray)
        XCTAssertEqual(document.rootArray?.count, 3)
        XCTAssertEqual(document.rootArray?[0]?.number, 1.0)
    }

    func testRootObjectOnArray() throws {
        let document = try JSONDocument(string: "[1, 2, 3]")
        XCTAssertNil(document.rootObject)
    }

    func testRootArrayOnObject() throws {
        let document = try JSONDocument(string: #"{"key": "value"}"#)
        XCTAssertNil(document.rootArray)
    }

    func testRootOnPrimitive() throws {
        let document = try JSONDocument(string: "42")
        XCTAssertNotNil(document.root)
        XCTAssertEqual(document.root?.number, 42.0)
        XCTAssertNil(document.rootObject)
        XCTAssertNil(document.rootArray)
    }

    func testRootOnString() throws {
        let document = try JSONDocument(string: #""hello""#)
        XCTAssertNotNil(document.root)
        XCTAssertEqual(document.root?.string, "hello")
    }

    func testRootOnNull() throws {
        let document = try JSONDocument(string: "null")
        XCTAssertNotNil(document.root)
        XCTAssertEqual(document.root?.isNull, true)
    }

    func testRootOnBool() throws {
        let document = try JSONDocument(string: "true")
        XCTAssertNotNil(document.root)
        XCTAssertEqual(document.root?.bool, true)
    }
}

class JSONDocumentComplexTests: XCTestCase {
    func testNestedStructures() throws {
        let json = """
            {
                "users": [
                    {"name": "Alice", "age": 30},
                    {"name": "Bob", "age": 25}
                ],
                "meta": {"count": 2}
            }
            """
        let document = try JSONDocument(string: json)
        guard let root = document.root else {
            XCTFail("Expected root")
            return
        }
        guard let users = root["users"]?.array else {
            XCTFail("Expected users array")
            return
        }
        XCTAssertEqual(users.count, 2)
        XCTAssertEqual(users[0]?["name"]?.string, "Alice")
        XCTAssertEqual(users[1]?["name"]?.string, "Bob")
        XCTAssertEqual(root["meta"]?["count"]?.number, 2.0)
    }

    func testLargeDocument() throws {
        var elements: [String] = []
        for i in 0 ..< 100 {
            elements.append(String(i))
        }
        let json = "[\(elements.joined(separator: ", "))]"
        let document = try JSONDocument(string: json)
        guard let array = document.rootArray else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(array.count, 100)
        XCTAssertEqual(array[0]?.number, 0.0)
        XCTAssertEqual(array[99]?.number, 99.0)
    }
}

class ValueWritingTests: XCTestCase {
    func testWriteSortedKeys() throws {
        let value = try JSONValue(string: #"{"b":1,"a":2}"#)
        let data = try value.data(options: [.sortedKeys])
        let json = String(data: data, encoding: .utf8)!
        let aIndex = json.range(of: "\"a\"")!.lowerBound
        let bIndex = json.range(of: "\"b\"")!.lowerBound
        XCTAssertTrue(aIndex < bIndex)
    }

    func testWriteFragment() throws {
        let value = try JSONValue(string: "true")
        let data = try value.data()
        let json = String(data: data, encoding: .utf8)!
        XCTAssertEqual(json, "true")
    }
}
