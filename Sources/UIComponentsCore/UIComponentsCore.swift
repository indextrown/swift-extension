/// The `UIComponentsCore` module holds UI-framework-neutral logic that
/// `UIKitExtension` and `SwiftUIExtension` share, such as bottom sheet detents,
/// layout math, and motion parameters.
///
/// It imports Foundation only. That keeps it buildable and testable on every
/// platform, including the macOS CI runner that cannot compile UIKit code.
/// Both UI modules re-export it, so `import UIKitExtension` or
/// `import SwiftUIExtension` alone is enough to use these types.
