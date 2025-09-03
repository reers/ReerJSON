# ReerJSON
## A faster version of JSONDecoder based on [yyjson](https://github.com/ibireme/yyjson)

ReerJSON is a really fast JSON parser, and it's inspired by [ZippyJSON](https://github.com/michaeleisel/ZippyJSON) and [Ananda](https://github.com/nixzhu/Ananda).

> **⚠️Important:** When measuring the performance of Swift libraries, make sure you're building in **Release Mode**. 
> When building Swift code on DEBUG compilation, it can be 10-20x slower than equivalent code on RELEASE.

# Benchmarks


# Usage
Just replace `JSONDecoder` with `ReerJSONDecoder` wherever you want to use it. So instead of `let decoder = JSONDecoder()`, do `let decoder = ReerJSONDecoder()`, and everything will just work. This is because `ReerJSONDecoder` has the exact same API as `JSONDecoder`. Also, don't forget to add `import ReerJSON` in files where you use it.

# TODO
* [x] Add GitHub workflow for CI.
* [x] Support `CodableWithConfiguration`.
* [ ] Support JSON5 decoding.
* [ ] Implement ReerJSONEncoder.

# License
This project is licensed under the MIT License. See the LICENSE file for details.
Portions of this project incorporate code from the following sources:

[swiftlang/swift-foundation](https://github.com/swiftlang/swift-foundation), licensed under the Apache License, Version 2.0.
[michaeleisel/ZippyJSON](https://github.com/michaeleisel/ZippyJSON), licensed under the MIT License.

See the LICENSE file for the full text of both licenses.
Acknowledgments

Thanks to the contributors of [swiftlang/swift-foundation](https://github.com/swiftlang/swift-foundation) for their Apache 2.0 licensed code.
Thanks to [michaeleisel/ZippyJSON](https://github.com/michaeleisel/ZippyJSON) for their MIT licensed test code.
