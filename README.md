# ReerJSON
## A faster version of JSONDecoder & JSONEncoder powered by [yyjson](https://github.com/ibireme/yyjson)

![Coverage: 88%](https://img.shields.io/static/v1?label=coverage&message=88%&color=brightgreen)
[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible%20%28iOS%29-brightgreen)](https://swift.org/package-manager/)

ReerJSON is a really fast JSON parser, and it's inspired by [ZippyJSON](https://github.com/michaeleisel/ZippyJSON) and [Ananda](https://github.com/nixzhu/Ananda).

> **⚠️Important:** When measuring the performance of Swift libraries, make sure you're building in **Release Mode**. 
> When building Swift code on DEBUG compilation, it can be 10-20x slower than equivalent code on RELEASE.

# Benchmarks

## JSONDecoder

### iOS 17+

![CleanShot 2025-09-18 at 14 31 41@2x](https://github.com/user-attachments/assets/2fd6d82b-7a5f-4d6a-a6e5-3b0cd1682acd)

![CleanShot 2025-09-18 at 14 33 30@2x](https://github.com/user-attachments/assets/1cab62ec-077a-4c20-a294-9b5fb01ce5c6)

### Lower than iOS 17

![CleanShot 2025-09-18 at 14 37 04@2x](https://github.com/user-attachments/assets/ed201e1a-c1dc-4ec6-8036-2316bd5bccc4)

### macOS

![CleanShot 2025-09-18 at 13 40 05@2x](https://github.com/user-attachments/assets/3f814fa3-72b0-4005-bea5-7391105aa6dd)

## JSONEncoder

<img width="1233" height="708" alt="ios1" src="https://github.com/user-attachments/assets/1abce9a2-a17b-467d-8edb-6082bc79476b" />
<img width="2474" height="1416" alt="CleanShot 2026-04-15 at 12 43 58@2x" src="https://github.com/user-attachments/assets/f81b77e7-6cb9-4ec1-b11d-9bf5ecfd714e" />
<img width="2464" height="1418" alt="CleanShot 2026-04-15 at 12 46 05@2x" src="https://github.com/user-attachments/assets/57d76606-a76f-453c-a5e0-f0c77ce2872d" />

> On older/lower-end chips (e.g. A11), yyjson's "build DOM tree then serialize" approach is bottlenecked by smaller caches and weaker branch prediction — exactly the hardware traits yyjson's README states it depends on ("high instruction level parallelism, excellent branch predictor"). IkigaJSON's streaming byte-buffer design avoids building an intermediate tree, making it less sensitive to these hardware limitations and thus faster in certain scenarios on constrained processors

### macOS

<img width="1234" height="710" alt="macos" src="https://github.com/user-attachments/assets/3ddf4ff8-fa3a-4cae-ad70-a9653f981acb" />



Tested with ReerJSON 1.0.0, ZippyJSON 1.2.15, IkigaJSON 2.3.2

[Code for Benchmarks](https://github.com/Asura19/ReerJSONBenchmark)

# Installation

## Swift Package Manager

Add dependency in `Package.swift` or project `Package Dependencies`
```swift
.package(url: "https://github.com/reers/ReerJSON.git", from: "1.0.0"),
```

Depend on `ReerJSON` in your target.
```swift
.product(name: "ReerJSON", package: "ReerJSON" ),
```

# Usage

## Decoder && Encoder

`ReerJSONDecoder` and `ReerJSONEncoder` are API-compatible replacements for Foundation's JSONDecoder and JSONEncoder. 
Simply swap the type and add the import, no other code changes required:

```
import ReerJSON

// Before
let decoder = JSONDecoder()
let encoder = JSONEncoder()

// After
let decoder = ReerJSONDecoder()
let encoder = ReerJSONEncoder()
```

All public interfaces, behaviors, error types, and coding strategies are identical to the Foundation counterparts. The ReerJSON test suite includes exhaustive test cases covering every feature, ensuring full compatibility.

## DOM-Style Access

Parse JSON and access values directly without defining types:

```swift
import ReerJSON

let json = #"{"users": [{"name": "Alice"}, {"name": "Bob"}]}"#
let value = try JSONValue(string: json)

// Access nested values with subscripts
if let name = value["users"]?[0]?["name"]?.string {
    print(name) // "Alice"
}
```

## In-Place Parsing

For maximum performance with large JSON files,
use in-place parsing to avoid copying the input data:

```swift
var data = try Data(contentsOf: fileURL)
let json = try JSONValue.parseInPlace(consuming: &data)
// `data` is now consumed and should not be used
```

In-place parsing allows yyjson to parse directly within the input buffer,
avoiding memory allocation for string storage.
The `inout` parameter makes it clear that the data is consumed by this operation.

> [!NOTE]
> For most use cases, the standard `YYJSONValue(data:)` initializer is sufficient.
> Use in-place parsing only when performance is critical
> and you can accept the ownership semantics.

## JSONSerialization Alternative

Use `ReerJSONSerialization` with the same API as Foundation's `JSONSerialization`:

```swift
import ReerJSON

let json = #"{"message": "Hello, World!"}"#
let data = json.data(using: .utf8)!

let object = try ReerJSONSerialization.jsonObject(with: data)
if let dict = object as? [String: Any] {
    print(dict["message"] as? String ?? "") // "Hello, World!"
}
```

Configure output formatting with `WritingOptions`:

```swift
// Pretty printing with 2-space indent (useful for Xcode asset catalogs)
let data = try ReerJSONSerialization.data(
    withJSONObject: dict,
    options: [.indentationTwoSpaces, .sortedKeys]
)

// ASCII-only output with trailing newline
let data = try ReerJSONSerialization.data(
    withJSONObject: dict,
    options: [.escapeUnicode, .newlineAtEnd]
)
```


# Differences

Except for the items listed below, ReerJSON behaves exactly the same as Foundation—every capability, every thrown error, and every edge case is covered by a comprehensive test suite.

## Decoder

| Decoder Diff              | Foundation |ReerJSON                   |
|---------------------------|------------|---------------------------|
| JSON5                     | ✅         | ✅                        |                       
| assumesTopLevelDictionary | ✅         | ❌                        |
| Infinity and NaN          | ±Infinity, ±NaN | ±Infinity, ±NaN, ±Inf and case-insensitive. See [details](https://github.com/reers/ReerJSON/blob/main/Tests/ReerJSONTests/JSONEncoderTests.swift#L1975) |

## Encoder

| Encoder Diff          | Foundation              | ReerJSON                              |
|-----------------------|-------------------------|---------------------------------------|
| Unicode escape casing | `\u001f` (lowercase)    | `\u001F` (uppercase). Both are valid JSON per RFC 8259 |
| Pretty-print colon    | `"key" : value` (space before and after colon) | `"key": value` (space after colon only) |


# License
This project is licensed under the MIT License.
Portions of this project incorporate code from the following source code or test code:

* [swiftlang/swift-foundation](https://github.com/swiftlang/swift-foundation), licensed under the Apache License, Version 2.0.
* [michaeleisel/ZippyJSON](https://github.com/michaeleisel/ZippyJSON), licensed under the MIT License.
* [mattt/swift-yyjson](https://github.com/mattt/swift-yyjson), licensed under the MIT License. The `ReerJSONSerialization`, `Value`, `Configuration`, `Error`, and `Helpers` modules are adapted from this project.

See the LICENSE file for the full text of both licenses.

# Acknowledgments

We would like to express our gratitude to the following projects and their contributors:

* **[ibireme/yyjson](https://github.com/ibireme/yyjson)** - For providing the high-performance JSON parsing library that powers ReerJSON.
* **[swiftlang/swift-foundation](https://github.com/swiftlang/swift-foundation)** - For implementation reference and comprehensive test suites that helped ensure compatibility.
* **[michaeleisel/ZippyJSON](https://github.com/michaeleisel/ZippyJSON)** - For the innovative Swift JSON parsing approach and valuable test cases.
* **[michaeleisel/JJLISO8601DateFormatter](https://github.com/michaeleisel/JJLISO8601DateFormatter)** - For the high-performance date formatting implementation.
* **[mattt/swift-yyjson](https://github.com/mattt/swift-yyjson)** - For the `JSONSerialization` replacement and DOM-style `JSONValue`/`JSONDocument` APIs. The `ReerJSONSerialization`, `Value`, `Configuration`, `Error`, and `Helpers` source files and their tests are adapted from this project.
* **[nixzhu/Ananda](https://github.com/nixzhu/Ananda)** - For the pioneering work in integrating yyjson with Swift and providing architectural inspiration.

Special thanks to all the open-source contributors who made this project possible.
