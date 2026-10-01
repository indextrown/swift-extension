//
//  ViewComponent.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/1/26.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// UIKit 뷰 하나를 만들고 현재 상태를 반영하는 컴포넌트입니다.
///
/// 컴포넌트는 표시할 상태를 담는 값이고, 실제 화면은 `UIViewType`입니다. 호스트는 뷰를
/// `makeView()`로 한 번만 만들고, 상태가 바뀔 때마다 같은 뷰에 `updateView(_:context:)`를
/// 다시 부릅니다. SwiftUI `UIViewRepresentable`의 `makeUIView`·`updateUIView`와 같은 짝입니다.
///
/// 같은 컴포넌트를 세 곳에 그대로 넣습니다.
///
/// | 넣을 곳 | 방법 |
/// | --- | --- |
/// | UIKit 뷰, `UIStackView` | `ComponentHostView(component)` |
/// | `UITableViewCell`, `UICollectionViewCell` | `cell.contentConfiguration = component.contentConfiguration()` |
/// | SwiftUI | `ComponentView(component)`, 또는 `View`를 함께 채택한 컴포넌트 그대로 |
///
/// ```swift
/// struct NoticeComponent: ViewComponent, Equatable {
///     let title: String
///
///     func makeView() -> NoticeView {
///         NoticeView()
///     }
///
///     func updateView(_ view: NoticeView, context: ComponentContext) {
///         view.titleLabel.text = self.title
///     }
/// }
/// ```
///
/// 컴포넌트가 `Equatable`이면 호스트는 이전 값과 같을 때 `updateView(_:context:)`를 건너뜁니다.
/// 클로저를 담은 컴포넌트는 `Equatable`을 채택할 수 없으므로 매번 갱신합니다.
public protocol ViewComponent {

    /// 컴포넌트가 만들고 갱신하는 UIKit 뷰 타입입니다.
    associatedtype UIViewType: UIView

    /// 호스트 수명 동안 한 번만 호출되어 뷰를 만듭니다.
    ///
    /// 상태와 무관한 구성(서브뷰, 제약, 고정 스타일)만 여기서 합니다.
    /// 상태에 따라 바뀌는 값은 `updateView(_:context:)`에서 넣습니다.
    @MainActor
    func makeView() -> UIViewType

    /// 현재 상태를 뷰에 반영합니다.
    ///
    /// 같은 뷰에 여러 번 호출되므로 이전 상태를 덮어쓰도록 작성합니다. 셀이 재사용되면
    /// 다른 항목을 그리던 뷰가 넘어올 수 있습니다.
    ///
    /// - Parameters:
    ///   - view: `makeView()`로 만든 뷰입니다.
    ///   - context: 이번 갱신의 작업 수명입니다. 다음 갱신 직전이나 화면에서 빠질 때 취소됩니다.
    @MainActor
    func updateView(_ view: UIViewType, context: ComponentContext)
}



// MARK: - Cell

extension ViewComponent {

    /// 셀의 `contentConfiguration`에 넣을 설정을 만듭니다.
    ///
    /// ```swift
    /// cell.contentConfiguration = NoticeComponent(title: notice.title).contentConfiguration()
    /// ```
    ///
    /// - Returns: 이 컴포넌트를 담은 설정입니다.
    /// - Complexity: O(1)입니다.
    public func contentConfiguration() -> ComponentConfiguration<Self> {
        return ComponentConfiguration(self)
    }
}
#endif
