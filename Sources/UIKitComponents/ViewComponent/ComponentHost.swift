//
//  ComponentHost.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/1/26.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// 컴포넌트의 뷰를 한 번 만들고, 갱신 수명과 크기 계산을 맡는 내부 타입입니다.
///
/// `ComponentHostView`, 셀의 `ComponentContentView`, SwiftUI의 `SwiftUIComponentHostView`가
/// 모두 이 타입을 씁니다. 세 호스트가 같은 규칙으로 뷰를 만들고 갱신하고 정리하게 하려고 한곳에 모았습니다.
@MainActor
final class ComponentHost<Component: ViewComponent> {

    // MARK: - Property

    /// `makeView()`로 만든 뷰입니다. 호스트 수명 동안 바뀌지 않습니다.
    let view: Component.UIViewType

    /// 마지막으로 반영한 컴포넌트입니다.
    private(set) var component: Component

    /// `updateView(_:context:)`를 부른 횟수입니다. 테스트에서 갱신을 건너뛰었는지 확인할 때 씁니다.
    private(set) var updateCount = 0

    private var context: ComponentContext?
    private var layoutInvalidation: () -> Void = {}



    // MARK: - Life Cycle

    init(component: Component) {
        self.component = component
        self.view = component.makeView()
    }



    // MARK: - Interface

    /// 뷰를 컨테이너의 네 변에 붙이고 첫 갱신을 합니다.
    ///
    /// - Parameters:
    ///   - container: 뷰를 담을 호스트 뷰입니다.
    ///   - layoutInvalidation: 컴포넌트가 `invalidateLayout()`을 부르면 실행할 동작입니다.
    func attach(
        to container: UIView,
        layoutInvalidation: @escaping () -> Void
    ) {
        self.layoutInvalidation = layoutInvalidation

        self.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(self.view)
        NSLayoutConstraint.activate([
            self.view.topAnchor.constraint(equalTo: container.topAnchor),
            self.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            self.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            self.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        self.performUpdate()
    }

    /// 새 상태를 반영합니다.
    ///
    /// `Equatable` 컴포넌트가 이전 값과 같고 수명이 살아 있으면 갱신을 건너뜁니다.
    ///
    /// - Parameter component: 반영할 컴포넌트입니다.
    /// - Returns: `updateView(_:context:)`를 불렀으면 `true`입니다.
    @discardableResult
    func update(_ component: Component) -> Bool {
        let isUnchanged = self.context != nil && self.isEqual(self.component, component)
        self.component = component
        guard !isUnchanged else { return false }

        self.performUpdate()
        return true
    }

    /// 화면에서 빠질 때 이번 갱신의 작업을 취소합니다.
    func suspend() {
        self.context?.cancel()
        self.context = nil
    }

    /// 화면에 다시 붙을 때, 취소된 작업이 있으면 마지막 컴포넌트로 다시 갱신합니다.
    func resumeIfNeeded() {
        guard self.context == nil else { return }

        self.performUpdate()
    }

    /// 주어진 너비에서 뷰가 필요로 하는 크기를 계산합니다.
    ///
    /// 너비가 없거나 0 이하이거나 무한이면 뷰의 자연 크기를 돌려줍니다.
    ///
    /// - Parameter width: 제안받은 너비입니다.
    /// - Returns: 너비는 그대로 두고 높이를 Auto Layout으로 잰 크기입니다.
    func fittingSize(width: CGFloat?) -> CGSize {
        guard
            let width,
            width.isFinite,
            width > 0
        else {
            return self.view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        }

        let size = self.view.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return CGSize(width: width, height: ceil(size.height))
    }



    // MARK: - Update

    private func performUpdate() {
        self.context?.cancel()

        let context = ComponentContext(layoutInvalidation: self.layoutInvalidation)
        self.context = context
        self.component.updateView(self.view, context: context)
        self.updateCount += 1
    }

    private func isEqual(_ lhs: Component, _ rhs: Component) -> Bool {
        guard let lhs = lhs as? any Equatable else { return false }

        return lhs.isEqual(to: rhs)
    }
}



// MARK: - Equatable

extension Equatable {

    /// 타입이 지워진 값과 같은지 비교합니다. 타입이 다르면 `false`입니다.
    fileprivate func isEqual(to other: Any) -> Bool {
        return (other as? Self) == self
    }
}
#endif
