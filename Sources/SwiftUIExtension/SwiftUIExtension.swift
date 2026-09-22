/// The `SwiftUIExtension` module contains reusable SwiftUI views and modifiers.
///
/// This file intentionally has no public declarations yet. It establishes the
/// module boundary so clients can use `import SwiftUIExtension` as components
/// are added.
///
/// SwiftUI is available on every platform this package supports, but individual
/// APIs are not. Annotate declarations that need a newer OS with `@available`
/// instead of raising the package wide deployment targets.

/// `UIComponentsCore`의 단계·레이아웃·움직임 타입을 다시 내보냅니다.
/// `import SwiftUIExtension` 하나로 `BottomSheetLayout` 같은 타입을 쓸 수 있습니다.
@_exported import UIComponentsCore
