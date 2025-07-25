import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ReerJSONDecoderTests.allTests),
        testCase(AppleJSONDecoderTests.allTests),
    ]
}
#endif
