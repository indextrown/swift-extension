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

    /// 화면에서 빠져 있는지 나타냅니다. 빠져 있는 동안 갱신하면 뷰만 바꾸고 작업은 시작하지 않습니다.
    private var isSuspended = false



    // MARK: - Life Cycle

    init(component: Component) {
        self.component = component
        self.view = component.makeView()
    }

    /// 호스트를 가진 뷰가 해제되면 마지막 갱신의 작업도 끝냅니다.
    ///
    /// 셀이 사라지거나, 창에 붙은 적 없는 호스트 뷰가 해제되면 다음 갱신이 오지 않습니다.
    /// 여기서 취소하지 않으면 `task(priority:_:)`로 시작한 작업이 뷰를 붙잡은 채 계속 돕니다.
    /// UIView는 메인 스레드에서 해제되므로 보통 바로 취소하고, 다른 스레드라면 메인 액터로 넘겨 취소합니다.
    deinit {
        guard let context = self.context else { return }

        if Thread.isMainThread {
            MainActor.assumeIsolated { context.cancel() }
        } else {
            Task { @MainActor in context.cancel() }
        }
    }



    // MARK: - Interface

    /// 뷰를 컨테이너의 네 변에 붙이고 첫 갱신을 합니다.
    ///
    /// - Parameters:
    ///   - container: 뷰를 담을 호스트 뷰입니다.
    ///   - updatesImmediately: `false`면 첫 갱신을 `update(_:)`나 `performInitialUpdateIfNeeded()`까지 미룹니다.
    ///   - layoutInvalidation: 컴포넌트가 `invalidateLayout()`을 부르면 실행할 동작입니다.
    func attach(
        to container: UIView,
        updatesImmediately: Bool = true,
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

        if updatesImmediately {
            self.performUpdate()
        }
    }

    /// 아직 한 번도 갱신하지 않았으면 마지막 컴포넌트로 갱신합니다.
    ///
    /// 첫 갱신을 미룬 호스트가 크기를 재거나 배치하기 전에 부릅니다.
    func performInitialUpdateIfNeeded() {
        guard self.updateCount == 0 else { return }

        self.performUpdate()
    }

    /// 새 상태를 반영합니다.
    ///
    /// `Equatable` 컴포넌트가 이전 값과 같으면 갱신을 건너뜁니다. 화면에서 빠져 있는 동안에는
    /// 이미 취소된 context로 갱신해서 뷰만 바꾸고 작업은 시작하지 않습니다.
    ///
    /// - Parameter component: 반영할 컴포넌트입니다.
    /// - Returns: `updateView(_:context:)`를 불렀으면 `true`입니다.
    @discardableResult
    func update(_ component: Component) -> Bool {
        let isUnchanged = self.updateCount > 0 && self.isEqual(self.component, component)
        self.component = component
        guard !isUnchanged else { return false }

        self.performUpdate()
        return true
    }

    /// 화면에서 빠질 때 이번 갱신의 작업을 취소합니다.
    func suspend() {
        self.isSuspended = true
        self.context?.cancel()
    }

    /// 화면에 다시 붙을 때 마지막 컴포넌트로 다시 갱신해서 작업을 새로 시작합니다.
    func resumeIfNeeded() {
        guard self.isSuspended else { return }

        self.isSuspended = false
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
        if self.isSuspended {
            /// 화면 밖에서는 작업이 돌지 않게 미리 취소해 둡니다. 등록한 정리 동작은 바로 실행됩니다.
            context.cancel()
        }
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
