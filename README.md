# ReerJSON
## A faster version of JSONDecoder based on [yyjson](https://github.com/ibireme/yyjson)

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


Tested with ReerJSON 0.3.2, ZippyJSON 1.2.15, IkigaJSON 2.3.2

[Code for Benchmarks](https://github.com/Asura19/ReerJSONBenchmark)

# Installation

## Swift Package Manager

Add dependency in `Package.swift` or project `Package Dependencies`
```swift
.package(url: "https://github.com/reers/ReerJSON.git", from: "0.3.2"),
```

Depend on `ReerJSON` in your target.
```swift
.product(name: "ReerJSON", package: "ReerJSON" ),
```

# Usage
`ReerJSONDecoder` is API-compatible replacements for Foundation's JSONDecoder. 
Simply swap the type and add the import, no other code changes required:

```
import ReerJSON

// Before
let decoder = JSONDecoder()

// After
let decoder = ReerJSONDecoder()
```

All public interfaces, behaviors, error types, and coding strategies are identical to the Foundation counterparts. The ReerJSON test suite includes exhaustive test cases covering every feature, ensuring full compatibility.


# Differences

Except for the items listed below, ReerJSON behaves exactly the same as Foundation—every capability, every thrown error, and every edge case is covered by a comprehensive test suite.

| Decoder Diff              | Foundation |ReerJSON                   |
|---------------------------|------------|---------------------------|
| JSON5                     | ✅         | ✅                        |                       
| assumesTopLevelDictionary | ✅         | ❌                        |
| Infinity and NaN          | ±Infinity, ±NaN | ±Infinity, ±NaN, ±Inf and case-insensitive. See [details](https://github.com/reers/ReerJSON/blob/main/Tests/ReerJSONTests/JSONEncoderTests.swift#L1975) |

# TODO
* [x] Add GitHub workflow for CI.
* [x] Support `CodableWithConfiguration`.
* [x] Support JSON5 decoding.
* [ ] Implement ReerJSONEncoder.

# License
This project is licensed under the MIT License.
Portions of this project incorporate code from the following source code or test code:

* [swiftlang/swift-foundation](https://github.com/swiftlang/swift-foundation), licensed under the Apache License, Version 2.0.
* [michaeleisel/ZippyJSON](https://github.com/michaeleisel/ZippyJSON), licensed under the MIT License.

See the LICENSE file for the full text of both licenses.

# Acknowledgments

We would like to express our gratitude to the following projects and their contributors:

* **[ibireme/yyjson](https://github.com/ibireme/yyjson)** - For providing the high-performance JSON parsing library that powers ReerJSON.
* **[swiftlang/swift-foundation](https://github.com/swiftlang/swift-foundation)** - For implementation reference and comprehensive test suites that helped ensure compatibility.
* **[michaeleisel/ZippyJSON](https://github.com/michaeleisel/ZippyJSON)** - For the innovative Swift JSON parsing approach and valuable test cases.
* **[michaeleisel/JJLISO8601DateFormatter](https://github.com/michaeleisel/JJLISO8601DateFormatter)** - For the high-performance date formatting implementation.
* **[nixzhu/Ananda](https://github.com/nixzhu/Ananda)** - For the pioneering work in integrating yyjson with Swift and providing architectural inspiration.

Special thanks to all the open-source contributors who made this project possible.
