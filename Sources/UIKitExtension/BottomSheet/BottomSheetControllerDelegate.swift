//
//  BottomSheetControllerDelegate.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import UIKit

/// 바텀시트의 움직임을 소유자에게 알립니다.
///
/// 모든 메서드에 빈 기본 구현이 있어 필요한 것만 구현합니다.
@MainActor
public protocol BottomSheetControllerDelegate: AnyObject {

    /// 사용자가 시트를 끌기 시작하면 호출합니다.
    func bottomSheetWillBeginDragging(_ controller: BottomSheetController)

    /// 사용자가 끄는 동안 위치가 바뀔 때마다 호출합니다.
    ///
    /// 지도 카메라 여백처럼 시트 높이를 따라가야 하는 값을 갱신하는 데 씁니다.
    /// 프로그램으로 옮기거나 손을 뗀 뒤 애니메이션이 도는 동안에는 호출하지 않습니다.
    ///
    /// - Parameter offset: 부모 안전 영역 위쪽 끝에서 시트 위쪽 끝까지의 거리입니다.
    func bottomSheet(_ controller: BottomSheetController, didMoveTo offset: CGFloat)

    /// 사용자가 손을 뗀 직후, 도착할 단계를 정한 뒤 호출합니다.
    ///
    /// `targetDetent`를 바꾸면 그 단계로 대신 이동합니다. 레이아웃에 없는 이름을 넣으면
    /// 무시하고 원래 단계로 갑니다.
    ///
    /// - Parameters:
    ///   - velocity: 손을 뗀 순간의 초당 이동 거리입니다. 아래로 끌었으면 양수입니다.
    ///   - targetDetent: 계산된 도착 단계이며 바꿔 넣을 수 있습니다.
    func bottomSheet(
        _ controller: BottomSheetController,
        willEndDraggingWithVelocity velocity: CGFloat,
        targetDetent: inout BottomSheetDetent.Identifier
    )

    /// 시트가 머무는 단계가 바뀌면 호출합니다.
    ///
    /// 도착 단계가 정해진 시점, 즉 이동 애니메이션이 시작되기 직전에 호출합니다. 같은 길이로
    /// 다른 값을 함께 움직이면 두 애니메이션이 나란히 갑니다. 길이는
    /// `BottomSheetBehavior.animationDuration`, 도착 위치는 `controller.offset(for: detent)`입니다.
    func bottomSheet(_ controller: BottomSheetController, didChangeDetent detent: BottomSheetDetent)
}



// MARK: - Default Implementation

public extension BottomSheetControllerDelegate {

    func bottomSheetWillBeginDragging(_ controller: BottomSheetController) {}

    func bottomSheet(_ controller: BottomSheetController, didMoveTo offset: CGFloat) {}

    func bottomSheet(
        _ controller: BottomSheetController,
        willEndDraggingWithVelocity velocity: CGFloat,
        targetDetent: inout BottomSheetDetent.Identifier
    ) {}

    func bottomSheet(_ controller: BottomSheetController, didChangeDetent detent: BottomSheetDetent) {}
}
#endif
