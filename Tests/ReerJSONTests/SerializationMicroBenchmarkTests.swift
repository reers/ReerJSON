import XCTest
import Foundation
@testable import ReerJSON

// Micro-benchmarks to isolate write bottleneck
final class SerializationMicroBenchmarkTests: XCTestCase {

    // Pure integer dict (no string values, only string keys)
    private let intDict: NSDictionary = {
        let d = NSMutableDictionary()
        for i in 0..<1000 {
            d["k\(i)"] = NSNumber(value: i)
        }
        return d.copy() as! NSDictionary
    }()

    // String dict
    private let strDict: NSDictionary = {
        let d = NSMutableDictionary()
        for i in 0..<1000 {
            d["key_\(i)"] = "value_\(i)"
        }
        return d.copy() as! NSDictionary
    }()

    func testWriteIntDict_Foundation() {
        measure {
            for _ in 0..<100 {
                _ = try? JSONSerialization.data(withJSONObject: intDict)
            }
        }
    }

    func testWriteIntDict_ReerJSON() {
        measure {
            for _ in 0..<100 {
                _ = try? ReerJSONSerialization.data(withJSONObject: intDict)
            }
        }
    }

    func testWriteStrDict_Foundation() {
        measure {
            for _ in 0..<100 {
                _ = try? JSONSerialization.data(withJSONObject: strDict)
            }
        }
    }

    func testWriteStrDict_ReerJSON() {
        measure {
            for _ in 0..<100 {
                _ = try? ReerJSONSerialization.data(withJSONObject: strDict)
            }
        }
    }
}
