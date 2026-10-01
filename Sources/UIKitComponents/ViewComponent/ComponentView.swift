//
//  ComponentView.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/1/26.
//

#if canImport(UIKit) && !os(watchOS)
import SwiftUI
import UIKit

/// 컴포넌트를 SwiftUI 뷰 계층에 넣는 뷰입니다.
///
/// SwiftUI가 제안한 너비를 그대로 쓰고, 그 너비에서 뷰가 필요로 하는 높이를 Auto Layout으로 잽니다.
/// 그래서 `.frame(height:)`로 높이를 고정하지 않아도 여러 줄 레이블이 제 높이를 가집니다.
/// iOS 16 이상은 `UIViewRepresentable.sizeThatFits(_:uiView:context:)`로, iOS 15는 배치된 너비로
/// 계산한 `intrinsicContentSize`로 알립니다.
///
/// ```swift
/// ScrollView {
///     VStack {
///         ComponentView(NoticeComponent(title: "점검 안내"))
///     }
/// }
/// ```
///
/// SwiftUI가 뷰를 다시 그릴 때마다 `updateView(_:context:)`가 불립니다. 컴포넌트가 `Equatable`이면
/// 이전 값과 같을 때 건너뜁니다. 뷰 계층에서 빠지면 이번 갱신의 작업을 취소합니다.
public struct ComponentView<Component: ViewComponent>: View {

    // MARK: - Property

    private let component: Component



    // MARK: - Life Cycle

    /// 표시할 컴포넌트를 받습니다.
    ///
    /// - Parameter component: 표시할 컴포넌트입니다.
    /// - Complexity: O(1)입니다.
    public init(_ component: Component) {
        self.component = component
    }



    // MARK: - View

    /// 컴포넌트의 뷰를 담은 `UIViewRepresentable`입니다.
    ///
    /// - Complexity: O(1)입니다. 실제 갱신 비용은 `updateView(_:context:)`를 따릅니다.
    public var body: some View {
        ComponentRepresentable(component: self.component)
    }
}



// MARK: - ViewComponent + View

extension ViewComponent where Self: View {

    /// `View`를 함께 채택한 컴포넌트를 SwiftUI에 바로 넣을 수 있게 하는 기본 `body`입니다.
    ///
    /// ```swift
    /// extension NoticeComponent: View {}
    ///
    /// VStack {
    ///     NoticeComponent(title: "점검 안내")
    /// }
    /// ```
    ///
    /// `ComponentView(self)`와 같습니다.
    ///
    /// - Complexity: O(1)입니다. 실제 갱신 비용은 `updateView(_:context:)`를 따릅니다.
    public var body: some View {
        ComponentView(self)
    }
}
#endif
