//
//  BottomSheetControllerDelegate.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import UIComponentsCore
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

    /// 시트가 가린 높이가 바뀔 때 호출합니다.
    ///
    /// 가린 높이는 부모 안전 영역 아래쪽 끝에서 시트 윗선까지의 거리, 즉 `availableHeight - offset`입니다.
    /// 끄는 동안은 매 프레임 `animated == false`로, 손을 뗀 뒤나 `move(to:animated: true)`로 옮길 때는
    /// 도착값을 `animated == true`로 한 번 알립니다. 처음 화면에 자리 잡을 때도 한 번 옵니다.
    ///
    /// 지도 여백처럼 시트 높이를 따라가야 하는 값 하나를 갱신할 때, `didMoveTo`와 `didChangeDetent`를
    /// 둘 다 구현하고 도착 위치를 계산하는 대신 이것 하나로 처리할 수 있습니다.
    ///
    /// - Parameters:
    ///   - height: 시트가 가린 높이입니다. 0 이상입니다.
    ///   - animated: `true`면 시트가 이 값까지 `behavior.animationDuration` 동안 움직이는 중이니 같은 길이로 함께 움직이면 나란히 갑니다.
    func bottomSheet(_ controller: BottomSheetController, didChangeCoveredHeight height: CGFloat, animated: Bool)

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

    func bottomSheet(_ controller: BottomSheetController, didChangeCoveredHeight height: CGFloat, animated: Bool) {}
}
#endif
