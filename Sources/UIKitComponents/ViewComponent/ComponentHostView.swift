//
//  ComponentHostView.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/1/26.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// 컴포넌트 하나를 UIKit 뷰 계층에 넣는 호스트 뷰입니다.
///
/// `addSubview(_:)`나 `UIStackView.addArrangedSubview(_:)`로 넣고 Auto Layout으로 배치합니다.
/// 컴포넌트의 뷰를 네 변에 붙이므로 높이는 뷰의 제약에서 정해집니다. 상태가 바뀌면 `update(_:)`로
/// 새 컴포넌트를 넣습니다. 뷰는 다시 만들지 않습니다.
///
/// ```swift
/// let notice = ComponentHostView(NoticeComponent(title: "점검 안내"))
/// stackView.addArrangedSubview(notice)
///
/// notice.update(NoticeComponent(title: "점검이 끝났어요"))
/// ```
///
/// window에서 빠지면 이번 갱신의 작업(`ComponentContext.task(priority:_:)` 등)을 취소하고,
/// 다시 붙으면 마지막 컴포넌트로 다시 갱신합니다. 콘텐츠 허깅·압축 저항 우선순위는 기본값을 그대로 둬서
/// 높이가 고정된 스택뷰에서도 제약이 충돌하지 않습니다.
@MainActor
public final class ComponentHostView<Component: ViewComponent>: UIView {

    // MARK: - Property

    /// 컴포넌트가 만든 뷰입니다. 애니메이션처럼 뷰를 직접 다뤄야 할 때 씁니다.
    ///
    /// - Complexity: O(1)입니다.
    public var hostedView: Component.UIViewType {
        return self.host.view
    }

    /// 마지막으로 반영한 컴포넌트입니다.
    ///
    /// - Complexity: O(1)입니다.
    public var component: Component {
        return self.host.component
    }

    /// `updateView(_:context:)`를 부른 횟수입니다.
    var updateCount: Int {
        return self.host.updateCount
    }

    private let host: ComponentHost<Component>



    // MARK: - Life Cycle

    /// 컴포넌트로 호스트 뷰를 만들고 첫 갱신을 합니다.
    ///
    /// - Parameter component: 처음 표시할 컴포넌트입니다.
    /// - Complexity: `makeView()`와 첫 `updateView(_:context:)`의 비용을 따릅니다.
    public init(_ component: Component) {
        self.host = ComponentHost(component: component)
        super.init(frame: .zero)

        self.host.attach(to: self) { [weak self] in
            self?.invalidateIntrinsicContentSize()
            self?.setNeedsLayout()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:)는 지원하지 않습니다.")
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()

        if self.window == nil {
            self.host.suspend()
        } else {
            self.host.resumeIfNeeded()
        }
    }



    // MARK: - Interface

    /// 같은 뷰에 새 상태를 반영합니다.
    ///
    /// 컴포넌트가 `Equatable`이고 이전 값과 같으면 갱신을 건너뜁니다.
    ///
    /// - Parameter component: 반영할 컴포넌트입니다.
    /// - Complexity: `updateView(_:context:)`의 비용을 따릅니다. 갱신을 건너뛰면 `==` 비교 비용만 듭니다.
    public func update(_ component: Component) {
        self.host.update(component)
    }

    /// 주어진 너비에서 컴포넌트가 필요로 하는 크기를 돌려줍니다.
    ///
    /// Auto Layout 없이 프레임으로 배치할 때 씁니다. 너비가 0이거나 무한이면 뷰의 자연 크기를 돌려줍니다.
    ///
    /// - Parameter size: 제안받은 크기입니다. 높이는 무시합니다.
    /// - Returns: 제안받은 너비와 그 너비에서 필요한 높이입니다.
    /// - Complexity: Auto Layout 측정 비용을 따릅니다.
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        return self.host.fittingSize(width: size.width)
    }
}
#endif
