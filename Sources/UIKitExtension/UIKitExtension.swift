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

/// `UIComponentsCore`의 단계·레이아웃·움직임 타입을 다시 내보냅니다.
/// `import UIKitExtension` 하나로 `BottomSheetLayout` 같은 타입을 쓸 수 있습니다.
@_exported import UIComponentsCore
