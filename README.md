# ReerJSON
## A faster version of JSONDecoder based on [yyjson](https://github.com/ibireme/yyjson)

ReerJSON is a really fast JSON parser, and it's inspired by [ZippyJSON](https://github.com/michaeleisel/ZippyJSON) and [Ananda](https://github.com/nixzhu/Ananda).

> **⚠️Important:** When measuring the performance of Swift libraries, make sure you're building in **Release Mode**. 
> When building Swift code on DEBUG compilation, it can be 10-20x slower than equivalent code on RELEASE.

# Benchmarks

## JSONDecoder

### iOS 17+

![CleanShot 2025-09-04 at 14 18 27@2x](https://github.com/user-attachments/assets/68a106fa-ba18-498b-9b67-31d4f7c466eb)

![CleanShot 2025-09-04 at 14 21 33@2x](https://github.com/user-attachments/assets/7f05490a-c8e2-44ac-9ce1-5abbcdbcef01)

### Lower than iOS 17

![CleanShot 2025-09-04 at 14 24 18@2x](https://github.com/user-attachments/assets/b288b301-72e5-4bff-b2b7-59ad50ddd53a)

### macOS

![CleanShot 2025-09-04 at 14 27 07@2x](https://github.com/user-attachments/assets/7c5326b4-2de1-4458-8a4e-f9580bd477f1)


Tested with ReerJSON 0.1.0, ZippyJSON 1.2.15, IkigaJSON 2.3.2

[Code for Benchmarks](https://github.com/Asura19/ReerJSONBenchmark)

# Usage
Just replace `JSONDecoder` with `ReerJSONDecoder` wherever you want to use it. So instead of `let decoder = JSONDecoder()`, do `let decoder = ReerJSONDecoder()`, and everything will just work. This is because `ReerJSONDecoder` has the exact same API as `JSONDecoder`. Also, don't forget to add `import ReerJSON` in files where you use it.

# TODO
* [x] Add GitHub workflow for CI.
* [x] Support `CodableWithConfiguration`.
* [ ] Support JSON5 decoding.
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
* **[michaeleisel/ZippyJSON](https://github.com/michaeleisel/ZippyJSON)** - For the innovative Swift JSON parsing approach and valuable test cases used in our benchmarking.
* **[michaeleisel/JJLISO8601DateFormatter](https://github.com/michaeleisel/JJLISO8601DateFormatter)** - For the high-performance date formatting implementation.
* **[nixzhu/Ananda](https://github.com/nixzhu/Ananda)** - For the pioneering work in integrating yyjson with Swift and providing architectural inspiration.

Special thanks to all the open-source contributors who made this project possible.
