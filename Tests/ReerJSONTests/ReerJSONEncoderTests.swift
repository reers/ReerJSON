
import XCTest
@testable import ReerJSON
import Foundation

class ReerJSONEncoderTests: XCTestCase {

    var encoder: ReerJSONEncoder!

    override func setUp() {
        super.setUp()
        encoder = ReerJSONEncoder()
    }

    override func tearDown() {
        encoder = nil
        super.tearDown()
    }

    // MARK: - Helper Functions
    
    func assertEncode<T: Encodable & Equatable>(
        _ value: T,
        _ expected: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        do {
            let data = try encoder.encode(value)
            let result = String(data: data, encoding: .utf8)
            XCTAssertEqual(result, expected, file: file, line: line)
        } catch {
            XCTFail("Encoding failed with error: \(error)", file: file, line: line)
        }
    }
    
    func assertEncode<T: Encodable>(
        _ value: T,
        produces expected: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        do {
            let data = try encoder.encode(value)
            guard let result = String(data: data, encoding: .utf8) else {
                XCTFail("Failed to convert encoded data to string", file: file, line: line)
                return
            }
            XCTAssertEqual(result, expected, file: file, line: line)
        } catch {
            XCTFail("Encoding \(T.self) failed: \(error)", file: file, line: line)
        }
    }
    
    private func sortJSONKeys(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let sortedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys]) else {
            return jsonString
        }
        return String(data: sortedData, encoding: .utf8) ?? jsonString
    }

    // MARK: - Basic Types

    func testEncodeNull() {
        let value: Int? = nil
        assertEncode(value, "null")
    }

    func testEncodeBool() {
        assertEncode(true, "true")
        assertEncode(false, "false")
    }

    func testEncodeString() {
        assertEncode("hello", "\"hello\"")
        assertEncode("with \"quotes\"", "\"with \\\"quotes\\\"\"")
        assertEncode("escaped \\/\\n\\r\\t", "\"escaped \\\\/\\n\\r\\t\"")
    }
    
    func testEncodeNumbers() {
        assertEncode(42, "42")
        assertEncode(-42, "-42")
        assertEncode(3.14159, "3.14159")
        assertEncode(Int64.max, "\(Int64.max)")
        assertEncode(UInt64.max, "\(UInt64.max)")
    }
    
    func testEncodeFloat() {
        assertEncode(Float(3.14), "3.14")
    }
    
    func testEncodeDouble() {
        assertEncode(Double(3.1415926535), "3.1415926535")
    }

    // MARK: - Structs and Classes

    struct SimpleStruct: Codable, Equatable {
        let name: String
        let value: Int
    }

    func testEncodeSimpleStruct() {
        let value = SimpleStruct(name: "test", value: 123)
        let expected = "{\"name\":\"test\",\"value\":123}"
        
        do {
            let data = try encoder.encode(value)
            let result = String(data: data, encoding: .utf8)
            XCTAssertEqual(sortJSONKeys(result!), sortJSONKeys(expected))
        } catch {
            XCTFail("Encoding failed with error: \(error)")
        }
    }

    struct NestedStruct: Codable, Equatable {
        let simple: SimpleStruct
        let anotherValue: Bool
    }
    
    func testEncodeNestedStruct() {
        let value = NestedStruct(simple: SimpleStruct(name: "nested", value: 456), anotherValue: true)
        let expected = "{\"simple\":{\"name\":\"nested\",\"value\":456},\"anotherValue\":true}"
        
        do {
            let data = try encoder.encode(value)
            let result = String(data: data, encoding: .utf8)
            XCTAssertEqual(sortJSONKeys(result!), sortJSONKeys(expected))
        } catch {
            XCTFail("Encoding failed with error: \(error)")
        }
    }

    // MARK: - Arrays

    func testEncodeArray() {
        let array = [1, 2, 3]
        assertEncode(array, "[1,2,3]")
    }
    
    func testEncodeEmptyArray() {
        let array: [Int] = []
        assertEncode(array, "[]")
    }

    func testEncodeArrayOfStructs() {
        let array = [SimpleStruct(name: "a", value: 1), SimpleStruct(name: "b", value: 2)]
        let expected = "[{\"name\":\"a\",\"value\":1},{\"name\":\"b\",\"value\":2}]"
        
        do {
            let data = try encoder.encode(array)
            let result = String(data: data, encoding: .utf8)
            let sortedResult = try JSONSerialization.jsonObject(with: data, options: []) as! [Any]
            
            let expectedData = expected.data(using: .utf8)!
            let expectedSorted = try JSONSerialization.jsonObject(with: expectedData, options: []) as! [Any]
            
            XCTAssertEqual(sortedResult.count, expectedSorted.count)
        } catch {
            XCTFail("Encoding or comparison failed: \(error)")
        }
    }

    // MARK: - Dictionaries

    func testEncodeDictionary() {
        let dict = ["a": 1, "b": 2]
        let expected = "{\"a\":1,\"b\":2}"
        
        do {
            let data = try encoder.encode(dict)
            let result = String(data: data, encoding: .utf8)
            XCTAssertEqual(sortJSONKeys(result!), sortJSONKeys(expected))
        } catch {
            XCTFail("Encoding failed with error: \(error)")
        }
    }

    func testEncodeEmptyDictionary() {
        let dict: [String: Int] = [:]
        assertEncode(dict, "{}")
    }

    // MARK: - Encoding Strategies

    func testDateEncodingStrategySecondsSince1970() {
        encoder.dateEncodingStrategy = .secondsSince1970
        let date = Date(timeIntervalSince1970: 1234567890)
        assertEncode(date, "1234567890")
    }

    func testDateEncodingStrategyMillisecondsSince1970() {
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let date = Date(timeIntervalSince1970: 1234567890.123)
        assertEncode(date, "1234567890123")
    }

    func testDateEncodingStrategyISO8601() {
        encoder.dateEncodingStrategy = .iso8601
        let date = Date(timeIntervalSinceReferenceDate: 0) // "2001-01-01T00:00:00Z"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let expected = formatter.string(from: date)
        assertEncode(date, "\"\(expected)\"")
    }
    
    func testDataEncodingStrategyBase64() {
        encoder.dataEncodingStrategy = .base64
        let data = "hello".data(using: .utf8)!
        assertEncode(data, "\"aGVsbG8=\"")
    }
    
    func testKeyEncodingStrategyConvertToSnakeCase() {
        struct User: Codable, Equatable {
            let firstName: String
            let lastName: String
        }
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let user = User(firstName: "John", lastName: "Appleseed")
        let expected = "{\"first_name\":\"John\",\"last_name\":\"Appleseed\"}"
        
        do {
            let data = try encoder.encode(user)
            let result = String(data: data, encoding: .utf8)
            XCTAssertEqual(sortJSONKeys(result!), sortJSONKeys(expected))
        } catch {
            XCTFail("Encoding failed with error: \(error)")
        }
    }
    
    func testNonConformingFloatStrategy() {
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "+inf",
            negativeInfinity: "-inf",
            nan: "nan"
        )
        assertEncode(Double.infinity, "\"+inf\"")
        assertEncode(-Double.infinity, "\"-inf\"")
        assertEncode(Double.nan, "\"nan\"")
    }

    // MARK: - Output Formatting
    func testPrettyPrintedOutput() {
        encoder.outputFormatting = .prettyPrinted
        let value = SimpleStruct(name: "test", value: 123)
        // The exact format can vary slightly (e.g., indentation), so we check for key elements.
        do {
            let data = try encoder.encode(value)
            let result = String(data: data, encoding: .utf8)!
            XCTAssertTrue(result.contains("\n"))
            XCTAssertTrue(result.contains("  \"name\" : \"test\""))
        } catch {
            XCTFail("Encoding failed with error: \(error)")
        }
    }
}

