//
//  BottomSheetDockView.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/23/26.
//

#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import UIComponentsCore
import UIKit

/// 시트 위에 세로로 쌓이는 둥근 버튼 묶음(도크)입니다.
///
/// 지도 앱의 현재 위치·확대 버튼처럼 시트 윗선에 붙어 함께 오르내리는 컨트롤을 담아요. 자리 잡기는
/// `BottomSheetController.attachDock(_:alignment:insets:)`가 해 주므로 이 View는 쌓기와 간격, 그리고
/// 항목별 표시 규칙만 맡습니다.
///
/// 항목마다 `setVisibility(_:for:)`로 어느 단계에서 보일지 정할 수 있어요. 시트가 머무는 단계가 바뀌면
/// 컨트롤러가 `update(for:animated:)`를 불러 해당 항목을 페이드로 넣고 빼요. "시트가 내려가 있을 때만
/// 보이는 올리기 버튼"이 대표적인 쓰임이에요.
///
/// ```swift
/// let openButton = BottomSheetDockView.makeButton(systemImage: "chevron.up", accessibilityLabel: "시트 열기", action: open)
/// let dock = BottomSheetDockView(arrangedSubviews: [openButton, locateButton])
/// dock.setVisibility(.whenHidden, for: openButton)   // hidden에서만 보이고, 누르면 시트가 올라가며 사라져요
/// sheet.attachDock(dock)
/// ```
@MainActor
public final class BottomSheetDockView: UIStackView {

    /// 도크 버튼의 한 변 길이입니다. 손가락으로 누르기 좋은 최소 크기예요.
    public static let buttonSize: CGFloat = 44

    /// 항목이 나타나고 사라질 때 쓰는 애니메이션 길이입니다.
    public static let visibilityAnimationDuration: TimeInterval = 0.25

    private var visibilities: [UIView: BottomSheetDockVisibility] = [:]

    /// 세로 스택으로 만듭니다.
    ///
    /// - Parameters:
    ///   - arrangedSubviews: 위에서 아래 순서로 쌓을 View입니다.
    ///   - spacing: View 사이 간격입니다. 기본값은 12pt입니다.
    public init(arrangedSubviews: [UIView] = [], spacing: CGFloat = 12) {
        super.init(frame: .zero)

        self.axis = .vertical
        self.alignment = .center
        self.spacing = spacing
        arrangedSubviews.forEach(self.addArrangedSubview)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:)는 지원하지 않습니다.")
    }

    /// 항목이 보일 단계를 정합니다. 기본값은 `always`예요.
    ///
    /// 컨트롤러에 붙어 있으면 시트가 머무는 단계가 바뀔 때마다 반영돼요. 붙기 전에 정해 두면 붙을 때 반영됩니다.
    ///
    /// - Parameters:
    ///   - visibility: 표시 규칙입니다.
    ///   - view: 이 도크의 arranged subview입니다.
    /// - Complexity: O(1)입니다.
    public func setVisibility(_ visibility: BottomSheetDockVisibility, for view: UIView) {
        self.visibilities[view] = visibility
    }

    /// 항목의 표시 규칙입니다. 정한 적이 없으면 `always`예요.
    public func visibility(for view: UIView) -> BottomSheetDockVisibility {
        return self.visibilities[view] ?? .always
    }

    /// 시트가 머무는 단계에 맞춰 항목을 넣고 뺍니다.
    ///
    /// `BottomSheetController`가 단계가 바뀔 때 불러 줘요. 직접 부를 일은 거의 없어요.
    /// 숨길 항목은 `isHidden`으로 빼서 스택의 간격도 함께 사라지고, 알파를 같이 바꿔 페이드돼요.
    ///
    /// - Parameters:
    ///   - detent: 시트가 머무는 단계의 이름입니다.
    ///   - animated: 페이드 애니메이션을 쓸지 정합니다.
    /// - Complexity: O(n)입니다. n은 항목 개수입니다.
    public func update(for detent: BottomSheetDetent.Identifier, animated: Bool) {
        let changes = self.arrangedSubviews.compactMap { view -> (UIView, Bool)? in
            let visible = self.visibility(for: view).isVisible(at: detent)

            return view.isHidden == !visible ? nil : (view, visible)
        }

        guard changes.isEmpty == false else { return }

        let apply = {
            for (view, visible) in changes {
                view.isHidden = !visible
                view.alpha = visible ? 1 : 0
            }
        }

        guard animated else { return apply() }

        UIView.animate(
            withDuration: Self.visibilityAnimationDuration,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseOut],
            animations: apply
        )
    }

    /// 도크에 어울리는 44pt 원형 버튼을 만듭니다.
    ///
    /// 바탕은 `systemBackground`, 아이콘은 `systemBlue`이고 옅은 그림자가 있어 지도 위에서 잘 보여요.
    ///
    /// - Parameters:
    ///   - systemImage: SF Symbols 이름입니다.
    ///   - accessibilityLabel: VoiceOver가 읽을 이름입니다. 아이콘만 있는 버튼이라 꼭 넣어요.
    ///   - action: 누를 때 실행할 동작입니다.
    public static func makeButton(systemImage: String, accessibilityLabel: String, action: UIAction) -> UIButton {
        let button = UIButton(type: .system, primaryAction: action)
        button.configuration = {
            var configuration = UIButton.Configuration.filled()
            configuration.image = UIImage(systemName: systemImage)
            configuration.baseBackgroundColor = .systemBackground
            configuration.baseForegroundColor = .systemBlue
            configuration.cornerStyle = .capsule
            configuration.contentInsets = .zero
            return configuration
        }()
        button.accessibilityLabel = accessibilityLabel
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.15
        button.layer.shadowRadius = 6
        button.layer.shadowOffset = CGSize(width: 0, height: 2)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: Self.buttonSize),
            button.heightAnchor.constraint(equalToConstant: Self.buttonSize)
        ])

        return button
    }
}
#endif
