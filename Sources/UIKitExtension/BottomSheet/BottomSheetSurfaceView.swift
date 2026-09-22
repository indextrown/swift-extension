//
//  BottomSheetSurfaceView.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import UIKit

/// 바텀시트의 겉면입니다. 배경, 모서리, 그림자, 손잡이와 콘텐츠 자리를 그립니다.
///
/// 위치와 제스처는 `BottomSheetController`가 다루고 이 View는 모양만 맡습니다.
@MainActor
final class BottomSheetSurfaceView: UIView {

    // MARK: - Property

    /// 손잡이가 놓이는 영역입니다. VoiceOver 조작도 이 View가 받습니다.
    let handleView: BottomSheetHandleView

    /// 콘텐츠 화면의 View가 들어가는 자리입니다.
    let contentContainerView = UIView()

    private let appearance: BottomSheetAppearance



    // MARK: - Life Cycle

    init(appearance: BottomSheetAppearance) {
        self.appearance = appearance
        self.handleView = BottomSheetHandleView(appearance: appearance)
        super.init(frame: .zero)

        self.setAttribute()
        self.setConstraint()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        /// 그림자 경로를 미리 알려 주면 매 프레임 알파 채널에서 윤곽을 계산하지 않습니다.
        /// 시트는 끌 때마다 다시 그려지므로 이 비용이 그대로 프레임에 얹힙니다.
        self.layer.shadowPath = UIBezierPath(
            roundedRect: self.bounds,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: self.appearance.cornerRadius, height: self.appearance.cornerRadius)
        ).cgPath
    }



    // MARK: - Interface

    /// 그림자를 보이거나 숨깁니다.
    ///
    /// 완전히 내린 단계에서는 시트 본체가 탭바 뒤로 들어가지만 그림자는 그 위로 번져
    /// 시트가 남은 것처럼 보이므로 숨겨야 합니다.
    func setShadowVisible(_ isVisible: Bool) {
        self.layer.shadowOpacity = isVisible ? self.appearance.shadowOpacity : 0
    }



    // MARK: - UI

    private func setAttribute() {
        /// 위치가 정해지기 전에 한 번 그려지면 시트가 전체 화면으로 보였다가 제자리를 찾습니다.
        self.isHidden = true

        self.backgroundColor = self.appearance.backgroundColor
        self.layer.cornerRadius = self.appearance.cornerRadius
        self.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        /// 그림자를 그리려면 경계를 잘라 내지 않아야 합니다. 콘텐츠는 아래 컨테이너가 잘라 냅니다.
        self.layer.masksToBounds = false
        self.layer.shadowColor = self.appearance.shadowColor.cgColor
        self.layer.shadowOpacity = self.appearance.shadowOpacity
        self.layer.shadowRadius = self.appearance.shadowRadius
        self.layer.shadowOffset = self.appearance.shadowOffset

        self.contentContainerView.clipsToBounds = true

        /// 손잡이 영역이 없으면 콘텐츠가 둥근 모서리까지 올라오므로 컨테이너도 같은 모서리로 잘라 냅니다.
        if self.appearance.showsGrabber == false || self.appearance.handleAreaHeight == 0 {
            self.contentContainerView.layer.cornerRadius = self.appearance.cornerRadius
            self.contentContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
    }

    private func setConstraint() {
        [self.handleView, self.contentContainerView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview($0)
        }

        let handleHeight = self.appearance.showsGrabber ? self.appearance.handleAreaHeight : 0

        NSLayoutConstraint.activate([
            self.handleView.topAnchor.constraint(equalTo: self.topAnchor),
            self.handleView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.handleView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.handleView.heightAnchor.constraint(equalToConstant: handleHeight),

            self.contentContainerView.topAnchor.constraint(equalTo: self.handleView.bottomAnchor),
            self.contentContainerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.contentContainerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.contentContainerView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
}



// MARK: - Handle

/// 손잡이를 그리고 VoiceOver의 위아래 조작을 받는 View입니다.
@MainActor
final class BottomSheetHandleView: UIView {

    // MARK: - Property

    /// VoiceOver에서 값을 올리면 호출합니다. 시트를 한 단계 올리는 데 씁니다.
    var onIncrement: (() -> Void)?

    /// VoiceOver에서 값을 내리면 호출합니다. 시트를 한 단계 내리는 데 씁니다.
    var onDecrement: (() -> Void)?

    private let grabberView = UIView()



    // MARK: - Life Cycle

    init(appearance: BottomSheetAppearance) {
        super.init(frame: .zero)

        self.isAccessibilityElement = appearance.showsGrabber
        self.accessibilityLabel = appearance.handleAccessibilityLabel
        self.accessibilityTraits = .adjustable

        self.grabberView.isHidden = appearance.showsGrabber == false
        self.grabberView.backgroundColor = appearance.grabberColor
        self.grabberView.layer.cornerRadius = appearance.grabberSize.height / 2
        self.grabberView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.grabberView)

        NSLayoutConstraint.activate([
            self.grabberView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self.grabberView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.grabberView.widthAnchor.constraint(equalToConstant: appearance.grabberSize.width),
            self.grabberView.heightAnchor.constraint(equalToConstant: appearance.grabberSize.height)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }



    // MARK: - Accessibility

    override func accessibilityIncrement() {
        self.onIncrement?()
    }

    override func accessibilityDecrement() {
        self.onDecrement?()
    }
}
#endif
