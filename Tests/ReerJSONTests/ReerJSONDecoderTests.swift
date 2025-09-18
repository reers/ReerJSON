//Copyright (c) 2018 Michael Eisel. All rights reserved.

import XCTest
@testable import ReerJSON

struct TestCodingKey: CodingKey {
    var stringValue: String

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    var intValue: Int? {
        return nil
    }

    init?(intValue: Int) {
        return nil
    }
}

extension DecodingError: Equatable {
    public static func == (lhs: DecodingError, rhs: DecodingError) -> Bool {
        switch lhs {
        case .typeMismatch(let lType, let lContext):
            if case let DecodingError.typeMismatch(rType, rContext) = rhs {
                return /*lType == rType && */rContext == lContext
            }
        case .valueNotFound(let lType, let lContext):
            if case let DecodingError.valueNotFound(rType, rContext) = rhs {
                return /*lType == rType && */rContext == lContext
            }
        case .keyNotFound(let lKey, let lContext):
            if case let DecodingError.keyNotFound(rKey, rContext) = rhs {
                return keysEqual(lKey, rKey) && rContext == lContext
            }
        case .dataCorrupted(let lContext):
            if case let DecodingError.dataCorrupted(rContext) = rhs {
                return rContext == lContext
            }
        @unknown default:
            return false
        }
        return false
    }
}

extension _CodingKey: Equatable {
    public static func == (lhs: _CodingKey, rhs: _CodingKey) -> Bool {
        return lhs.intValue == rhs.intValue && lhs.stringValue == rhs.stringValue
    }
}

func aKeysEqual(_ lhs: [CodingKey], _ rhs: [CodingKey]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    return zip(lhs, rhs).map { (l, r) -> Bool in
        return l.stringValue == r.stringValue || (l.intValue != nil && l.intValue == r.intValue)
    }.reduce(true) { $0 && $1 }
}

func keysEqual(_ lhs: CodingKey, _ rhs: CodingKey) -> Bool {
    return lhs.stringValue == rhs.stringValue || (lhs.intValue != nil && lhs.intValue == rhs.intValue)
}

public func testRoundTrip<T: Codable & Equatable>(_ object: T) {
    let data: Data = try! JSONEncoder().encode(object)
    let json = String(data: data, encoding: .utf8)!
    testRoundTrip(of: T.self, json: json)
}

func threadTime() -> CFTimeInterval {
    var tp: timespec = timespec()
    if #available(macOS 10.12, *) {
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &tp)
    } else {
        abort()
    }
    return Double(tp.tv_sec) + Double(tp.tv_nsec) / 1e9;
}

func time(_ closure: () -> ()) -> CFTimeInterval {
    let start = threadTime()
    //let _: Int = autoreleasepool {
        closure()
        //return 0
    //}
    let end = threadTime()
    return end - start
}

func averageTime(_ closure: () -> ()) -> CFTimeInterval {
    let count = 10
    var times: [CFTimeInterval] = []
    for _ in 0..<count {
        times.append(time(closure))
    }
    return times.dropFirst(count / 3).reduce(0, +) / CFTimeInterval(times.count)
}

func testPerf<T: Decodable>(appleDecoder: JSONDecoder, reerDecoder: ReerJSONDecoder, json: Data, type: T.Type) {
    let reerTime = averageTime {
        let _ = try! reerDecoder.decode(type, from: json)
    }
    let appleTime = averageTime {
        let _ = try! appleDecoder.decode(type, from: json)
    }
    XCTAssert(reerTime < appleTime / 3)
}

public func testRoundTrip<T>(of value: T.Type,
                              json: String,
                              outputFormatting: JSONEncoder.OutputFormatting = [],
                              dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
                              dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
                              dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64,
                              dataDecodingStrategy: JSONDecoder.DataDecodingStrategy = .base64,
                              keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
                              keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
                              nonConformingFloatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .throw,
                              nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw,
                              testPerformance: Bool = false) where T : Decodable, T : Equatable {
    do {
        
        let d = JSONDecoder()
        d.dateDecodingStrategy = dateDecodingStrategy
        d.dataDecodingStrategy = dataDecodingStrategy
        d.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
        d.keyDecodingStrategy = keyDecodingStrategy
        let apple = try d.decode(T.self, from: json.data(using: .utf8)!)
        
        let decoder = ReerJSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStrategy
        decoder.dataDecodingStrategy = dataDecodingStrategy
        decoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
        decoder.keyDecodingStrategy = keyDecodingStrategy
        let decoded = try decoder.decode(T.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(decoded, apple)
        if decoded == apple && testPerformance {
            testPerf(appleDecoder: d, reerDecoder: decoder, json: json.data(using: .utf8)!, type: T.self)
        }
    } catch {
        XCTFail("Failed to decode \(T.self) from JSON: \(error)")
    }
}

extension _CodingKey {
    fileprivate static func create(_ values: [StringOrInt]) -> [_CodingKey] {
        return values.map {
            if let i = $0 as? Int {
                return _CodingKey(intValue: i)!
            }
            return _CodingKey(stringValue: $0 as! String)!
        }
    }
}

protocol StringOrInt {
}

extension String: StringOrInt {}

extension Int: StringOrInt {}

extension CodingKey {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.stringValue == rhs.stringValue && lhs.intValue == rhs.intValue
    }
}

func pathsEqual(_ lPath: [CodingKey], _ rPath: [CodingKey]) -> Bool {
    return lPath.count == rPath.count && zip(lPath, rPath).allSatisfy { (a, b) in
        keysEqual(a, b)
    }
}

extension DecodingError.Context: Equatable {
    public static func == (lhs: DecodingError.Context, rhs: DecodingError.Context) -> Bool {
        let lPath = lhs.codingPath//.drop { $0.stringValue == "" && $0.intValue == nil }
        let rPath = rhs.codingPath//.drop { $0.stringValue == "" && $0.intValue == nil }
        let pathsEqual = lPath.count == rPath.count && zip(lPath, rPath).allSatisfy { (a, b) in
            keysEqual(a, b)
        }
        return pathsEqual// && lhs.debugDescription == rhs.debugDescription
    }
}

class ReerJSONTests: XCTestCase {
    let decoder = ReerJSONDecoder()
    lazy var base64Data = {
        return dataFromFile("base64.json")
    }()
    lazy var twitterData = {
        dataFromFile("twitter.json")
    }()
    lazy var canadaData = {
        self.dataFromFile("canada.json")
    }()

    func dataFromFile(_ file: String) -> Data {
    #if SWIFT_PACKAGE
        let path = Bundle.module.path(forResource: file, ofType: "")!
    #else
        let path = Bundle(for: type(of: self)).path(forResource: file, ofType: "")!
    #endif
        if let string = try? String(contentsOfFile: path) {
            return string.data(using: .utf8)!
        } else {
            return try! Data(contentsOf: URL(filePath: path))
        }
    }
    
	func testExceptionSafetyAroundObjectPool() {
		// https://github.com/michaeleisel/ReerJSON/issues/20
		struct Aa: Equatable & Decodable {
			let value: String
			enum Keys: String, CodingKey {
				case value
			}
			init(from decoder: Decoder) throws {
				let outer = try decoder.container(keyedBy: Keys.self)
				try autoreleasepool {
    				let _ = try decoder.container(keyedBy: _CodingKey.self)
				}
				if let _ = try? outer.decode(Bb.self, forKey: .value) {
					XCTFail()
					value = ""
				} else if let _ = try? outer.decode(Bb.self, forKey: .value) {
					XCTFail()
					value = ""
				} else {
					value = try outer.decode(String.self, forKey: .value)
				}
			}
		}
		
		struct Bb: Equatable & Decodable {
			let placeholder: String
			init(from decoder: Decoder) throws {
				let _ = try decoder.container(keyedBy: _CodingKey.self)
				placeholder = "bar"
			}
		}
		testRoundTrip(of: Aa.self, json: #"{"value": "foo"}"#)
	}

    func testData() {
        //let error = DecodingError.dataCorrupted(DecodingError.Context(codingPath: [_CodingKey(index: 0)], debugDescription: "Encountered Data is not valid Base64."))
        _testFailure(of: [Data].self, json: #"["😊"]"#)
    }
    
    func testVeryNestedArray() {
        testRoundTrip(of: [[[[[Int]]]]].self, json: #"[[[[[2]]]]]"#)
    }

    func assertEqualsApple<T: Codable & Equatable>(data: Data, type: T.Type) {
        let testDecoder = ReerJSONDecoder()
        let appleDecoder = JSONDecoder()
        let testObject = try! testDecoder.decode(type, from: data)
        let appleObject = try! appleDecoder.decode(type, from: data)
        XCTAssertEqual(appleObject, testObject)
    }
    
    func testNestedDecode() {
        struct Aa: Equatable & Codable {
            let a: [Int]
            let b: [Int]
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                var nestedContainer = try container.nestedUnkeyedContainer()
                self.a = [try nestedContainer.decode(Int.self)]
                self.b = [try container.decode(Int.self)]
            }
        }
        testRoundTrip(of: Aa.self, json: #"[[2], 3]"#)

        struct Bb: Equatable & Codable {
            let a: Int
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: _CodingKey.self)
                let nestedContainer = try container.nestedContainer(keyedBy: _CodingKey.self, forKey: _CodingKey(stringValue: "value")!)
                self.a = try nestedContainer.decode(Int.self, forKey: _CodingKey(stringValue: "inner")!)
            }
        }
        testRoundTrip(of: Bb.self, json: #"{"value": {"inner": 4}}"#)
    }
    
    func testJSONKey() {
        XCTAssertEqual(_CodingKey(intValue: 1), _CodingKey(stringValue: "1", intValue: 1))
    }
    
    func testCodingPath() {
        struct Zz: Equatable & Codable {
            init(from decoder: Decoder) throws {
                let expected: [CodingKey] = [_CodingKey(stringValue: "asdf")!, _CodingKey(index: 0)]
                XCTAssert(aKeysEqual(decoder.codingPath, expected))
            }
        }
        struct ZzContainer: Equatable & Codable {
            let asdf: [Zz]
        }
        testRoundTrip(of: ZzContainer.self, json: #"{"asdf": [{}]}"#)
        struct Aa: Equatable & Codable {
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: _CodingKey.self)
                XCTAssert(container.allKeys.count == 0)
                //XCTAssertEqual(container.codingPath.count, 0)
            }
        }
        testRoundTrip(of: Aa.self, json: "{}")
        
        struct Cc: Equatable & Codable {
            init(from decoder: Decoder) throws {
                for _ in 0..<3 {
                    let container = try decoder.container(keyedBy: _CodingKey.self)
                    let inner = try container.nestedContainer(keyedBy: _CodingKey.self, forKey: _CodingKey(stringValue: "inner")!)
                    XCTAssert(aKeysEqual(container.allKeys, [_CodingKey(stringValue: "inner")!]))
                    let path = [_CodingKey(stringValue: "inner")!]
                    let testPath = inner.codingPath
                    XCTAssert(aKeysEqual(testPath, path))
                }
            }
        }
        //testRoundTrip(of: Cc.self, json: #"{"inner": {"a": 2}}"#)
        
        struct Bb: Equatable & Codable {
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                let _ = try container.nestedUnkeyedContainer()
            }
        }
        //_testFailure(of: Bb.self, json: "[]")
    }

    func testMoreCodingPath() {
        struct Dd: Equatable & Codable {
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: _CodingKey.self)
                let emptyDict = try container.nestedContainer(keyedBy: _CodingKey.self, forKey: _CodingKey(stringValue: "emptyDict")!)
                let emptyArray = try container.nestedUnkeyedContainer(forKey: _CodingKey(stringValue: "emptyArray")!)
                XCTAssert(aKeysEqual(emptyDict.codingPath, _CodingKey.create(["emptyDict"])))
                // XCTAssert(aKeysEqual(emptyArray.codingPath, _CodingKey.create(["emptyArray"])))
                //XCTAssert(aKeysEqual(decoder.codingPath, []))
            }
        }
        // testRoundTrip(of: Dd.self, json: #"{"emptyDict": {}, "emptyArray": [], "dict": {"emptyNestedDict": {}, "emptyNestedArray": []}}"#)
    }
    
    func testArrayDecodeNil() {
        struct Aa: Equatable & Codable {
            let a: [Int?]
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                let _ = try container.decodeNil()
                self.a = [try container.decode(Int.self)]
            }
        }
        
        testRoundTrip(of: Aa.self, json: #"[1, 2]"#)
    }
    
    struct Example: Equatable, Codable {
        let key: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.key = (try? container.decode(String.self, forKey: .key)) ?? ""
        }
    }

    struct Example2: Equatable, Codable {
        let key: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let double = try? container.decode(Double.self, forKey: .key) {
                self.key = "\(double)"
            } else {
                self.key = try container.decode(String.self, forKey: .key)
            }
        }
    }
    
    func testStuff() {
        struct Aa: Decodable, Equatable {
            let a: [String: String]
        }
        // testRoundTrip(of: Aa.self, json: #"{"a": {}}"#)
        _testFailure(of: Aa.self, json: #"{"a": 2}"#)
    }
    
    func testNilAdvance() {
        struct Aa: Codable & Equatable {
            let a: Int
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                while try container.decodeNil() {
                }
                a = try container.decode(Int.self)
            }
        }
        testRoundTrip(of: Aa.self, json: #"[2]"#)
        testRoundTrip(of: Aa.self, json: #"[null, 2]"#)
        testRoundTrip(of: Aa.self, json: #"[null, null, 2]"#)
        _testFailure(of: Aa.self, json: #"[]"#)
        _testFailure(of: Aa.self, json: #"[null]"#)
    }
    
    func testURLError() {
        _testFailure(of: [URL].self, json: #"[""]"#)
    }

    func testOptionalInvalidValue() {
        testRoundTrip(of: Example.self, json: "{\"key\": 123}")
        testRoundTrip(of: Example2.self, json: "{\"key\": 123}")
        testRoundTrip(of: Example2.self, json: "{\"key\": \"123\"}")
    }

    func testRecursiveDecoding() {
        decoder.keyDecodingStrategy = .custom({ (keys) -> CodingKey in
            let recursiveDecoder = ReerJSONDecoder()
            let data: Data = keys.last!.stringValue.data(using: .utf8)!
            return TestCodingKey(stringValue: try! recursiveDecoder.decode(String.self, from: data))!
        })
    }
    
    func dateError(_ msg: String) -> DecodingError {
        let path = [_CodingKey(index: 0)]
        let context = DecodingError.Context(codingPath: path, debugDescription: msg)
        return DecodingError.dataCorrupted(context)
    }
    
    func testSuperDecoder() {
        struct Aa: Equatable, Codable {
            let a: Int
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                let superDecoder = try container.superDecoder()
                let superContainer = try superDecoder.singleValueContainer()
                self.a = try superContainer.decode(Int.self)
            }
        }

        testRoundTrip(of: Aa.self, json: "[2]")

        struct Bb: Equatable, Codable {
            let a: Int
            init(from decoder: Decoder) throws {
                var container = try decoder.container(keyedBy: _CodingKey.self)
                let superDecoder = try container.superDecoder()
                var superContainer = try superDecoder.unkeyedContainer()
                self.a = try superContainer.decode(Int.self)
            }
        }
        
        testRoundTrip(of: Bb.self, json: #"{"super": [2]}"#)
        
        struct Cc: Equatable, Codable {
            let a: Int
            init(from decoder: Decoder) throws {
                var container = try decoder.container(keyedBy: _CodingKey.self)
                let superDecoder = try container.superDecoder(forKey: _CodingKey(stringValue: "foo")!)
                var superContainer = try superDecoder.unkeyedContainer()
                self.a = try superContainer.decode(Int.self)
            }
        }

        testRoundTrip(of: Cc.self, json: #"{"foo": [2]}"#)
    }
    
    func testOther() {
        struct Aa: Codable & Equatable {
            let a: Int
        }
        _testFailure(of: Aa.self, json: #"{}"#)
        struct Bb: Codable & Equatable {
            let a: Int
            init(from decoder: Decoder) throws {
                let c1 = try decoder.container(keyedBy: _CodingKey.self)
                let c2 = try c1.nestedContainer(keyedBy: _CodingKey.self, forKey: _CodingKey(stringValue: "a")!)
                let c3 = try c2.nestedContainer(keyedBy: _CodingKey.self, forKey: _CodingKey(stringValue: "b")!)
                let c4 = try c3.nestedContainer(keyedBy: _CodingKey.self, forKey: _CodingKey(stringValue: "c")!)
                a = try c4.decode(Int.self, forKey: _CodingKey(stringValue: "d")!)
            }
        }
        testRoundTrip(of: Bb.self, json: #"{"a": {"b": {"c": {"d": 2}}}}"#)
        _testFailure(of: Bb.self, json: #"{"a": {"b": {"c": {"d": false}}}}"#, relaxedErrorCheck: true)
        struct Cc: Codable & Equatable {
            let a: Int
            init(from decoder: Decoder) throws {
                let c1 = try decoder.container(keyedBy: _CodingKey.self)
                let c2 = try c1.nestedContainer(keyedBy: _CodingKey.self, forKey: _CodingKey(stringValue: "a")!)
                let c3 = try c2.nestedContainer(keyedBy: _CodingKey.self, forKey: _CodingKey(stringValue: "b")!)
                let c4 = try c3.nestedContainer(keyedBy: _CodingKey.self, forKey: _CodingKey(stringValue: "c")!)
                var c5 = try c4.nestedUnkeyedContainer(forKey: _CodingKey(stringValue: "d")!)
                let c6 = try c5.nestedContainer(keyedBy: _CodingKey.self)
                var c7 = try c6.nestedUnkeyedContainer(forKey: _CodingKey(stringValue: "e")!)
                a = try c7.decode(Int.self)
            }
        }
        testRoundTrip(of: Cc.self, json: #"{"a": {"b": {"c": {"d": [{"e": [2]}]}}}}"#)
        _testFailure(of: Cc.self, json: #"{"a": {"b": {"c": {"d": [{"e": [false]}]}}}}"#, relaxedErrorCheck: true)
        /*let count: Int = Int(UInt32.max) + 1
        let d = Data(count: count)
        try! ReerJSONDecoder().decode(Cc.self, from: d)*/
    }

    func testJSONKeyCleanupMemorySafe() {
        class Holder {
            var path: [CodingKey]? = nil
            init() {
            }
        }
        struct Aa: Codable & Equatable {
            let b: Bb
        }
        struct Bb: Codable & Equatable {
            let c: Int
            init(from decoder: Decoder) {
                let holder = (decoder.userInfo[CodingUserInfoKey(rawValue: "key")!]) as! Holder
                holder.path = decoder.codingPath
                c = 0
            }
        }
        let holder = Holder()
        autoreleasepool {
            let decoder = ReerJSONDecoder()
            decoder.userInfo[CodingUserInfoKey(rawValue: "key")!] = holder
            let json = #"{"b": 1}"#.data(using: .utf8)!
            let _ = try! decoder.decode(Aa.self, from: json)
        }
        let _ = holder.path![0].stringValue
    }

    func testJSONKeyCleanupThreadSafe() {
        struct Aa: Codable & Equatable {
            let b: Bb
        }
        struct Bb: Codable & Equatable {
            let c: Cc
        }
        struct Cc: Codable & Equatable {
            enum Key: String, CodingKey{
                case one
                case two
            }
            let i: Int
            init(from decoder: Decoder) throws {
                let codingPath = decoder.codingPath
                DispatchQueue.global(qos: .userInteractive).async {
                    let _ = codingPath[0].stringValue
                    let keys = _CodingKey.create(["b", "c"])
                    if !pathsEqual(codingPath, keys) {
                        abort()
                    }
                }
                i = try decoder.singleValueContainer().decode(Int.self)
                let _ = codingPath[0].stringValue
            }
        }
        {
            let decoder = ReerJSONDecoder()
            let json = #"{"b": {"c": 2}}"#.data(using: .utf8)!
            let _ = try! decoder.decode(Aa.self, from: json)
        }()
        usleep(50000)
    }

    func testInvalidDates() {
        let secondsError = dateError("Expected double/float but found Bool instead.")
        testRoundTrip(of: [Date].self, json: "[23908742398047]", dateDecodingStrategy: .secondsSince1970)
        _testFailure(of: [Date].self, json: "[false]", expectedError: secondsError, dateDecodingStrategy: .secondsSince1970)
        
        let millisError = dateError("Expected double/float but found Bool instead.")
        testRoundTrip(of: [Date].self, json: "[23908742398047]", dateDecodingStrategy: .millisecondsSince1970)
        _testFailure(of: [Date].self, json: "[false]", expectedError: millisError, dateDecodingStrategy: .millisecondsSince1970)

        let error = dateError("Expected date string to be ISO8601-formatted.")
        let typeError = DecodingError.typeMismatch(Any.self, DecodingError.Context(codingPath: _CodingKey.create([0]), debugDescription: "Expected to decode PKc but found Number instead."))

        testRoundTrip(of: [Date].self, json: #"["2016-06-13T16:00:00+00:00"]"#, dateDecodingStrategy: .iso8601)
        _testFailure(of: [Date].self, json: "[23908742398047]", expectedError: typeError, dateDecodingStrategy: .iso8601)
      _testFailure(of: [Date].self, json: #"["23908742398047"]"#, relaxedErrorCheck: true, expectedError: error, dateDecodingStrategy: .iso8601)
        
        testRoundTrip(of: [Date].self, json: #"["1992"]"#, dateDecodingStrategy: .custom({ _ -> Date in
            return Date(timeIntervalSince1970: 0)
        }))
        _testFailure(of: [Date].self, json: "[23908742398047]", expectedError: error, dateDecodingStrategy: .custom({ _ -> Date in
            throw error
        }))
        
        let formatter = DateFormatter()
        let formatterError = dateError("Date string does not match format expected by formatter.")
        formatter.dateFormat = "yyyy"
        testRoundTrip(of: [Date].self, json: #"["1992"]"#, dateDecodingStrategy: .formatted(formatter))
        _testFailure(of: [Date].self, json: #"["March"]"#, expectedError: formatterError, dateDecodingStrategy: .formatted(formatter))
        _testFailure(of: [Date].self, json: "[23423423]", expectedError: typeError, dateDecodingStrategy: .formatted(formatter))
    }

    func testDefaultFloatStrings() {
        _testFailure(of: [Float].self, json: #"[""]"#)
    }

  func testLesserUsedFunctions() {
    struct NestedArrayMember: Codable, Equatable {
      let a: Int
    }
    struct Test: Codable, Equatable {
      let nestedArray: [NestedArrayMember]
      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _CodingKey.self)
        var unkeyedContainer = try container.nestedUnkeyedContainer(forKey: _CodingKey(stringValue: "array")!)
        let nestedArrayMember = try unkeyedContainer.decode(NestedArrayMember.self)
        nestedArray = [nestedArrayMember]
      }
    }

    testRoundTrip(of: Test.self, json: #"{"array": [{"a": 3}]}"#)
  }

    func _testFailure<T>(of value: T.Type,
                           json: String,
                           relaxedErrorCheck: Bool = false,
                           expectedError: Error? = nil,
                           outputFormatting: JSONEncoder.OutputFormatting = [],
                           dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
                           dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
                           dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64,
                           dataDecodingStrategy: JSONDecoder.DataDecodingStrategy = .base64,
                           keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
                           keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
                           nonConformingFloatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .throw,
                           nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw) where T : Decodable, T : Equatable {
        let decoder = ReerJSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStrategy
        decoder.dataDecodingStrategy = dataDecodingStrategy
        decoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
        decoder.keyDecodingStrategy = keyDecodingStrategy
        var reerErrorMaybe: DecodingError?
        do {
            let _ = try decoder.decode(T.self, from: json.data(using: .utf8)!)
            XCTFail()
        } catch {
            reerErrorMaybe = error as? DecodingError
        }
        guard let reerError = reerErrorMaybe else {
            XCTFail()
            return
        }
        do {
            let d = JSONDecoder()
            d.dateDecodingStrategy = dateDecodingStrategy
            d.dataDecodingStrategy = dataDecodingStrategy
            d.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
            d.keyDecodingStrategy = keyDecodingStrategy
            let _ = try d.decode(T.self, from: json.data(using: .utf8)!)
        } catch {
            guard let appleError = error as? DecodingError else {
                XCTFail()
                return
            }
            if !relaxedErrorCheck {
                XCTAssertEqual(appleError, reerError)
            }
            return
        }
        XCTFail()
    }

    func testDictionaryStuff() {
        struct Test: Codable, Equatable {
            let a: Bool
        }
        testRoundTrip(of: Test.self, json: #"{"a": true}"#)
        testRoundTrip(of: TopLevelWrapper<Test>.self, json: #"{"value": {"a": true}}"#)
        _testFailure(of: Test.self, json: #"{"b": true}"#, expectedError: DecodingError.keyNotFound(_CodingKey(stringValue: "a")!, DecodingError.Context(codingPath: [], debugDescription: "No value associated with a.")))
        _testFailure(of: Test.self, json: #"{}"#, expectedError: DecodingError.keyNotFound(_CodingKey(stringValue: "a")!, DecodingError.Context(codingPath: [], debugDescription: "No value associated with a.")))
        _testFailure(of: TopLevelWrapper<Test>.self, json: #"{"value": {}}"#, expectedError: DecodingError.keyNotFound(_CodingKey(stringValue: "a")!, DecodingError.Context(codingPath: [], debugDescription: "No value associated with a.")))
        _testFailure(of: TopLevelWrapper<Test>.self, json: #"{"value": {"b": true}}"#, expectedError: nil) //DecodingError.keyNotFound(_CodingKey(stringValue: "a")!, DecodingError.Context(codingPath: [_CodingKey(stringValue: "value")!], debugDescription: "No value associated with a.")))
    }

    func testNestedDecoding() {
        struct Test: Codable, Equatable {
            init(from decoder: Decoder) throws {
                if (try! ReerJSONDecoder().decode([Int].self, from: "[1]".data(using: .utf8)!) != [1]) {
                    abort()
                }
            }
        }
        testRoundTrip(of: Test.self, json: "{}")
    }

    func testEmptyString() {
        _testFailure(of: [Int].self, json: "", expectedError: DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "The given data was not valid JSON. Error: Empty")))
    }
    
    func testArrayStuff() {
        struct Test: Codable, Equatable {
            let a: Bool
            let b: Bool

            init(a: Bool, b: Bool) {
                self.a = a
                self.b = b
            }

            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                a = try container.decode(Bool.self)
                b = try container.decode(Bool.self)
            }
        }

        // Goes past the end
        _testFailure(of: Test.self, json: "[true]", expectedError: DecodingError.valueNotFound(Any.self, DecodingError.Context(codingPath: [_CodingKey(index: 0)], debugDescription: "Cannot get next value -- unkeyed container is at end.")))
        _testFailure(of: Test.self, json: "[]", expectedError: DecodingError.valueNotFound(Any.self, DecodingError.Context(codingPath: [], debugDescription: "Cannot get next value -- unkeyed container is at end.")))
        _testFailure(of: TopLevelWrapper<Test>.self, json: #"{"value": [true]}"#, expectedError: DecodingError.valueNotFound(Any.self, DecodingError.Context(codingPath: [_CodingKey(stringValue: "value")!, _CodingKey(index: 0)], debugDescription: "Cannot get next value -- unkeyed container is at end.")))
        _testFailure(of: TopLevelWrapper<Test>.self, json: #"{"value": []}"#, expectedError: DecodingError.valueNotFound(Any.self, DecodingError.Context(codingPath: [_CodingKey(stringValue: "value")!], debugDescription: "Cannot get next value -- unkeyed container is at end.")))
        // Left over
        testRoundTrip(of: Test.self, json: "[false, true, false]")
        // Normals
        testRoundTrip(of: Test.self, json: "[false, true]")
        testRoundTrip(of: [[[[Int]]]].self, json: "[[[[]]]]")
        testRoundTrip(of: [[[[Int]]]].self, json: "[[[[2, 3]]]]")
        testRoundTrip(of: [Bool].self, json: "[false, true]")
        _testFailure(of: [Int].self, json: #"{"a": 1}"#, expectedError: DecodingError.typeMismatch([Any].self, DecodingError.Context(codingPath: [], debugDescription: "Tried to unbox array, but it wasn\'t an array")))
    }

    func testInvalidJSON() {
        _testFailure(of: [Int].self, json: "{a: 255}", expectedError: DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "The given data was not valid JSON. Error: Something went wrong while writing to the tape")))
        _testFailure(of: [Int].self, json: #"{"key: "yes"}"#, expectedError: DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "The given data was not valid JSON. Error: Something went wrong while writing to the tape")))
    }
    
    func testRawValuePassedAsJson() {
        testRoundTrip(of: Bool.self, json: "false")
        testRoundTrip(of: Bool.self, json: #"true"#)
        testRoundTrip(of: Int.self, json: "82")
        _testFailure(of: Int.self, json: "82.1")
        testRoundTrip(of: Double.self, json: "82.1")
        testRoundTrip(of: String.self, json: #""test""#)
        _testFailure(of: Int.self, json: #"undefined"#)
    }

    func testMultipleRefsToSameDecoder() {
        struct Aa: Codable, Equatable {
            let value: Int
            init(from decoder: Decoder) throws {
                var c1 = try decoder.unkeyedContainer()
                var c2 = try decoder.unkeyedContainer()
                // Get c1 to skip ahead
                let _ = try c1.decode(Int.self)
                value = try c2.decode(Int.self)
            }
        }
        testRoundTrip(of: Aa.self, json: "[20]")
    }

    func testInts() {
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            testRoundTrip(of: Int128.self, json: "\(Int128.max)")
            testRoundTrip(of: UInt128.self, json: "\(UInt128.max)")
            _testFailure(of: Int128.self, json: "\(UInt128.max)")
            testRoundTrip(of: [Int128].self, json: "[\(Int128.max)]")
            testRoundTrip(of: [Int128].self, json: "[\(Int128.min)]")
            testRoundTrip(of: [UInt128].self, json: "[\(UInt128.max)]")
        }
        testRoundTrip(of: UInt64.self, json: "\(UInt64.max)")
        _testFailure(of: Int64.self, json: "\(UInt64.max)")
        
        testRoundTrip(of: Int64.self, json: "\(Int64.max)")
        testRoundTrip(of: UInt64.self, json: "\(UInt64.max)")
        _testFailure(of: Int64.self, json: "\(UInt64.max)")
        testRoundTrip(of: Double.self, json: "\(Int64.max)")
        testRoundTrip(of: Double.self, json: "\(UInt64.max)")
        testRoundTrip(of: UInt64.self, json: "\(UInt64.max)")
        testRoundTrip(of: [Int8].self, json: "[127]")
        testRoundTrip(of: [UInt8].self, json: "[255]")
      _testFailure(of: [UInt8].self, json: "[256]", relaxedErrorCheck: true, expectedError: DecodingError.dataCorrupted(DecodingError.Context(codingPath: [_CodingKey(index: 0)], debugDescription: "Parsed JSON number 256 does not fit.")))
      _testFailure(of: [UInt8].self, json: "[-1]", relaxedErrorCheck: true, expectedError: DecodingError.dataCorrupted(DecodingError.Context(codingPath: [_CodingKey(index: 0)], debugDescription: "Parsed JSON number -1 does not fit.")))
        testRoundTrip(of: [Int64].self, json: "[\(Int64.max)]")
        testRoundTrip(of: [Int64].self, json: "[\(Int64.min)]")
        testRoundTrip(of: [UInt64].self, json: "[\(UInt64.max)]")
    }

    func testDifferentTypes() {
        struct Test: Codable, Equatable {
            let i8: Int8
            let i16: Int16
            let i32: Int32
            let i64: Int64
            let u8: UInt8
            let u16: UInt16
            let u32: UInt32
            let u64: UInt64
            let u: UInt64
            let i: Int
        }
        let expected = Test(i8: 1, i16: 2, i32: 3, i64: 4, u8: 5, u16: 6, u32: 7, u64: 8, u: 9, i: 10)
        testRoundTrip(of: Test.self, json: #"{"u8": 1, "u16": 2, "u32": 3, "u64": 4, "i8": 5, "i16": 6, "i32": 7, "i64": 8, "u": 9, "i": 10}"#)
    }

    func testAllKeys() {
        struct Test: Codable {
            let keys: [String]
            init(from decoder: Decoder) throws {
                let container = try! decoder.container(keyedBy: _CodingKey.self)
                keys = container.allKeys.map { $0.stringValue }
            }
        }
        let test = try! ReerJSONDecoder().decode(Test.self, from: #"{"a": 1, "b": 2}"#.data(using: .utf8)!)
        XCTAssertTrue(test.keys == ["a", "b"] || test.keys == ["b", "a"])
    }

    func testDoubleParsing() {
        testRoundTrip(of: [Double].self, json: "[0.0]")
        testRoundTrip(of: [Double].self, json: "[0.0000]")
        testRoundTrip(of: [Double].self, json: "[-0.0]")
        testRoundTrip(of: [Double].self, json: "[1.0]")
        testRoundTrip(of: [Double].self, json: "[1.11111]")
        testRoundTrip(of: [Double].self, json: "[1.11211e-2]")
        testRoundTrip(of: [Double].self, json: "[1.11211e200]")
    }

    // Run with tsan
    func testConcurrentUsage() {
        let d = ReerJSONDecoder()
        let testResult = try! d.decode(Twitter.self, from: twitterData)
        var value: Int32 = 0
        for _ in 0..<100 {
            DispatchQueue.global(qos: .userInteractive).async {
                assert(testResult == (try! d.decode(Twitter.self, from: self.twitterData)))
                OSAtomicIncrement32(&value)
            }
        }
        while value < 100 {
            usleep(UInt32(1e5))
        }
    }

    func testCodingKeys() {
        struct Test: Codable, Equatable {
            let a: Int
            let c: Int

            enum CodingKeys: String, CodingKey {
                case a = "b"
                case c
            }
        }

        testRoundTrip(of: Test.self, json: #"{"b": 1, "c": 2}"#)
    }
    
    func testSuppressWarnings() {
        struct Aa: Decodable {
            init(from decoder: Decoder) throws {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: ""))
            }
        }
        XCTAssertThrowsError(try ReerJSONDecoder().decode(Aa.self, from: "{5345893478957345903475890734}".data(using: .utf8)!))
        testRoundTrip([UInt64.max])
        testRoundTrip([UInt64.max])
    }

    func testDecimal() {
        let decimals: [Decimal] = ["1.2", "1", "0.0000000000000000000000000000001", "-1", "745612491641.4614612344632"].map { (numberString: String) -> Decimal in
            return Decimal(string: numberString)!
        }
        testRoundTrip(decimals)
        
        _testFailure(of: [Decimal].self, json: "[true]", expectedError: DecodingError.dataCorrupted(DecodingError.Context(codingPath: [_CodingKey(index: 0)], debugDescription: "Invalid Decimal")))
    }

    func testNull() {
        struct Test: Codable, Equatable {
            let a: Int?
        }
        testRoundTrip(of: Test.self, json: #"{"a": null}"#)
    }

    func run<T: Codable & Equatable>(_ filename: String, _ type: T.Type, keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys, dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate) {
        let json = dataFromFile(filename + ".json")
        testRoundTrip(of: type, json: String(data: json, encoding: .utf8)!,
                      dateDecodingStrategy: dateDecodingStrategy, testPerformance: false)
    }

    func testArrayTypes() {
        struct Test: Codable, Equatable {
            init(from decoder: Decoder) throws {
                var c = try! decoder.unkeyedContainer()
                a = try! c.decode(Int8.self)
                b = try! c.decode(Int16.self)
                cc = try! c.decode(Int32.self)
                d = try! c.decode(Int64.self)
                e = try! c.decode(Int.self)
                f = try! c.decode(UInt8.self)
                g = try! c.decode(UInt16.self)
                h = try! c.decode(UInt32.self)
                i = try! c.decode(UInt64.self)
                j = try! c.decode(UInt.self)
                k = try! c.decode(Float.self)
                l = try! c.decode(Double.self)
            }
            let a: Int8
            let b: Int16
            let cc: Int32
            let d: Int64
            let e: Int
            let f: UInt8
            let g: UInt16
            let h: UInt32
            let i: UInt64
            let j: UInt
            let k: Float
            let l: Double
        }
        testRoundTrip(of: Test.self, json: "[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]")
    }

    func testRealJsons() {
        run("apache_builds", ApacheBuilds.self)
        run("random", random.self)
        run("mesh", mesh.self)
        run("canada", canada.self)
        run("github_events", ghEvents.self, dateDecodingStrategy: .iso8601)
        run("twitter", Twitter.self, keyDecoding: .convertFromSnakeCase)
        run("twitterescaped", Twitter.self)
    }
    
    // MARK: - PreTransformKeyedDecodingContainer Tests
    
    func testPreTransformKeyedDecodingContainerSnakeCase() {
        struct SnakeCaseTest: Codable, Equatable {
            let firstName: String
            let lastName: String
            let userAge: Int
            let isActive: Bool
            let phoneNumber: String?
            let emailAddress: String
            let homeAddress: Address
            let workInfo: WorkInfo
            
            // 添加更多可选属性用于测试 decodeIfPresent
            let middleName: String?
            let alternateEmail: String?
            let userScore: Int?
            let isPremium: Bool?
            let accountBalance: Double?
            let lastLoginTime: Float?
            let profilePicture: Data?
            let websiteUrl: URL?
            let birthDate: Date?
            
            struct Address: Codable, Equatable {
                let streetName: String
                let cityName: String
                let zipCode: String
                let apartmentNumber: String?  // 可选属性
                let buildingFloor: Int?       // 可选属性
            }
            
            struct WorkInfo: Codable, Equatable {
                let companyName: String
                let jobTitle: String
                let startDate: String
                let endDate: String?          // 可选属性
                let monthlySalary: Double?    // 可选属性
                let isRemote: Bool?           // 可选属性
            }
        }
        
        let json = """
        {
            "first_name": "John",
            "last_name": "Doe",
            "user_age": 30,
            "is_active": true,
            "phone_number": "123-456-7890",
            "email_address": "john@example.com",
            "home_address": {
                "street_name": "Main St",
                "city_name": "New York",
                "zip_code": "10001",
                "apartment_number": "4B",
                "building_floor": null
            },
            "work_info": {
                "company_name": "Tech Corp",
                "job_title": "Engineer",
                "start_date": "2020-01-01",
                "monthly_salary": 8500.50,
                "is_remote": true
            },
            "middle_name": null,
            "user_score": 95,
            "is_premium": false,
            "account_balance": 1250.75,
            "last_login_time": 3.14159,
            "profile_picture": "SGVsbG8gV29ybGQ=",
            "website_url": "https://johndoe.dev",
            "birth_date": 631152000
        }
        """
        
        testRoundTrip(of: SnakeCaseTest.self, json: json, dateDecodingStrategy: .secondsSince1970, dataDecodingStrategy: .base64, keyDecodingStrategy: .convertFromSnakeCase)
    }
    
    func testPreTransformKeyedDecodingContainerCustomStrategy() {
        struct CustomKeyTest: Codable, Equatable {
            let userName: String
            let userEmail: String
            let userAge: Int
            let isAdmin: Bool
            
            // 添加可选属性测试 decodeIfPresent
            let userNickname: String?
            let userPhone: String?
            let userScore: Int?
            let isVerified: Bool?
            let userRating: Double?
            let lastSeen: Float?
            let avatarData: Data?
            let profileUrl: URL?
            
            enum CodingKeys: String, CodingKey {
                case userName = "user_name"
                case userEmail = "user_email"
                case userAge = "user_age"
                case isAdmin = "is_admin"
                case userNickname = "user_nickname"
                case userPhone = "user_phone"
                case userScore = "user_score"
                case isVerified = "is_verified"
                case userRating = "user_rating"
                case lastSeen = "last_seen"
                case avatarData = "avatar_data"
                case profileUrl = "profile_url"
            }
        }
        
        let json = """
        {
            "USER_NAME": "alice",
            "USER_EMAIL": "alice@example.com",
            "USER_AGE": 25,
            "IS_ADMIN": false,
            "USER_NICKNAME": "Ali",
            "USER_SCORE": 88,
            "IS_VERIFIED": null,
            "USER_RATING": 4.7,
            "LAST_SEEN": 1.23,
            "AVATAR_DATA": "dGVzdCBkYXRh",
            "PROFILE_URL": "https://alice.dev"
        }
        """
        
        // Custom strategy: convert UPPER_CASE to snake_case
        let customStrategy: JSONDecoder.KeyDecodingStrategy = .custom { keys in
            let key = keys.last!
            let upperKey = key.stringValue
            let lowerKey = upperKey.lowercased()
            return _CodingKey(stringValue: lowerKey)!
        }
        
        testRoundTrip(of: CustomKeyTest.self, json: json, dataDecodingStrategy: .base64, keyDecodingStrategy: customStrategy)
    }
    
    func testPreTransformKeyedDecodingContainerCustomStrategyWithPath() {
        struct PathTest: Codable, Equatable {
            let value: String
            let nested: NestedData
            
            struct NestedData: Codable, Equatable {
                let innerValue: String
            }
        }
        
        let json = """
        {
            "VALUE": "test",
            "NESTED": {
                "INNER_VALUE": "nested_test"
            }
        }
        """
        
        // Custom strategy that converts all keys to lowercase and handles underscores
        let customStrategy: JSONDecoder.KeyDecodingStrategy = .custom { keys in
            let key = keys.last!
            let originalKey = key.stringValue
            
            // Always convert to lowercase first, then handle underscores
            let lowerKey = originalKey.lowercased()
            let components = lowerKey.split(separator: "_")
            if components.count > 1 {
                let camelCase = String(components[0]) + components[1...].map { $0.capitalized }.joined()
                return _CodingKey(stringValue: camelCase)!
            }
            return _CodingKey(stringValue: lowerKey)!
        }
        
        let decoder = ReerJSONDecoder()
        decoder.keyDecodingStrategy = customStrategy
        
        let result = try! decoder.decode(PathTest.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(result.value, "test")
        XCTAssertEqual(result.nested.innerValue, "nested_test")
    }
    
    func testPreTransformKeyedDecodingContainerErrorHandling() {
        struct ErrorTest: Codable, Equatable {
            let requiredField: String
            let optionalField: String?
        }
        
        // Test missing required key
        let missingKeyJson = """
        {
            "optional_field": "present"
        }
        """
        
        let decoder = ReerJSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let _ = try decoder.decode(ErrorTest.self, from: missingKeyJson.data(using: .utf8)!)
            XCTFail("Should have thrown an error for missing required key")
        } catch let error as DecodingError {
            if case .keyNotFound(let key, let context) = error {
                XCTAssertEqual(key.stringValue, "requiredField")
                XCTAssertTrue(context.debugDescription.contains("requiredField"))
            } else {
                XCTFail("Expected keyNotFound error, got \(error)")
            }
        } catch {
            XCTFail("Expected DecodingError, got \(error)")
        }
        
        // Test type mismatch
        let typeMismatchJson = """
        {
            "required_field": 123,
            "optional_field": "valid"
        }
        """
        
        do {
            let _ = try decoder.decode(ErrorTest.self, from: typeMismatchJson.data(using: .utf8)!)
            XCTFail("Should have thrown an error for type mismatch")
        } catch let error as DecodingError {
            if case .typeMismatch(let type, let context) = error {
                XCTAssertTrue(type == String.self)
                XCTAssertEqual(context.codingPath.first?.stringValue, "requiredField")
            } else {
                XCTFail("Expected typeMismatch error, got \(error)")
            }
        } catch {
            XCTFail("Expected DecodingError, got \(error)")
        }
    }
    
    func testPreTransformKeyedDecodingContainerNullHandling() {
        struct NullTest: Codable, Equatable {
            let requiredField: String
            let optionalField: String?
            let explicitNull: String?
        }
        
        let nullJson = """
        {
            "required_field": "value",
            "optional_field": null,
            "explicit_null": null
        }
        """
        
        let decoder = ReerJSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let result = try! decoder.decode(NullTest.self, from: nullJson.data(using: .utf8)!)
        XCTAssertEqual(result.requiredField, "value")
        XCTAssertNil(result.optionalField)
        XCTAssertNil(result.explicitNull)
        
        // Test decodeNil
        struct NilCheckTest: Codable, Equatable {
            let value: String?
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if try container.decodeNil(forKey: .value) {
                    self.value = nil
                } else {
                    self.value = try container.decode(String.self, forKey: .value)
                }
            }
            
            enum CodingKeys: String, CodingKey {
                case value
            }
        }
        
        let nilCheckJson = """
        {
            "value": null
        }
        """
        
        let nilResult = try! decoder.decode(NilCheckTest.self, from: nilCheckJson.data(using: .utf8)!)
        XCTAssertNil(nilResult.value)
    }
    
    func testPreTransformKeyedDecodingContainerNestedContainers() {
        struct NestedTest: Codable, Equatable {
            let userInfo: UserInfo
            let preferences: [String]
            let metadata: [String: String]
            
            struct UserInfo: Codable, Equatable {
                let personalData: PersonalData
                let workData: WorkData
                
                struct PersonalData: Codable, Equatable {
                    let fullName: String
                    let birthDate: String
                }
                
                struct WorkData: Codable, Equatable {
                    let companyName: String
                    let jobTitle: String
                }
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                // Test nested keyed container
                self.userInfo = try container.decode(UserInfo.self, forKey: .userInfo)
                
                // Test nested unkeyed container
                var prefsContainer = try container.nestedUnkeyedContainer(forKey: .preferences)
                var preferences: [String] = []
                while !prefsContainer.isAtEnd {
                    preferences.append(try prefsContainer.decode(String.self))
                }
                self.preferences = preferences
                
                // Test nested keyed container for dictionary
                let metadataContainer = try container.nestedContainer(keyedBy: _CodingKey.self, forKey: .metadata)
                var metadata: [String: String] = [:]
                for key in metadataContainer.allKeys {
                    metadata[key.stringValue] = try metadataContainer.decode(String.self, forKey: key)
                }
                self.metadata = metadata
            }
        }
        
        let json = """
        {
            "user_info": {
                "personal_data": {
                    "full_name": "John Doe",
                    "birth_date": "1990-01-01"
                },
                "work_data": {
                    "company_name": "Tech Corp",
                    "job_title": "Engineer"
                }
            },
            "preferences": ["dark_mode", "notifications", "auto_save"],
            "metadata": {
                "lastUpdated": "system",
                "createdBy": "2024-01-01"
            }
        }
        """
        
        let decoder = ReerJSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let result = try! decoder.decode(NestedTest.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(result.userInfo.personalData.fullName, "John Doe")
        XCTAssertEqual(result.userInfo.personalData.birthDate, "1990-01-01")
        XCTAssertEqual(result.userInfo.workData.companyName, "Tech Corp")
        XCTAssertEqual(result.userInfo.workData.jobTitle, "Engineer")
        XCTAssertEqual(result.preferences, ["dark_mode", "notifications", "auto_save"])
        XCTAssertEqual(result.metadata["lastUpdated"], "system")
        XCTAssertEqual(result.metadata["createdBy"], "2024-01-01")
    }
    
    func testPreTransformKeyedDecodingContainerSuperDecoder() {
        struct SuperDecoderTest: Codable, Equatable {
            let normalField: String
            let superData: SuperData
            
            struct SuperData: Codable, Equatable {
                let value: String
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.normalField = try container.decode(String.self, forKey: .normalField)
                
                // Test superDecoder
                let superDecoder = try container.superDecoder()
                self.superData = try SuperData(from: superDecoder)
            }
            
        }
        
        let json = """
        {
            "normal_field": "normal_value",
            "super": {
                "value": "super_value"
            }
        }
        """
        
        let decoder = ReerJSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let result = try! decoder.decode(SuperDecoderTest.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(result.normalField, "normal_value")
        XCTAssertEqual(result.superData.value, "super_value")
        
        // Test superDecoder(forKey:)
        struct CustomSuperDecoderTest: Codable, Equatable {
            let normalField: String
            let customSuperData: SuperData
            
            struct SuperData: Codable, Equatable {
                let value: String
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.normalField = try container.decode(String.self, forKey: .normalField)
                
                // Test superDecoder(forKey:)
                let superDecoder = try container.superDecoder(forKey: .customSuperData)
                self.customSuperData = try SuperData(from: superDecoder)
            }
        }
        
        let customSuperJson = """
        {
            "normal_field": "normal_value",
            "custom_super_data": {
                "value": "custom_super_value"
            }
        }
        """
        
        let customResult = try! decoder.decode(CustomSuperDecoderTest.self, from: customSuperJson.data(using: .utf8)!)
        XCTAssertEqual(customResult.normalField, "normal_value")
        XCTAssertEqual(customResult.customSuperData.value, "custom_super_value")
    }
    
    func testPreTransformKeyedDecodingContainerAllDataTypes() {
        #if compiler(>=6.0)
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        struct AllTypesTestWithInt128: Codable, Equatable {
            // Basic types
            let boolValue: Bool
            let stringValue: String
            let intValue: Int
            let int8Value: Int8
            let int16Value: Int16
            let int32Value: Int32
            let int64Value: Int64
            let uintValue: UInt
            let uint8Value: UInt8
            let uint16Value: UInt16
            let uint32Value: UInt32
            let uint64Value: UInt64
            let floatValue: Float
            let doubleValue: Double
            
            // Optional types
            let optionalString: String?
            let optionalInt: Int?
            let optionalBool: Bool?
            
            // Collections
            let arrayValue: [String]
            let dictionaryValue: [String: Int]
            
            // Special types
            let urlValue: URL
            let dateValue: Date
            let dataValue: Data
            
            let int128Value: Int128?
            let uint128Value: UInt128?
        }
        #endif
        
        struct AllTypesTest: Codable, Equatable {
            // Basic types
            let boolValue: Bool
            let stringValue: String
            let intValue: Int
            let int8Value: Int8
            let int16Value: Int16
            let int32Value: Int32
            let int64Value: Int64
            let uintValue: UInt
            let uint8Value: UInt8
            let uint16Value: UInt16
            let uint32Value: UInt32
            let uint64Value: UInt64
            let floatValue: Float
            let doubleValue: Double
            
            // Optional types for decodeIfPresent testing
            let optionalString: String?
            let optionalInt: Int?
            let optionalBool: Bool?
            
            // Optional integer types
            let optionalInt8: Int8?
            let optionalInt16: Int16?
            let optionalInt32: Int32?
            let optionalInt64: Int64?
            let optionalUInt: UInt?
            let optionalUInt8: UInt8?
            let optionalUInt16: UInt16?
            let optionalUInt32: UInt32?
            let optionalUInt64: UInt64?
            
            // Optional floating point types
            let optionalFloat: Float?
            let optionalDouble: Double?
            
            // Collections
            let arrayValue: [String]
            let dictionaryValue: [String: Int]
            let optionalArrayValue: [Int]?
            let optionalDictionaryValue: [String: String]?
            
            // Special types
            let urlValue: URL
            let dateValue: Date
            let dataValue: Data
            let optionalUrlValue: URL?
            let optionalDateValue: Date?
            let optionalDataValue: Data?
        }
        
        let json = """
        {
            "bool_value": true,
            "string_value": "test_string",
            "int_value": 42,
            "int8_value": 127,
            "int16_value": 32767,
            "int32_value": 2147483647,
            "int64_value": 9223372036854775807,
            "uint_value": 4294967295,
            "uint8_value": 255,
            "uint16_value": 65535,
            "uint32_value": 4294967295,
            "uint64_value": 18446744073709551615,
            "float_value": 3.14159,
            "double_value": 2.71828182846,
            "optional_string": "optional_test",
            "optional_int": 123,
            "optional_bool": null,
            "optional_int8": 100,
            "optional_int16": null,
            "optional_int32": 999999,
            "optional_int64": 1234567890123456789,
            "optional_u_int": null,
            "optional_u_int8": 200,
            "optional_u_int16": 50000,
            "optional_u_int32": null,
            "optional_u_int64": 9876543210987654321,
            "optional_float": 2.718,
            "optional_double": null,
            "array_value": ["item1", "item2", "item3"],
            "dictionary_value": {
                "key1": 1,
                "key2": 2
            },
            "optional_array_value": [10, 20, 30],
            "optional_dictionary_value": null,
            "url_value": "https://example.com",
            "date_value": 1609459200,
            "data_value": "SGVsbG8gV29ybGQ=",
            "optional_url_value": "https://optional.example.com",
            "optional_date_value": null,
            "optional_data_value": "T3B0aW9uYWwgRGF0YQ=="
        }
        """
        
        let decoder = ReerJSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .secondsSince1970
        decoder.dataDecodingStrategy = .base64
        
        #if compiler(>=6.0)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            let jsonWithInt128 = """
            {
                "bool_value": true,
                "string_value": "test_string",
                "int_value": 42,
                "int8_value": 127,
                "int16_value": 32767,
                "int32_value": 2147483647,
                "int64_value": 9223372036854775807,
                "uint_value": 4294967295,
                "uint8_value": 255,
                "uint16_value": 65535,
                "uint32_value": 4294967295,
                "uint64_value": 18446744073709551615,
                "float_value": 3.14159,
                "double_value": 2.71828182846,
                "optional_string": "optional_test",
                "optional_int": 123,
                "optional_bool": null,
                "array_value": ["item1", "item2", "item3"],
                "dictionary_value": {
                    "key1": 1,
                    "key2": 2
                },
                "url_value": "https://example.com",
                "date_value": 1609459200,
                "data_value": "SGVsbG8gV29ybGQ=",
                "decimal_value": "123.456",
                "int128_value": 170141183460469231731687303715884105727,
                "uint128_value": 340282366920938463463374607431768211455
            }
            """
            
            let resultWithInt128 = try! decoder.decode(AllTypesTestWithInt128.self, from: jsonWithInt128.data(using: .utf8)!)
            
            // Verify all values
            XCTAssertEqual(resultWithInt128.boolValue, true)
            XCTAssertEqual(resultWithInt128.stringValue, "test_string")
            XCTAssertEqual(resultWithInt128.intValue, 42)
            XCTAssertEqual(resultWithInt128.int8Value, 127)
            XCTAssertEqual(resultWithInt128.int16Value, 32767)
            XCTAssertEqual(resultWithInt128.int32Value, 2147483647)
            XCTAssertEqual(resultWithInt128.int64Value, 9223372036854775807)
            XCTAssertEqual(resultWithInt128.uintValue, 4294967295)
            XCTAssertEqual(resultWithInt128.uint8Value, 255)
            XCTAssertEqual(resultWithInt128.uint16Value, 65535)
            XCTAssertEqual(resultWithInt128.uint32Value, 4294967295)
            XCTAssertEqual(resultWithInt128.uint64Value, 18446744073709551615)
            XCTAssertEqual(resultWithInt128.floatValue, 3.14159, accuracy: 0.00001)
            XCTAssertEqual(resultWithInt128.doubleValue, 2.71828182846, accuracy: 0.00000000001)
            XCTAssertEqual(resultWithInt128.optionalString, "optional_test")
            XCTAssertEqual(resultWithInt128.optionalInt, 123)
            XCTAssertNil(resultWithInt128.optionalBool)
            XCTAssertEqual(resultWithInt128.arrayValue, ["item1", "item2", "item3"])
            XCTAssertEqual(resultWithInt128.dictionaryValue, ["key1": 1, "key2": 2])
            XCTAssertEqual(resultWithInt128.urlValue, URL(string: "https://example.com")!)
            XCTAssertEqual(resultWithInt128.dateValue, Date(timeIntervalSince1970: 1609459200))
            XCTAssertEqual(resultWithInt128.dataValue, "Hello World".data(using: .utf8)!)
            XCTAssertEqual(resultWithInt128.int128Value, 170141183460469231731687303715884105727)
            XCTAssertEqual(resultWithInt128.uint128Value, 340282366920938463463374607431768211455)
        }
        #endif
        
        let result = try! decoder.decode(AllTypesTest.self, from: json.data(using: .utf8)!)
        
        // Verify all values
        XCTAssertEqual(result.boolValue, true)
        XCTAssertEqual(result.stringValue, "test_string")
        XCTAssertEqual(result.intValue, 42)
        XCTAssertEqual(result.int8Value, 127)
        XCTAssertEqual(result.int16Value, 32767)
        XCTAssertEqual(result.int32Value, 2147483647)
        XCTAssertEqual(result.int64Value, 9223372036854775807)
        XCTAssertEqual(result.uintValue, 4294967295)
        XCTAssertEqual(result.uint8Value, 255)
        XCTAssertEqual(result.uint16Value, 65535)
        XCTAssertEqual(result.uint32Value, 4294967295)
        XCTAssertEqual(result.uint64Value, 18446744073709551615)
        XCTAssertEqual(result.floatValue, 3.14159, accuracy: 0.00001)
        XCTAssertEqual(result.doubleValue, 2.71828182846, accuracy: 0.00000000001)
        XCTAssertEqual(result.optionalString, "optional_test")
        XCTAssertEqual(result.optionalInt, 123)
        XCTAssertNil(result.optionalBool)
        XCTAssertEqual(result.arrayValue, ["item1", "item2", "item3"])
        XCTAssertEqual(result.dictionaryValue, ["key1": 1, "key2": 2])
        XCTAssertEqual(result.urlValue, URL(string: "https://example.com")!)
        XCTAssertEqual(result.dateValue, Date(timeIntervalSince1970: 1609459200))
        XCTAssertEqual(result.dataValue, "Hello World".data(using: .utf8)!)
        
        // Verify optional values from decodeIfPresent
        XCTAssertEqual(result.optionalString, "optional_test")
        XCTAssertEqual(result.optionalInt, 123)
        XCTAssertNil(result.optionalBool)
        
        // Verify optional integer types
        XCTAssertEqual(result.optionalInt8, 100)
        XCTAssertNil(result.optionalInt16)
        XCTAssertEqual(result.optionalInt32, 999999)
        XCTAssertEqual(result.optionalInt64, 1234567890123456789)
        XCTAssertNil(result.optionalUInt)
        XCTAssertEqual(result.optionalUInt8, 200)
        XCTAssertEqual(result.optionalUInt16, 50000)
        XCTAssertNil(result.optionalUInt32)
        XCTAssertEqual(result.optionalUInt64, 9876543210987654321)
        
        // Verify optional floating point types
        XCTAssertEqual(result.optionalFloat!, 2.718, accuracy: 0.001)
        XCTAssertNil(result.optionalDouble)
        
        // Verify optional collections
        XCTAssertEqual(result.optionalArrayValue, [10, 20, 30])
        XCTAssertNil(result.optionalDictionaryValue)
        
        // Verify optional special types
        XCTAssertEqual(result.optionalUrlValue, URL(string: "https://optional.example.com")!)
        XCTAssertNil(result.optionalDateValue)
        XCTAssertEqual(result.optionalDataValue, "Optional Data".data(using: .utf8)!)
    }
    
    func testPreTransformKeyedDecodingContainerDecodeIfPresent() {
        struct DecodeIfPresentTest: Codable, Equatable {
            let presentString: String?
            let missingString: String?
            let nullString: String?
            let presentInt: Int?
            let missingInt: Int?
            let nullInt: Int?
        }
        
        let json = """
        {
            "present_string": "value",
            "null_string": null,
            "present_int": 42,
            "null_int": null
        }
        """
        
        let decoder = ReerJSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let result = try! decoder.decode(DecodeIfPresentTest.self, from: json.data(using: .utf8)!)
        
        // Check present values
        XCTAssertEqual(result.presentString, "value")
        XCTAssertEqual(result.presentInt, 42)
        
        // Check missing values (should be nil)
        XCTAssertNil(result.missingString)
        XCTAssertNil(result.missingInt)
        
        // Check null values (should be nil)
        XCTAssertNil(result.nullString)
        XCTAssertNil(result.nullInt)
    }
    
    func testPreTransformKeyedDecodingContainerDecodeIfPresentEdgeCases() {
        struct EdgeCaseTest: Codable, Equatable {
            // 测试各种整数类型的 decodeIfPresent
            let optInt8Present: Int8?
            let optInt8Null: Int8?
            let optInt8Missing: Int8?
            
            let optInt16Present: Int16?
            let optInt16Null: Int16?
            let optInt16Missing: Int16?
            
            let optInt32Present: Int32?
            let optInt32Null: Int32?
            let optInt32Missing: Int32?
            
            let optInt64Present: Int64?
            let optInt64Null: Int64?
            let optInt64Missing: Int64?
            
            let optUIntPresent: UInt?
            let optUIntNull: UInt?
            let optUIntMissing: UInt?
            
            let optUInt8Present: UInt8?
            let optUInt8Null: UInt8?
            let optUInt8Missing: UInt8?
            
            let optUInt16Present: UInt16?
            let optUInt16Null: UInt16?
            let optUInt16Missing: UInt16?
            
            let optUInt32Present: UInt32?
            let optUInt32Null: UInt32?
            let optUInt32Missing: UInt32?
            
            let optUInt64Present: UInt64?
            let optUInt64Null: UInt64?
            let optUInt64Missing: UInt64?
            
            // 测试浮点类型的 decodeIfPresent
            let optFloatPresent: Float?
            let optFloatNull: Float?
            let optFloatMissing: Float?
            
            let optDoublePresent: Double?
            let optDoubleNull: Double?
            let optDoubleMissing: Double?
            
            // 测试布尔类型的 decodeIfPresent
            let optBoolPresent: Bool?
            let optBoolNull: Bool?
            let optBoolMissing: Bool?
            
            // 测试字符串类型的 decodeIfPresent
            let optStringPresent: String?
            let optStringNull: String?
            let optStringMissing: String?
        }
        
        let json = """
        {
            "opt_int8_present": 127,
            "opt_int8_null": null,
            
            "opt_int16_present": 32767,
            "opt_int16_null": null,
            
            "opt_int32_present": 2147483647,
            "opt_int32_null": null,
            
            "opt_int64_present": 9223372036854775807,
            "opt_int64_null": null,
            
            "opt_u_int_present": 4294967295,
            "opt_u_int_null": null,
            
            "opt_u_int8_present": 255,
            "opt_u_int8_null": null,
            
            "opt_u_int16_present": 65535,
            "opt_u_int16_null": null,
            
            "opt_u_int32_present": 4294967295,
            "opt_u_int32_null": null,
            
            "opt_u_int64_present": 18446744073709551615,
            "opt_u_int64_null": null,
            
            "opt_float_present": 3.14159,
            "opt_float_null": null,
            
            "opt_double_present": 2.71828182846,
            "opt_double_null": null,
            
            "opt_bool_present": true,
            "opt_bool_null": null,
            
            "opt_string_present": "hello world",
            "opt_string_null": null
        }
        """
        
        let decoder = ReerJSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let result = try! decoder.decode(EdgeCaseTest.self, from: json.data(using: .utf8)!)
        
        // 验证 present 值
        XCTAssertEqual(result.optInt8Present, 127)
        XCTAssertEqual(result.optInt16Present, 32767)
        XCTAssertEqual(result.optInt32Present, 2147483647)
        XCTAssertEqual(result.optInt64Present, 9223372036854775807)
        XCTAssertEqual(result.optUIntPresent, 4294967295)
        XCTAssertEqual(result.optUInt8Present, 255)
        XCTAssertEqual(result.optUInt16Present, 65535)
        XCTAssertEqual(result.optUInt32Present, 4294967295)
        XCTAssertEqual(result.optUInt64Present, 18446744073709551615)
        XCTAssertEqual(result.optFloatPresent!, 3.14159, accuracy: 0.00001)
        XCTAssertEqual(result.optDoublePresent!, 2.71828182846, accuracy: 0.00000000001)
        XCTAssertEqual(result.optBoolPresent, true)
        XCTAssertEqual(result.optStringPresent, "hello world")
        
        // 验证 null 值
        XCTAssertNil(result.optInt8Null)
        XCTAssertNil(result.optInt16Null)
        XCTAssertNil(result.optInt32Null)
        XCTAssertNil(result.optInt64Null)
        XCTAssertNil(result.optUIntNull)
        XCTAssertNil(result.optUInt8Null)
        XCTAssertNil(result.optUInt16Null)
        XCTAssertNil(result.optUInt32Null)
        XCTAssertNil(result.optUInt64Null)
        XCTAssertNil(result.optFloatNull)
        XCTAssertNil(result.optDoubleNull)
        XCTAssertNil(result.optBoolNull)
        XCTAssertNil(result.optStringNull)
        
        // 验证 missing 值
        XCTAssertNil(result.optInt8Missing)
        XCTAssertNil(result.optInt16Missing)
        XCTAssertNil(result.optInt32Missing)
        XCTAssertNil(result.optInt64Missing)
        XCTAssertNil(result.optUIntMissing)
        XCTAssertNil(result.optUInt8Missing)
        XCTAssertNil(result.optUInt16Missing)
        XCTAssertNil(result.optUInt32Missing)
        XCTAssertNil(result.optUInt64Missing)
        XCTAssertNil(result.optFloatMissing)
        XCTAssertNil(result.optDoubleMissing)
        XCTAssertNil(result.optBoolMissing)
        XCTAssertNil(result.optStringMissing)
    }
    
    func testPreTransformKeyedDecodingContainerContains() {
        struct ContainsTest: Codable, Equatable {
            let value: String
            let existingKey: String?
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                // Test contains method - note: keys are transformed by snake_case strategy
                XCTAssertTrue(container.contains(.value))
                XCTAssertTrue(container.contains(.existingKey))  // existing_key -> existingKey
                XCTAssertFalse(container.contains(.missingKey))
                
                self.value = try container.decode(String.self, forKey: .value)
                self.existingKey = try container.decodeIfPresent(String.self, forKey: .existingKey)
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(value, forKey: .value)
                try container.encodeIfPresent(existingKey, forKey: .existingKey)
            }
            
            enum CodingKeys: String, CodingKey {
                case value
                case existingKey
                case missingKey
            }
        }
        
        let json = """
        {
            "value": "test",
            "existing_key": "exists"
        }
        """
        
        let decoder = ReerJSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let result = try! decoder.decode(ContainsTest.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(result.value, "test")
        XCTAssertEqual(result.existingKey, "exists")
    }
    
    func testPreTransformKeyedDecodingContainerAllKeys() {
        struct AllKeysTest: Codable, Equatable {
            let keys: [String]
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: _CodingKey.self)
                
                // Test allKeys property
                let allKeys = container.allKeys
                self.keys = allKeys.map { $0.stringValue }.sorted()
            }
        }
        
        let json = """
        {
            "first_key": "value1",
            "second_key": "value2",
            "third_key": "value3"
        }
        """
        
        let decoder = ReerJSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let result = try! decoder.decode(AllKeysTest.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(result.keys.sorted(), ["firstKey", "secondKey", "thirdKey"])
    }
    
    func testPath() throws {
        struct Test: Decodable {
            let c: String
        }
        let data = """
            {"a": {"b": {"c": "ddd"}}}
            """.data(using: .utf8)!
        let model = try ReerJSONDecoder().decode(Test.self, from: data, path: ["a", "b"])
        XCTAssert(model.c == "ddd")
        let model3 = try ReerJSONDecoder().decode(Test.self, from: data, path: "a.b")
        XCTAssert(model3.c == "ddd")
        
        struct Test2: Decodable {
            let c: [Int]
        }
        let data2 = """
            {"a": {"b": {"c": [1,2,3]}}}
            """.data(using: .utf8)!
        let model2 = try ReerJSONDecoder().decode(Test2.self, from: data2, path: ["a", "b"])
        XCTAssert(model2.c == [1, 2, 3])
        let model4 = try ReerJSONDecoder().decode(Test2.self, from: data2, path: "a.b")
        XCTAssert(model4.c == [1, 2, 3])
    }
    
    func testBasicTypeArray() throws {
        struct Test: Decodable {
            var double: [Double]
            var int: [Int]
            var string: [String]
        }
        
        let data = """
        {
            "double": [1.1, 2.2, 3.3],
            "int": [1, 2, 3],
            "string": ["1", "2", "3"]
        }
        """.data(using: .utf8)!
        let model = try ReerJSONDecoder().decode(Test.self, from: data)
        XCTAssert(model.double == [1.1, 2.2, 3.3])
        XCTAssert(model.int == [1, 2, 3])
        XCTAssert(model.string == ["1", "2", "3"])
    }
    
    func testBasicTypeArray2() throws {
        struct Test: Decodable {
            var double: [Double]
            var int: [Int]
            var string: [String]
            
            enum CodingKeys: String, CodingKey {
                case double
                case int
                case string
            }
            
            init(from decoder: any Decoder) throws {
                let keyed = try decoder.container(keyedBy: CodingKeys.self)
                var doubleUnkeyed = try keyed.nestedUnkeyedContainer(forKey: .double)
                var intUnkeyed = try keyed.nestedUnkeyedContainer(forKey: .int)
                var stringUnkeyed = try keyed.nestedUnkeyedContainer(forKey: .string)
                
                var doubleRet: [Double] = []
                while !doubleUnkeyed.isAtEnd {
                    let element = try doubleUnkeyed.decode(Double.self)
                    doubleRet.append(element)
                }
                self.double = doubleRet
                
                var intRet: [Int] = []
                while !intUnkeyed.isAtEnd {
                    let element = try intUnkeyed.decode(Int.self)
                    intRet.append(element)
                }
                self.int = intRet
                
                var stringRet: [String] = []
                while !stringUnkeyed.isAtEnd {
                    let element = try stringUnkeyed.decode(String.self)
                    stringRet.append(element)
                }
                self.string = stringRet
            }
        }
        
        let data = """
        {
            "double": [1.1, 2.2, 3.3],
            "int": [1, 2, 3],
            "string": ["1", "2", "3"]
        }
        """.data(using: .utf8)!
        let model = try ReerJSONDecoder().decode(Test.self, from: data)
        XCTAssert(model.double == [1.1, 2.2, 3.3])
        XCTAssert(model.int == [1, 2, 3])
        XCTAssert(model.string == ["1", "2", "3"])
    }
    
    #if !os(Linux)
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, visionOS 1, *)
    func testDecodableWithConfiguration() throws {
        
        struct DecodingConfig {
            let prefix: String
            let multiplier: Int
        }
        
        struct ConfigurableModel: DecodableWithConfiguration, Equatable {
            let value: String
            let number: Int
            
            init(from decoder: Decoder, configuration: DecodingConfig) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let rawValue = try container.decode(String.self, forKey: .value)
                let rawNumber = try container.decode(Int.self, forKey: .number)
                
                self.value = configuration.prefix + rawValue
                self.number = rawNumber * configuration.multiplier
            }
            
            enum CodingKeys: String, CodingKey {
                case value, number
            }
        }
        
        let json = """
            {"value": "test", "number": 5}
            """.data(using: .utf8)!
        
        let config = DecodingConfig(prefix: "prefix_", multiplier: 2)
        let decoder = ReerJSONDecoder()
        
        // 测试基本的配置解码
        let result = try decoder.decode(ConfigurableModel.self, from: json, configuration: config)
        XCTAssertEqual(result.value, "prefix_test")
        XCTAssertEqual(result.number, 10)
        
        // 测试与 Foundation.JSONDecoder 的兼容性
        let foundationDecoder = JSONDecoder()
        let foundationResult = try foundationDecoder.decode(ConfigurableModel.self, from: json, configuration: config)
        XCTAssertEqual(result, foundationResult)
    }
    
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, visionOS 1, *)
    func testDecodableWithConfigurationProvider() throws {
        // 定义配置结构
        struct AppConfig {
            let apiVersion: String
            let debug: Bool
        }
        
        // 定义配置提供者
        struct AppConfigProvider: DecodingConfigurationProviding {
            static let decodingConfiguration = AppConfig(apiVersion: "v2", debug: true)
        }
        
        // 定义使用配置的模型
        struct APIModel: DecodableWithConfiguration, Equatable {
            let endpoint: String
            let data: String
            
            init(from decoder: Decoder, configuration: AppConfig) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let rawEndpoint = try container.decode(String.self, forKey: .endpoint)
                self.data = try container.decode(String.self, forKey: .data)
                
                // 根据配置修改端点
                if configuration.debug {
                    self.endpoint = "/debug/\(configuration.apiVersion)/\(rawEndpoint)"
                } else {
                    self.endpoint = "/\(configuration.apiVersion)/\(rawEndpoint)"
                }
            }
            
            enum CodingKeys: String, CodingKey {
                case endpoint, data
            }
        }
        
        let json = """
            {"endpoint": "users", "data": "userdata"}
            """.data(using: .utf8)!
        
        let decoder = ReerJSONDecoder()
        
        // 测试配置提供者
        let result = try decoder.decode(APIModel.self, from: json, configuration: AppConfigProvider.self)
        XCTAssertEqual(result.endpoint, "/debug/v2/users")
        XCTAssertEqual(result.data, "userdata")
        
        // 测试与 Foundation.JSONDecoder 的兼容性
        let foundationDecoder = JSONDecoder()
        let foundationResult = try foundationDecoder.decode(APIModel.self, from: json, configuration: AppConfigProvider.self)
        XCTAssertEqual(result, foundationResult)
    }
    
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, visionOS 1, *)
    func testDecodableWithConfigurationAndPath() throws {
        // 定义配置
        struct PathConfig {
            let transform: Bool
        }
        
        // 定义嵌套模型
        struct NestedConfigurableModel: DecodableWithConfiguration, Equatable {
            let name: String
            let active: Bool
            
            init(from decoder: Decoder, configuration: PathConfig) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let rawName = try container.decode(String.self, forKey: .name)
                let rawActive = try container.decode(Bool.self, forKey: .active)
                
                // 根据配置转换数据
                if configuration.transform {
                    self.name = rawName.uppercased()
                    self.active = !rawActive
                } else {
                    self.name = rawName
                    self.active = rawActive
                }
            }
            
            enum CodingKeys: String, CodingKey {
                case name, active
            }
        }
        
        let json = """
            {
                "user": {
                    "profile": {
                        "name": "john",
                        "active": false
                    }
                }
            }
            """.data(using: .utf8)!
        
        let config = PathConfig(transform: true)
        let decoder = ReerJSONDecoder()
        
        // 测试带路径的配置解码
        let result = try decoder.decode(NestedConfigurableModel.self, from: json, path: ["user", "profile"], configuration: config)
        XCTAssertEqual(result.name, "JOHN")
        XCTAssertEqual(result.active, true)
        
        // 测试不带路径的配置解码（根级别）
        let rootJson = """
            {
                "name": "alice",
                "active": true
            }
            """.data(using: .utf8)!
        
        let rootResult = try decoder.decode(NestedConfigurableModel.self, from: rootJson, configuration: config)
        XCTAssertEqual(rootResult.name, "ALICE")
        XCTAssertEqual(rootResult.active, false)
    }
    
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, visionOS 1, *)
    func testDecodableWithConfigurationArray() throws {
        // 定义配置
        struct ArrayConfig {
            let filterNegative: Bool
        }
        
        // 定义数组项模型
        struct NumberModel: DecodableWithConfiguration, Equatable {
            let value: Int
            let isPositive: Bool
            
            init(from decoder: Decoder, configuration: ArrayConfig) throws {
                let container = try decoder.singleValueContainer()
                let rawValue = try container.decode(Int.self)
                
                if configuration.filterNegative && rawValue < 0 {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Negative numbers are not allowed"
                        )
                    )
                }
                
                self.value = rawValue
                self.isPositive = rawValue >= 0
            }
        }
        
        let json = """
            [1, 2, 3, -1, 5]
            """.data(using: .utf8)!
        
        let allowNegativeConfig = ArrayConfig(filterNegative: false)
        let filterNegativeConfig = ArrayConfig(filterNegative: true)
        let decoder = ReerJSONDecoder()
        
        // 测试允许负数的配置
        let result1 = try decoder.decode([NumberModel].self, from: json, configuration: allowNegativeConfig)
        XCTAssertEqual(result1.count, 5)
        XCTAssertEqual(result1[3].value, -1)
        XCTAssertEqual(result1[3].isPositive, false)
        
        // 测试过滤负数的配置应该抛出错误
        XCTAssertThrowsError(try decoder.decode([NumberModel].self, from: json, configuration: filterNegativeConfig)) { error in
            if let decodingError = error as? DecodingError,
               case .dataCorrupted(let context) = decodingError {
                XCTAssertEqual(context.debugDescription, "Negative numbers are not allowed")
            } else {
                XCTFail("Expected DecodingError.dataCorrupted")
            }
        }
    }
    
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, visionOS 1, *)
    func testDecodableWithConfigurationComplexTypes() throws {
        // 定义复杂配置
        struct ComplexConfig {
            let dateFormat: String
            let numberFormat: String
            let enableValidation: Bool
        }
        
        // 定义复杂模型
        struct ComplexModel: DecodableWithConfiguration, Equatable {
            let id: String
            let timestamp: String
            let score: String
            
            init(from decoder: Decoder, configuration: ComplexConfig) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.id = try container.decode(String.self, forKey: .id)
                
                // 根据配置格式化时间戳
                let rawTimestamp = try container.decode(Int.self, forKey: .timestamp)
                self.timestamp = "\(configuration.dateFormat):\(rawTimestamp)"
                
                // 根据配置格式化分数
                let rawScore = try container.decode(Double.self, forKey: .score)
                if configuration.enableValidation && rawScore < 0 {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Score cannot be negative"
                        )
                    )
                }
                self.score = "\(configuration.numberFormat):\(rawScore)"
            }
            
            enum CodingKeys: String, CodingKey {
                case id, timestamp, score
            }
        }
        
        let json = """
            {"id": "test123", "timestamp": 1609459200, "score": 95.5}
            """.data(using: .utf8)!
        
        let config = ComplexConfig(dateFormat: "ISO", numberFormat: "PERCENT", enableValidation: true)
        let decoder = ReerJSONDecoder()
        
        let result = try decoder.decode(ComplexModel.self, from: json, configuration: config)
        XCTAssertEqual(result.id, "test123")
        XCTAssertEqual(result.timestamp, "ISO:1609459200")
        XCTAssertEqual(result.score, "PERCENT:95.5")
        
        // 测试验证失败的情况
        let invalidJson = """
            {"id": "test456", "timestamp": 1609459200, "score": -10.0}
            """.data(using: .utf8)!
        
        XCTAssertThrowsError(try decoder.decode(ComplexModel.self, from: invalidJson, configuration: config)) { error in
            if let decodingError = error as? DecodingError,
               case .dataCorrupted(let context) = decodingError {
                XCTAssertEqual(context.debugDescription, "Score cannot be negative")
            } else {
                XCTFail("Expected DecodingError.dataCorrupted")
            }
        }
    }
    #endif
}
