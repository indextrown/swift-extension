# SwiftExtension

[![Build](https://github.com/indextrown/swift-extension/actions/workflows/build.yml/badge.svg)](https://github.com/indextrown/swift-extension/actions/workflows/build.yml)
[![Test](https://github.com/indextrown/swift-extension/actions/workflows/test.yml/badge.svg)](https://github.com/indextrown/swift-extension/actions/workflows/test.yml)

High-performance extensions, low-level data structures, and reusable UI
components for Swift.

SwiftExtension is a Swift Package Manager library for primitives that are
missing from the standard library or need a specialized, performance-oriented
implementation. The core modules are platform neutral; UIKit and SwiftUI
components live in their own targets so clients only link what they use.

## Modules

| Module | Status | Contents |
| --- | --- | --- |
| `Algorithm` | Available | Data structures and algorithms. Currently `Stack`. |
| `Labs` | Available | Experimental implementations and playgrounds. Not part of the public API surface yet. |
| `SwiftExtension` | Available | Package-level entry point. Exposes `SwiftExtension.version`. |
| `UIComponentsCore` | Available | Framework-neutral logic shared by the UI modules (bottom sheet detents, layout math, motion). Foundation only. Re-exported by both UI modules. |
| `UIKitExtension` | Available | Reusable UIKit components. Currently `BottomSheetController`, a bottom sheet that rises from behind the tab bar. |
| `SwiftUIExtension` | Available | Reusable SwiftUI components. Currently the `bottomSheet(detent:)` modifier and `BottomSheetScrollView` (iOS 17+). |

Core modules never import UIKit, SwiftUI, or AppKit, so they can be used on
servers and command line tools as well as Apple platforms.

## Requirements

- Swift 5.9 or later to build the package (`swift-tools-version: 5.9`)
- Swift 6.0 or later (Xcode 16+) to run the tests, which use Swift Testing
- iOS 15+, macOS 12+, tvOS 15+, watchOS 8+

## Installation

Add the package in Xcode with **File → Add Package Dependencies…**, or declare
it in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/indextrown/swift-extension.git", from: "0.1.0")
]
```

Then add the products you need to your target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "Algorithm", package: "swift-extension")
    ]
)
```

## Usage

Each product can be imported on its own.

```swift
import Algorithm

var stack = Stack([1, 2, 3])
stack.push(4)

print(stack.top)   // Optional(4)
print(stack.pop()) // Optional(4)
```

> `Stack`'s initializers are still `internal`, so the type cannot be
> constructed from outside the `Algorithm` module yet. Making them `public` is
> required before the first release.

```swift
import SwiftExtension

print(SwiftExtension.version)
```

## Development

```bash
swift build            # build all targets
swift test             # run all tests
swift test -c release  # run tests with optimizations enabled
```

Every push to `main` and every pull request runs two workflows on a macOS
runner: `Build` (debug and release) and `Test`.

Repository layout:

```text
Sources/
├── Algorithm/         data structures and algorithms
├── Labs/              experimental code and playgrounds
├── SwiftExtension/    package entry point
├── UIComponentsCore/  logic shared by the UI modules (Foundation only)
├── UIKitExtension/    reusable UIKit components
└── SwiftUIExtension/  reusable SwiftUI components
Tests/                 one test target per product
Demo/                  sample apps: AlgorithmDemo (macOS), SwiftExtensionDemo (iOS)
docs/                  architecture and development guides (Korean)
```

## Documentation

Development guides are written in Korean.

- [패키지 구조](docs/architecture/architecture.md) — targets, module boundaries, dependency direction
- [API 설계 규칙](docs/architecture/api-design.md) — public API naming, access control, compatibility
- [성능 기준](docs/architecture/performance.md) — value semantics, allocation, measurement
- [UI 모듈 가이드](docs/architecture/ui-modules.md) — rules for the UIKit and SwiftUI targets
- [바텀시트](docs/components/bottom-sheet.md) — `BottomSheetController` usage, scroll tracking, verification
- [Swift 스타일](docs/development/swiftstyle.md) — formatting and naming
- [테스트](docs/development/testing.md) — test targets and commands
- [Git 작업 흐름](docs/development/gitflow.md) — branches, commits, pull requests
- [PR 작성 가이드](docs/development/pr-writing.md) — what to write in a PR title and body, evidence, videos, stacked PRs

## License

License will be selected before the first public release.
