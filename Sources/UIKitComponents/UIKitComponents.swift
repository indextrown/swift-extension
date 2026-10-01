/// The `UIKitComponents` module turns a plain `UIView` into a `ViewComponent`
/// that can be placed in UIKit and SwiftUI with the same code.
///
/// - UIKit views and stack views: `ComponentHostView`
/// - Table and collection view cells: `contentConfiguration()`
/// - SwiftUI: `ComponentView`, or the component itself when it also conforms to `View`
///
/// Unlike `UIKitExtension` and `SwiftUIExtension`, this module imports UIKit and
/// SwiftUI together because its purpose is to bridge UIKit views into SwiftUI.
/// Every UIKit declaration is guarded with `#if canImport(UIKit) && !os(watchOS)`.
/// On macOS and watchOS only `ComponentContext` is compiled, which keeps the
/// render lifetime logic testable on the macOS CI runner.
