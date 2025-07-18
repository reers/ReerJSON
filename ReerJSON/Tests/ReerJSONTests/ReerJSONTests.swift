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
        let jsonString = "222.0"
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = ReerJSONDecoder()
        
        let result = try decoder.decode(UInt8.self, from: jsonData)
        XCTAssertEqual(result, 222)
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
            "active": true,
            "score": 95.5,
            "age": 33
        }
        """
        
        struct Person: Codable {
            let name: String
            let active: Bool
            let score: Double
            let age: UInt8
        }
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = ReerJSONDecoder()
        
        let person = try decoder.decode(Person.self, from: jsonData)
        
        XCTAssertEqual(person.name, "John")
        XCTAssertEqual(person.active, true)
        XCTAssertEqual(person.score, 95.5)
        XCTAssertEqual(person.age, 33)
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
        
        /**
         // 编译器自动生成的 CodingKeys 枚举
             private enum CodingKeys: String, CodingKey {
                 case numbers = "numbers"
                 case names = "names"
             }
             
             // 编译器自动生成的 init(from decoder:) 方法
             init(from decoder: Decoder) throws {
                 let container = try decoder.container(keyedBy: CodingKeys.self)
                 
                 // 解码 numbers 属性
                 self.numbers = try container.decode([Int].self, forKey: .numbers)
                 
                 // 解码 names 属性
                 self.names = try container.decode([String].self, forKey: .names)
             }
             
             // 编译器自动生成的 encode(to encoder:) 方法
             func encode(to encoder: Encoder) throws {
                 var container = encoder.container(keyedBy: CodingKeys.self)
                 
                 try container.encode(self.numbers, forKey: .numbers)
                 try container.encode(self.names, forKey: .names)
             }
         */
        
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
            
            // 编译器自动生成的 CodingKeys 枚举
            private enum CodingKeys: String, CodingKey {
                case name = "name"
                case age = "age"
                case email = "email"
            }
            
            // 编译器自动生成的 init(from decoder:) 方法
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                // 必需属性使用 decode(_:forKey:)
                self.name = try container.decode(String.self, forKey: .name)
                
                // 可选属性使用 decodeIfPresent(_:forKey:)
                self.age = try container.decodeIfPresent(Int.self, forKey: .age)
                self.email = try container.decodeIfPresent(String.self, forKey: .email)
            }
            
            // 编译器自动生成的 encode(to encoder:) 方法
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(self.name, forKey: .name)
                try container.encodeIfPresent(self.age, forKey: .age)
                try container.encodeIfPresent(self.email, forKey: .email)
            }
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
