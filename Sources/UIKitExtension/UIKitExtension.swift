/// The `UIKitExtension` module contains reusable UIKit views and extensions.
///
/// This file intentionally has no public declarations yet. It establishes the
/// module boundary so clients can use `import UIKitExtension` as components are
/// added.
///
/// UIKit is not available on every platform this package supports, so every
/// declaration in this module must be guarded:
///
/// ```swift
/// #if canImport(UIKit) && !os(watchOS)
/// import UIKit
///
/// // UIView based components
/// #endif
/// ```
///
/// On macOS the module still builds; it is simply empty.
