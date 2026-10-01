//
//  ComponentContentView.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/1/26.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// `ComponentConfiguration`을 셀 안에 표시하는 content view입니다.
///
/// 셀이 재사용되면 UIKit이 `configuration`에 새 설정을 넣습니다. 그때 뷰를 다시 만들지 않고 갱신만 합니다.
@MainActor
final class ComponentContentView<Component: ViewComponent>: UIView, UIContentView {

    // MARK: - Property

    var configuration: UIContentConfiguration {
        get {
            return self.currentConfiguration
        }
        set {
            guard let configuration = newValue as? ComponentConfiguration<Component> else {
                assertionFailure("ComponentContentView<\(Component.self)>에 다른 설정이 전달됐습니다.")
                return
            }

            let isSameConfiguration = configuration.revision === self.currentConfiguration.revision
            self.currentConfiguration = configuration

            /// 셀 상태만 바뀌어 `updated(for:)`로 같은 설정이 다시 들어온 경우입니다. 갱신하지 않습니다.
            guard !isSameConfiguration else { return }

            self.host.update(configuration.component)
        }
    }

    /// 컴포넌트가 만든 뷰입니다.
    var hostedView: Component.UIViewType {
        return self.host.view
    }

    /// `updateView(_:context:)`를 부른 횟수입니다.
    var updateCount: Int {
        return self.host.updateCount
    }

    private var currentConfiguration: ComponentConfiguration<Component>
    private let host: ComponentHost<Component>



    // MARK: - Life Cycle

    init(configuration: ComponentConfiguration<Component>) {
        self.currentConfiguration = configuration
        self.host = ComponentHost(component: configuration.component)
        super.init(frame: .zero)

        self.host.attach(to: self) { [weak self] in
            /// iOS 16부터 셀은 content view의 intrinsic 크기 무효화를 보고 크기를 다시 잽니다(`selfSizingInvalidation`).
            self?.invalidateIntrinsicContentSize()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:)는 지원하지 않습니다.")
    }



    // MARK: - UIContentView

    @available(iOS 16.0, tvOS 16.0, *)
    func supports(_ configuration: UIContentConfiguration) -> Bool {
        return configuration is ComponentConfiguration<Component>
    }
}
#endif
