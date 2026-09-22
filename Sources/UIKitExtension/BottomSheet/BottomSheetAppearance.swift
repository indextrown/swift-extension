//
//  BottomSheetAppearance.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import UIComponentsCore
import UIKit

/// 바텀시트의 표시 속성입니다.
///
/// 색, 모서리, 손잡이, 그림자처럼 화면마다 달라질 수 있는 값을 한곳에 모았습니다.
/// 인자를 생략하면 시스템 배경색 위에 얇은 손잡이와 옅은 그림자가 있는 기본 모양이 됩니다.
public struct BottomSheetAppearance {

    /// 시트 배경색입니다.
    public var backgroundColor: UIColor

    /// 위쪽 두 모서리의 둥근 정도입니다.
    public var cornerRadius: CGFloat

    /// 손잡이를 그릴지 정합니다. `false`면 손잡이 영역도 함께 사라집니다.
    public var showsGrabber: Bool

    /// 손잡이의 크기입니다.
    public var grabberSize: CGSize

    /// 손잡이의 색입니다.
    public var grabberColor: UIColor

    /// 손잡이가 놓이는 영역의 높이입니다. 콘텐츠는 이 영역 아래에서 시작합니다.
    public var handleAreaHeight: CGFloat

    /// 시트 위쪽에 드리우는 그림자의 색입니다.
    public var shadowColor: UIColor

    /// 그림자의 진하기입니다. 0이면 그림자를 그리지 않습니다.
    public var shadowOpacity: Float

    /// 그림자가 퍼지는 정도입니다.
    public var shadowRadius: CGFloat

    /// 그림자가 어긋나는 거리입니다. 위쪽으로 살짝 올리는 값이 기본입니다.
    public var shadowOffset: CGSize

    /// 시트 뒤를 어둡게 덮는 판입니다. `nil`이면 덮지 않습니다.
    ///
    /// 지도 위 시트처럼 뒤 화면을 계속 조작해야 하면 `nil`로 둡니다.
    public var backdrop: BottomSheetBackdrop?

    /// VoiceOver가 손잡이를 읽을 때 쓰는 이름입니다.
    public var handleAccessibilityLabel: String

    /// 표시 속성을 주입받습니다. 인자를 생략하면 기본값을 씁니다.
    public init(
        backgroundColor: UIColor = .systemBackground,
        cornerRadius: CGFloat = 16,
        showsGrabber: Bool = true,
        grabberSize: CGSize = CGSize(width: 36, height: 5),
        grabberColor: UIColor = .tertiaryLabel,
        handleAreaHeight: CGFloat = 28,
        shadowColor: UIColor = .black,
        shadowOpacity: Float = 0.12,
        shadowRadius: CGFloat = 8,
        shadowOffset: CGSize = CGSize(width: 0, height: -2),
        backdrop: BottomSheetBackdrop? = nil,
        handleAccessibilityLabel: String = "Sheet"
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.showsGrabber = showsGrabber
        self.grabberSize = grabberSize
        self.grabberColor = grabberColor
        self.handleAreaHeight = handleAreaHeight
        self.shadowColor = shadowColor
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
        self.backdrop = backdrop
        self.handleAccessibilityLabel = handleAccessibilityLabel
    }

    /// 시스템 배경색과 옅은 그림자를 쓰는 기본 모양입니다.
    public static let `default` = BottomSheetAppearance()
}



// MARK: - Backdrop

/// 시트 뒤를 어둡게 덮는 판의 설정입니다.
///
/// 시트가 올라갈수록 진해지고, 정한 단계 아래로 내려가면 사라집니다.
public struct BottomSheetBackdrop {

    /// 판의 색입니다.
    public var color: UIColor

    /// 시트가 가장 높은 단계에 있을 때의 투명도입니다.
    public var maximumAlpha: CGFloat

    /// 이 단계와 그보다 낮은 단계에서는 판을 그리지 않습니다.
    ///
    /// `nil`이면 가장 낮은 단계에서 0으로 시작해 가장 높은 단계에서 `maximumAlpha`가 됩니다.
    public var largestUndimmedDetent: BottomSheetDetent.Identifier?

    /// 판을 탭하면 시트를 내릴지 정합니다.
    ///
    /// `largestUndimmedDetent`가 있으면 그 단계로, 없으면 허용된 가장 낮은 단계로 내립니다.
    public var collapsesOnTap: Bool

    /// 판의 설정을 주입받습니다. 인자를 생략하면 기본값을 씁니다.
    public init(
        color: UIColor = .black,
        maximumAlpha: CGFloat = 0.4,
        largestUndimmedDetent: BottomSheetDetent.Identifier? = nil,
        collapsesOnTap: Bool = true
    ) {
        self.color = color
        self.maximumAlpha = maximumAlpha
        self.largestUndimmedDetent = largestUndimmedDetent
        self.collapsesOnTap = collapsesOnTap
    }
}
#endif
