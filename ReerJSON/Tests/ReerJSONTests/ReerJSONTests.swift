import XCTest
@testable import ReerJSON

final class ReerJSONTests: XCTestCase {
    
    func testSimpleString() throws {
        let jsonString = "\"hello\""
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = ReerJSONDecoder()
        
        let result = try decoder.decode(String.self, from: jsonData)
        XCTAssertEqual(result, "hello")
    }
    
    func testSimpleNumber() throws {
        let jsonString = "42"
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = ReerJSONDecoder()
        
        let result = try decoder.decode(Int.self, from: jsonData)
        XCTAssertEqual(result, 42)
    }
    
    func testSimpleBoolean() throws {
        let jsonString = "true"
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = ReerJSONDecoder()
        
        let result = try decoder.decode(Bool.self, from: jsonData)
        XCTAssertEqual(result, true)
    }
    
    func testBasicDecoding() throws {
        let jsonString = """
        {
            "name": "John",
            "age": 30,
            "active": true,
            "score": 95.5
        }
        """
        
        struct Person: Codable {
            let name: String
            let age: Int
            let active: Bool
            let score: Double
        }
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = ReerJSONDecoder()
        
        let person = try decoder.decode(Person.self, from: jsonData)
        
        XCTAssertEqual(person.name, "John")
        XCTAssertEqual(person.age, 30)
        XCTAssertEqual(person.active, true)
        XCTAssertEqual(person.score, 95.5)
    }
    
    func testArrayDecoding() throws {
        let jsonString = """
        {
            "numbers": [1, 2, 3, 4, 5],
            "names": ["Alice", "Bob", "Charlie"]
        }
        """
        
        struct Container: Codable {
            let numbers: [Int]
            let names: [String]
        }
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = ReerJSONDecoder()
        
        let container = try decoder.decode(Container.self, from: jsonData)
        
        XCTAssertEqual(container.numbers, [1, 2, 3, 4, 5])
        XCTAssertEqual(container.names, ["Alice", "Bob", "Charlie"])
    }
    
    func testNestedObjectDecoding() throws {
        let jsonString = """
        {
            "user": {
                "name": "Jane",
                "age": 25
            },
            "active": true
        }
        """
        
        struct User: Codable {
            let name: String
            let age: Int
        }
        
        struct Response: Codable {
            let user: User
            let active: Bool
        }
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = ReerJSONDecoder()
        
        let response = try decoder.decode(Response.self, from: jsonData)
        
        XCTAssertEqual(response.user.name, "Jane")
        XCTAssertEqual(response.user.age, 25)
        XCTAssertEqual(response.active, true)
    }
    
    func testOptionalDecoding() throws {
        let jsonString = """
        {
            "name": "Alice",
            "age": null,
            "email": "alice@example.com"
        }
        """
        
        struct Person: Codable {
            let name: String
            let age: Int?
            let email: String?
        }
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = ReerJSONDecoder()
        
        let person = try decoder.decode(Person.self, from: jsonData)
        
        XCTAssertEqual(person.name, "Alice")
        XCTAssertNil(person.age)
        XCTAssertEqual(person.email, "alice@example.com")
    }
    
    func testComparisonWithFoundationDecoder() throws {
        let jsonString = """
        {
            "name": "Test",
            "value": 42,
            "items": [1, 2, 3]
        }
        """
        
        struct TestData: Codable {
            let name: String
            let value: Int
            let items: [Int]
        }
        
        let jsonData = jsonString.data(using: .utf8)!
        
        let reerDecoder = ReerJSONDecoder()
        let foundationDecoder = JSONDecoder()
        
        let reerResult = try reerDecoder.decode(TestData.self, from: jsonData)
        let foundationResult = try foundationDecoder.decode(TestData.self, from: jsonData)
        
        XCTAssertEqual(reerResult.name, foundationResult.name)
        XCTAssertEqual(reerResult.value, foundationResult.value)
        XCTAssertEqual(reerResult.items, foundationResult.items)
    }
}
