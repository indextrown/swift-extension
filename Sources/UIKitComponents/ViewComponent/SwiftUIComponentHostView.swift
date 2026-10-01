//
//  SwiftUIComponentHostView.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/1/26.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// SwiftUI 브리지에서만 쓰는 호스트 뷰입니다.
///
/// iOS 16 이상에서는 SwiftUI가 `UIViewRepresentable.sizeThatFits(_:uiView:context:)`로 크기를 묻고,
/// `updateUIView`를 부른 뒤에도 다시 묻습니다. 그래서 이 뷰는 `intrinsicContentSize`를 알리지 않고,
/// 갱신할 때 크기를 무효화하지도 않습니다. 두 경로를 함께 쓰면 SwiftUI가 같은 행을 두 번 잽니다.
///
/// iOS 15에는 `sizeThatFits`가 없어서 SwiftUI가 `intrinsicContentSize`만 봅니다. 그래서 배치된 너비를
/// 기억해 두고, 그 너비에서 잰 높이를 intrinsic 높이로 알립니다. 너비가 바뀌거나 갱신하면 다시 재도록 무효화합니다.
///
/// SwiftUI는 `makeUIView` 직후 `updateUIView`를 한 번 더 부릅니다. 만들 때 바로 갱신하면 `Equatable`이 아닌
/// 컴포넌트가 처음 나타날 때 두 번 갱신되고, 첫 갱신에서 시작한 작업이 곧바로 취소됩니다. 그래서 이 뷰는 첫 갱신을
/// 첫 `update(_:)`까지 미룹니다. 그 전에 크기를 재거나 배치하거나 창에 붙으면 그때 갱신합니다.
///
/// 세로 허깅·압축 저항을 `required`로 둬서 SwiftUI가 높이를 늘리거나 줄이지 않게 합니다.
/// UIKit용 `ComponentHostView`는 스택뷰에서 제약이 충돌하지 않도록 기본값을 그대로 둡니다.
@MainActor
final class SwiftUIComponentHostView<Component: ViewComponent>: UIView {

    // MARK: - Property

    /// 컴포넌트가 만든 뷰입니다.
    var hostedView: Component.UIViewType {
        return self.host.view
    }

    /// `updateView(_:context:)`를 부른 횟수입니다.
    var updateCount: Int {
        return self.host.updateCount
    }

    /// 크기를 `intrinsicContentSize`로 알릴지 나타냅니다.
    ///
    /// `sizeThatFits(_:uiView:context:)`가 없는 iOS 15에서만 `true`입니다. 테스트에서 iOS 15 경로를 확인할 때 바꿉니다.
    var usesIntrinsicSizing: Bool

    private let host: ComponentHost<Component>
    private var measuredWidth: CGFloat = 0

    override var intrinsicContentSize: CGSize {
        guard
            self.usesIntrinsicSizing,
            self.measuredWidth > 0
        else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }

        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: self.fittingSize(width: self.measuredWidth).height
        )
    }



    // MARK: - Life Cycle

    init(_ component: Component) {
        if #available(iOS 16.0, tvOS 16.0, *) {
            self.usesIntrinsicSizing = false
        } else {
            self.usesIntrinsicSizing = true
        }
        self.host = ComponentHost(component: component)
        super.init(frame: .zero)

        self.setAttribute()
        self.host.attach(to: self, updatesImmediately: false) { [weak self] in
            /// 갱신이 끝난 뒤 크기가 바뀐 경우입니다. iOS 16 이상에서도 SwiftUI는 이 무효화를 보고 `sizeThatFits`를 다시 부릅니다.
            self?.invalidateIntrinsicContentSize()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:)는 지원하지 않습니다.")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        self.host.performInitialUpdateIfNeeded()
    }

    override func layoutSubviews() {
        self.host.performInitialUpdateIfNeeded()
        super.layoutSubviews()

        guard
            self.usesIntrinsicSizing,
            self.bounds.width != self.measuredWidth
        else {
            return
        }

        self.measuredWidth = self.bounds.width
        self.invalidateIntrinsicContentSize()
    }



    // MARK: - Interface

    func update(_ component: Component) {
        guard
            self.host.update(component),
            self.usesIntrinsicSizing
        else {
            return
        }

        self.invalidateIntrinsicContentSize()
    }

    func suspend() {
        self.host.suspend()
    }

    func fittingSize(width: CGFloat?) -> CGSize {
        self.host.performInitialUpdateIfNeeded()
        return self.host.fittingSize(width: width)
    }



    // MARK: - UI

    private func setAttribute() {
        self.setContentHuggingPriority(.defaultLow, for: .horizontal)
        self.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        self.setContentHuggingPriority(.required, for: .vertical)
        self.setContentCompressionResistancePriority(.required, for: .vertical)
    }
}
#endif
