//
//  BottomSheetBehavior.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import Foundation

/// 시트가 손을 따라오고, 손을 뗀 뒤 움직이는 방식입니다.
///
/// 위치를 정하는 규칙은 `BottomSheetLayout`이 맡고, 이 값은 그 위치 사이를 어떻게
/// 오가는지만 정합니다. 화면마다 다른 손맛이 필요하면 값을 바꿔 주입합니다.
public struct BottomSheetBehavior: Hashable, Sendable {

    /// 시트가 관성으로 미끄러지는 정도입니다.
    ///
    /// `UIScrollView`의 기본값 0.998은 화면 몇 개분을 미끄러지도록 맞춘 값이라
    /// 단계 사이가 300pt 남짓인 시트에서는 한 번의 플릭이 두 단계를 건너뜁니다.
    /// 값을 낮춰 손을 뗀 위치가 주도권을 갖게 하고 속도는 보조로만 씁니다.
    public var decelerationRate: CGFloat

    /// 단계 사이를 옮길 때 스프링이 튕기는 정도입니다. 1에 가까울수록 덜 튕깁니다.
    public var springDampingRatio: CGFloat

    /// 단계 사이를 옮기는 애니메이션의 길이입니다.
    public var animationDuration: TimeInterval

    /// 단계의 한계를 넘어 끌 때 시트가 따라올 최대 거리입니다.
    ///
    /// 이 거리에 가까워질수록 덜 따라와 더는 갈 곳이 없다는 것을 손끝으로 알립니다.
    /// 0이면 한계에서 딱 멈춥니다.
    public var overDragLimit: CGFloat

    /// 처음 화면에 붙을 때 아래에서 올라오는 애니메이션을 쓸지 정합니다.
    public var animatesInitialAppearance: Bool

    /// 움직임 값을 주입받습니다. 인자를 생략하면 기본값을 씁니다.
    public init(
        decelerationRate: CGFloat = 0.99,
        springDampingRatio: CGFloat = 0.85,
        animationDuration: TimeInterval = 0.4,
        overDragLimit: CGFloat = 64,
        animatesInitialAppearance: Bool = true
    ) {
        self.decelerationRate = decelerationRate
        self.springDampingRatio = springDampingRatio
        self.animationDuration = animationDuration
        self.overDragLimit = overDragLimit
        self.animatesInitialAppearance = animatesInitialAppearance
    }

    /// 지도 위 시트에 맞춘 기본 움직임입니다.
    public static let `default` = BottomSheetBehavior()
}



// MARK: - Physics

extension BottomSheetBehavior {

    /// 손을 뗀 속도로 관성이 멈출 지점을 예측합니다.
    ///
    /// 이동한 거리만 보면 짧고 빠르게 튕긴 동작이 무시됩니다.
    /// 감속 모델로 도착점을 먼저 구한 뒤 가까운 단계를 고르는 데 씁니다.
    ///
    /// - Parameter velocity: 손을 뗀 순간의 초당 이동 거리입니다.
    /// - Returns: 현재 위치에서 더 나아갈 거리입니다. 속도와 같은 부호입니다.
    /// - Complexity: O(1)입니다.
    public func projectedDistance(for velocity: CGFloat) -> CGFloat {
        guard self.decelerationRate > 0, self.decelerationRate < 1 else { return 0 }

        return (velocity / 1000) * self.decelerationRate / (1 - self.decelerationRate)
    }

    /// 한계를 넘어선 거리를 점점 줄여 돌려줍니다.
    ///
    /// 끌수록 덜 따라오고 `overDragLimit`을 넘지 않습니다.
    ///
    /// - Parameter distance: 한계를 넘어선 거리입니다. 0 이상을 기대합니다.
    /// - Returns: 저항을 반영해 줄인 거리입니다.
    /// - Complexity: O(1)입니다.
    public func resistedDistance(_ distance: CGFloat) -> CGFloat {
        guard self.overDragLimit > 0, distance > 0 else { return 0 }

        return self.overDragLimit * tanh(distance / self.overDragLimit)
    }
}
