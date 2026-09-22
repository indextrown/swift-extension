//
//  BottomSheetStyle.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

#if !os(tvOS)
import SwiftUI
import UIComponentsCore

/// SwiftUI 바텀시트의 표시 속성입니다.
///
/// UIKit 쪽 `BottomSheetAppearance`와 같은 역할이지만 SwiftUI 타입(`Color`, `ShapeStyle`)을 씁니다.
/// 인자를 생략하면 시스템 배경 위에 얇은 손잡이와 옅은 그림자가 있는 기본 모양이 됩니다.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct BottomSheetStyle {

    /// 시트 배경입니다. 기본은 시스템 배경(`.background`)입니다.
    public var background: AnyShapeStyle

    /// 위쪽 두 모서리의 둥근 정도입니다.
    public var cornerRadius: CGFloat

    /// 손잡이를 그릴지 정합니다. `false`면 손잡이 영역도 함께 사라집니다.
    public var showsGrabber: Bool

    /// 손잡이의 크기입니다.
    public var grabberSize: CGSize

    /// 손잡이의 색입니다.
    public var grabberColor: Color

    /// 손잡이가 놓이는 영역의 높이입니다. 콘텐츠는 이 영역 아래에서 시작합니다.
    public var handleAreaHeight: CGFloat

    /// 시트 위쪽에 드리우는 그림자의 색입니다. 투명도를 색에 포함합니다.
    public var shadowColor: Color

    /// 그림자가 퍼지는 정도입니다.
    public var shadowRadius: CGFloat

    /// 그림자가 세로로 어긋나는 거리입니다. 음수면 위로 올라갑니다.
    public var shadowY: CGFloat

    /// 시트 뒤를 어둡게 덮는 판입니다. `nil`이면 덮지 않습니다.
    public var backdrop: BottomSheetBackdropStyle?

    /// VoiceOver가 손잡이를 읽을 때 쓰는 이름입니다.
    public var handleAccessibilityLabel: String

    /// 표시 속성을 주입받습니다. 인자를 생략하면 기본값을 씁니다.
    public init(
        background: AnyShapeStyle = AnyShapeStyle(.background),
        cornerRadius: CGFloat = 16,
        showsGrabber: Bool = true,
        grabberSize: CGSize = CGSize(width: 36, height: 5),
        grabberColor: Color = .secondary.opacity(0.5),
        handleAreaHeight: CGFloat = 28,
        shadowColor: Color = .black.opacity(0.12),
        shadowRadius: CGFloat = 8,
        shadowY: CGFloat = -2,
        backdrop: BottomSheetBackdropStyle? = nil,
        handleAccessibilityLabel: String = "Sheet"
    ) {
        self.background = background
        self.cornerRadius = cornerRadius
        self.showsGrabber = showsGrabber
        self.grabberSize = grabberSize
        self.grabberColor = grabberColor
        self.handleAreaHeight = handleAreaHeight
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowY = shadowY
        self.backdrop = backdrop
        self.handleAccessibilityLabel = handleAccessibilityLabel
    }

    /// 시스템 배경과 옅은 그림자를 쓰는 기본 모양입니다.
    public static var `default`: BottomSheetStyle {
        return BottomSheetStyle()
    }
}



// MARK: - Backdrop

/// 시트 뒤를 어둡게 덮는 판의 설정입니다.
///
/// 시트가 올라갈수록 진해지고, 정한 단계 아래로 내려가면 사라집니다.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct BottomSheetBackdropStyle {

    /// 판의 색입니다.
    public var color: Color

    /// 시트가 가장 높은 단계에 있을 때의 투명도입니다.
    public var maximumOpacity: CGFloat

    /// 이 단계와 그보다 낮은 단계에서는 판을 그리지 않습니다.
    ///
    /// `nil`이면 가장 낮은 단계에서 0으로 시작해 가장 높은 단계에서 `maximumOpacity`가 됩니다.
    public var largestUndimmedDetent: BottomSheetDetent.Identifier?

    /// 판을 탭하면 시트를 내릴지 정합니다.
    ///
    /// `largestUndimmedDetent`가 있으면 그 단계로, 없으면 허용된 가장 낮은 단계로 내립니다.
    public var collapsesOnTap: Bool

    /// 판의 설정을 주입받습니다. 인자를 생략하면 기본값을 씁니다.
    public init(
        color: Color = .black,
        maximumOpacity: CGFloat = 0.4,
        largestUndimmedDetent: BottomSheetDetent.Identifier? = nil,
        collapsesOnTap: Bool = true
    ) {
        self.color = color
        self.maximumOpacity = maximumOpacity
        self.largestUndimmedDetent = largestUndimmedDetent
        self.collapsesOnTap = collapsesOnTap
    }
}
#endif
