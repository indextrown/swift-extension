//
//  ComponentRepresentable.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/1/26.
//

#if canImport(UIKit) && !os(watchOS)
import SwiftUI
import UIKit

/// `ComponentView`가 쓰는 `UIViewRepresentable`입니다.
///
/// 크기 계산은 `SwiftUIComponentHostView`가 맡고, 이 타입은 SwiftUI 수명 이벤트를 전달합니다.
struct ComponentRepresentable<Component: ViewComponent>: UIViewRepresentable {

    // MARK: - Property

    let component: Component



    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> SwiftUIComponentHostView<Component> {
        return SwiftUIComponentHostView(self.component)
    }

    func updateUIView(
        _ uiView: SwiftUIComponentHostView<Component>,
        context: Context
    ) {
        uiView.update(self.component)
    }

    static func dismantleUIView(
        _ uiView: SwiftUIComponentHostView<Component>,
        coordinator: ()
    ) {
        uiView.suspend()
    }

    /// 제안받은 너비에서 필요한 높이를 돌려줍니다. 너비가 없으면 뷰의 자연 크기를 돌려줍니다.
    @available(iOS 16.0, tvOS 16.0, *)
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: SwiftUIComponentHostView<Component>,
        context: Context
    ) -> CGSize? {
        return uiView.fittingSize(width: proposal.width)
    }
}
#endif
