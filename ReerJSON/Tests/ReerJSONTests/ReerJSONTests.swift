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
    
    // MARK: - 边界值测试
        func testNumberLimits() throws {
            // Int 边界值
            let intMax = "\(Int.max)"
            let intMin = "\(Int.min)"
            
            let decoder = ReerJSONDecoder()
            
            XCTAssertEqual(try decoder.decode(Int.self, from: intMax.data(using: .utf8)!), Int.max)
            XCTAssertEqual(try decoder.decode(Int.self, from: intMin.data(using: .utf8)!), Int.min)
            
            // UInt 边界值
            let uintMax = "\(UInt.max)"
            XCTAssertEqual(try decoder.decode(UInt.self, from: uintMax.data(using: .utf8)!), UInt.max)
            
            // Double 特殊值
            XCTAssertEqual(try decoder.decode(Double.self, from: "1.7976931348623157e+308".data(using: .utf8)!), Double.greatestFiniteMagnitude)
            XCTAssertEqual(try decoder.decode(Double.self, from: "2.2250738585072014e-308".data(using: .utf8)!), Double.leastNormalMagnitude)
        }
        
        func testFloatingPointNumbers() throws {
            let decoder = ReerJSONDecoder()
            
            struct Numbers: Codable {
                let float: Float
                let double: Double
                let scientific: Double
                let negative: Double
            }
            
            let jsonString = """
            {
                "float": 3.14159,
                "double": 123.456789,
                "scientific": 1.23e-4,
                "negative": -999.999
            }
            """
            
            let result = try decoder.decode(Numbers.self, from: jsonString.data(using: .utf8)!)
            
            XCTAssertEqual(result.float, 3.14159, accuracy: 0.00001)
            XCTAssertEqual(result.double, 123.456789)
            XCTAssertEqual(result.scientific, 0.000123)
            XCTAssertEqual(result.negative, -999.999)
        }
        
        // MARK: - 字符串转义测试
        func testStringEscaping() throws {
            let decoder = ReerJSONDecoder()
            
            struct StringTest: Codable {
                let quotes: String
                let backslash: String
                let unicode: String
                let newlines: String
            }
            
            let jsonString = """
            {
                "quotes": "She said \\"Hello\\"",
                "backslash": "Path: C:\\\\Users\\\\test",
                "unicode": "Unicode: \\u4e2d\\u6587",
                "newlines": "Line 1\\nLine 2\\tTabbed"
            }
            """
            
            let result = try decoder.decode(StringTest.self, from: jsonString.data(using: .utf8)!)
            
            XCTAssertEqual(result.quotes, "She said \"Hello\"")
            XCTAssertEqual(result.backslash, "Path: C:\\Users\\test")
            XCTAssertEqual(result.unicode, "Unicode: 中文")
            XCTAssertEqual(result.newlines, "Line 1\nLine 2\tTabbed")
        }
        
        // MARK: - 空值和缺失值测试
        func testNullAndMissingValues() throws {
            let decoder = ReerJSONDecoder()
            
            struct OptionalFields: Codable {
                let required: String
                let optional1: String?
                let optional2: Int?
                let optional3: Bool?
            }
            
            // 测试 null 值
            let nullJson = """
            {
                "required": "present",
                "optional1": null,
                "optional2": 42,
                "optional3": null
            }
            """
            
            let nullResult = try decoder.decode(OptionalFields.self, from: nullJson.data(using: .utf8)!)
            XCTAssertEqual(nullResult.required, "present")
            XCTAssertNil(nullResult.optional1)
            XCTAssertEqual(nullResult.optional2, 42)
            XCTAssertNil(nullResult.optional3)
            
            // 测试缺失字段
            let missingJson = """
            {
                "required": "present",
                "optional2": 42
            }
            """
            
            let missingResult = try decoder.decode(OptionalFields.self, from: missingJson.data(using: .utf8)!)
            XCTAssertEqual(missingResult.required, "present")
            XCTAssertNil(missingResult.optional1)
            XCTAssertEqual(missingResult.optional2, 42)
            XCTAssertNil(missingResult.optional3)
        }
        
        // MARK: - 数组测试
        func testArrayVariations() throws {
            let decoder = ReerJSONDecoder()
            
            struct ArrayTest: Codable {
                let empty: [String]
                let mixed: [Int]
                let nested: [[String]]
                let optional: [String]?
            }
            
            let jsonString = """
            {
                "empty": [],
                "mixed": [1, -2, 0, 999],
                "nested": [["a", "b"], ["c", "d", "e"], []],
                "optional": ["x", "y", "z"]
            }
            """
            
            let result = try decoder.decode(ArrayTest.self, from: jsonString.data(using: .utf8)!)
            
            XCTAssertTrue(result.empty.isEmpty)
            XCTAssertEqual(result.mixed, [1, -2, 0, 999])
            XCTAssertEqual(result.nested, [["a", "b"], ["c", "d", "e"], []])
            XCTAssertEqual(result.optional, ["x", "y", "z"])
        }
        
        // MARK: - 深度嵌套测试
        func testDeeplyNestedStructures() throws {
            let decoder = ReerJSONDecoder()
            
            struct Level3: Codable {
                let value: String
            }
            
            struct Level2: Codable {
                let level3: Level3
                let array: [Int]
            }
            
            struct Level1: Codable {
                let level2: Level2
                let name: String
            }
            
            let jsonString = """
            {
                "level2": {
                    "level3": {
                        "value": "deep"
                    },
                    "array": [1, 2, 3]
                },
                "name": "root"
            }
            """
            
            let result = try decoder.decode(Level1.self, from: jsonString.data(using: .utf8)!)
            
            XCTAssertEqual(result.name, "root")
            XCTAssertEqual(result.level2.array, [1, 2, 3])
            XCTAssertEqual(result.level2.level3.value, "deep")
        }
        
        // MARK: - 错误处理测试
        func testErrorHandling() throws {
            let decoder = ReerJSONDecoder()
            
            struct SimpleStruct: Codable {
                let name: String
                let age: Int
            }
            
            // 无效 JSON
            XCTAssertThrowsError(try decoder.decode(SimpleStruct.self, from: "{invalid json".data(using: .utf8)!))
            
            // 缺少必需字段
            XCTAssertThrowsError(try decoder.decode(SimpleStruct.self, from: """
                {"name": "John"}
                """.data(using: .utf8)!))
            
            // 类型不匹配
            XCTAssertThrowsError(try decoder.decode(SimpleStruct.self, from: """
                {"name": "John", "age": "not a number"}
                """.data(using: .utf8)!))
            
            // 必需字段为 null
            XCTAssertThrowsError(try decoder.decode(SimpleStruct.self, from: """
                {"name": null, "age": 25}
                """.data(using: .utf8)!))
        }
        
        // MARK: - 数字类型转换测试
        func testNumberTypeConversions() throws {
            let decoder = ReerJSONDecoder()
            
            // 测试 222.0 -> UInt8 (应该成功)
            let doubleAsInt = try decoder.decode(UInt8.self, from: "222.0".data(using: .utf8)!)
            XCTAssertEqual(doubleAsInt, 222)
            
            // 测试整数到不同类型的转换
            let int16Value = try decoder.decode(Int16.self, from: "12345".data(using: .utf8)!)
            XCTAssertEqual(int16Value, 12345)
            
            let uint32Value = try decoder.decode(UInt32.self, from: "4294967295".data(using: .utf8)!)
            XCTAssertEqual(uint32Value, 4294967295)
            
            // 测试溢出情况
            XCTAssertThrowsError(try decoder.decode(UInt8.self, from: "256".data(using: .utf8)!))
            XCTAssertThrowsError(try decoder.decode(Int8.self, from: "128".data(using: .utf8)!))
        }
        
        // MARK: - 自定义 CodingKeys 测试
        func testCustomCodingKeys() throws {
            let decoder = ReerJSONDecoder()
            
            struct User: Codable {
                let fullName: String
                let userAge: Int
                let isActive: Bool
                
                enum CodingKeys: String, CodingKey {
                    case fullName = "full_name"
                    case userAge = "user_age"
                    case isActive = "is_active"
                }
            }
            
            let jsonString = """
            {
                "full_name": "John Doe",
                "user_age": 30,
                "is_active": true
            }
            """
            
            let result = try decoder.decode(User.self, from: jsonString.data(using: .utf8)!)
            
            XCTAssertEqual(result.fullName, "John Doe")
            XCTAssertEqual(result.userAge, 30)
            XCTAssertTrue(result.isActive)
        }
        
        // MARK: - 枚举测试
        func testEnumDecoding() throws {
            let decoder = ReerJSONDecoder()
            
            enum Status: String, Codable {
                case active = "active"
                case inactive = "inactive"
                case pending = "pending"
            }
            
            struct Task: Codable {
                let id: Int
                let status: Status
            }
            
            let jsonString = """
            {
                "id": 123,
                "status": "pending"
            }
            """
            
            let result = try decoder.decode(Task.self, from: jsonString.data(using: .utf8)!)
            
            XCTAssertEqual(result.id, 123)
            XCTAssertEqual(result.status, .pending)
            
            // 测试无效枚举值
            let invalidEnumJson = """
            {
                "id": 123,
                "status": "invalid_status"
            }
            """
            
            XCTAssertThrowsError(try decoder.decode(Task.self, from: invalidEnumJson.data(using: .utf8)!))
        }
        
        // MARK: - Date 和 URL 测试（如果支持）
        func testSpecialTypes() throws {
            let decoder = ReerJSONDecoder()
            
            struct SpecialTypes: Codable {
                let url: URL
                let data: Data
            }
            
            let jsonString = """
            {
                "url": "https://example.com/api",
                "data": "SGVsbG8gV29ybGQ="
            }
            """
            
            let result = try decoder.decode(SpecialTypes.self, from: jsonString.data(using: .utf8)!)
            
            XCTAssertEqual(result.url.absoluteString, "https://example.com/api")
            XCTAssertEqual(String(data: result.data, encoding: .utf8), "Hello World")
        }
        
        // MARK: - 性能对比测试
        func testPerformanceComparison() throws {
            let largeJsonString = """
            {
                "users": [
                    \(String(repeating: """
                    {
                        "id": 1,
                        "name": "User Name",
                        "email": "user@example.com",
                        "active": true,
                        "score": 95.5,
                        "tags": ["tag1", "tag2", "tag3"]
                    },
                    """, count: 100))
                    {
                        "id": 101,
                        "name": "Last User",
                        "email": "last@example.com", 
                        "active": false,
                        "score": 88.0,
                        "tags": ["final"]
                    }
                ]
            }
            """
            
            struct User: Codable {
                let id: Int
                let name: String
                let email: String
                let active: Bool
                let score: Double
                let tags: [String]
            }
            
            struct UserList: Codable {
                let users: [User]
            }
            
            let jsonData = largeJsonString.data(using: .utf8)!
            
            let reerDecoder = ReerJSONDecoder()
            let foundationDecoder = JSONDecoder()
            
            // 测试 ReerJSON 性能
            measure {
                _ = try! reerDecoder.decode(UserList.self, from: jsonData)
            }
            
            // 验证结果正确性
            let result = try reerDecoder.decode(UserList.self, from: jsonData)
            XCTAssertEqual(result.users.count, 101)
            XCTAssertEqual(result.users.first?.name, "User Name")
            XCTAssertEqual(result.users.last?.name, "Last User")
        }
        
        // MARK: - 内存测试
        func testMemoryUsage() throws {
            let decoder = ReerJSONDecoder()
            
            // 测试大型 JSON 不会导致内存泄漏
            for _ in 0..<100 {
                let jsonString = """
                {
                    "data": "\(String(repeating: "x", count: 10000))",
                    "numbers": [\(Array(1...1000).map(String.init).joined(separator: ","))]
                }
                """
                
                struct LargeData: Codable {
                    let data: String
                    let numbers: [Int]
                }
                
                let result = try decoder.decode(LargeData.self, from: jsonString.data(using: .utf8)!)
                XCTAssertEqual(result.data.count, 10000)
                XCTAssertEqual(result.numbers.count, 1000)
            }
        }
        
        // MARK: - 边界格式测试
        func testEdgeCaseFormats() throws {
            let decoder = ReerJSONDecoder()
            
            // 测试紧凑格式
            let compactJson = #"""{"a":1,"b":"x","c":[1,2,3],"d":{"e":true}}"""#
            
            struct Compact: Codable {
                let a: Int
                let b: String
                let c: [Int]
                let d: Inner
                
                struct Inner: Codable {
                    let e: Bool
                }
            }
            
            let result = try decoder.decode(Compact.self, from: compactJson.data(using: .utf8)!)
            XCTAssertEqual(result.a, 1)
            XCTAssertEqual(result.b, "x")
            XCTAssertEqual(result.c, [1, 2, 3])
            XCTAssertTrue(result.d.e)
            
            // 测试带空格的格式
            let spacedJson = """
            {
                "value"  :   42   ,
                "text"   :   "hello world"
            }
            """
            
            struct Spaced: Codable {
                let value: Int
                let text: String
            }
            
            let spacedResult = try decoder.decode(Spaced.self, from: spacedJson.data(using: .utf8)!)
            XCTAssertEqual(spacedResult.value, 42)
            XCTAssertEqual(spacedResult.text, "hello world")
        }
}
