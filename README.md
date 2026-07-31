# SwiftExtension

High-performance extensions and low-level data structures for Swift.

SwiftExtension is a Swift Package Manager library for primitives that are
missing from the standard library or need a specialized, performance-oriented
implementation.

## Planned modules

- `Storage`: ownership-aware buffers and views
- `Collections`: chunked and packed collections
- `Buffers`: byte buffers and zero-copy parsing helpers
- `Numerics`: shaped arrays and numeric kernels
- `Indexes`: interval and spatial indexes

The package starts as a small, platform-neutral core. Platform-specific
backends such as Accelerate or Metal will be added as separate targets when
they are needed.

## Requirements

- Swift 6.3 or later
- Xcode 26.4 or later for Apple-platform development

## Usage

Add the package in Xcode with **File → Add Package Dependencies…** or add the
repository URL to `Package.swift`.

```swift
import SwiftExtension

print(SwiftExtension.version)
```

## License

License will be selected before the first public release.
