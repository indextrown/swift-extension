//
//  BottomSheetLayout.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import Foundation

/// 바텀시트가 멈출 단계의 목록과, 단계 사이에서 위치를 고르는 규칙입니다.
///
/// 여기서 다루는 값은 모두 `offset`이며, 부모 화면의 안전 영역 위쪽 끝에서
/// 시트 위쪽 끝까지의 거리입니다. 값이 클수록 시트가 아래에 있습니다.
/// 시트 높이를 직접 다루지 않고 이 거리 하나만 다뤄야 위치의 근거가 한 곳에 남습니다.
///
/// 이 타입은 UIKit에 의존하지 않습니다. 화면 없이도 단계 계산을 검증할 수 있습니다.
public struct BottomSheetLayout: Hashable, Sendable {

    /// 시트가 멈출 수 있는 단계입니다. 이름이 겹치지 않아야 하고 비어 있으면 안 됩니다.
    public private(set) var detents: [BottomSheetDetent]

    /// 단계 목록으로 레이아웃을 만듭니다.
    ///
    /// - Parameter detents: 멈출 수 있는 단계입니다. 순서는 상관없습니다.
    /// - Precondition: 비어 있지 않고 이름이 겹치지 않아야 합니다.
    public init(detents: [BottomSheetDetent]) {
        precondition(!detents.isEmpty, "BottomSheetLayout에는 단계가 하나 이상 있어야 합니다.")

        let identifiers = detents.map(\.identifier)
        precondition(
            Set(identifiers).count == identifiers.count,
            "BottomSheetLayout의 단계 이름은 겹칠 수 없습니다."
        )

        self.detents = detents
    }

    /// 낮은 단계, 절반, 전체 세 단계를 갖는 기본 레이아웃입니다.
    public static let standard = BottomSheetLayout(
        detents: [.tip(), .half(), .full()]
    )

    /// 완전히 내리는 단계까지 포함한 레이아웃입니다.
    ///
    /// 시트로 돌아올 조작을 화면이 따로 마련한 경우에만 씁니다.
    public static let dismissible = BottomSheetLayout(
        detents: [.hidden, .tip(), .half(), .full()]
    )
}



// MARK: - Lookup

extension BottomSheetLayout {

    /// 이름으로 단계를 찾습니다.
    ///
    /// - Parameter identifier: 찾을 단계의 이름입니다.
    /// - Returns: 등록된 단계이며 없으면 `nil`입니다.
    /// - Complexity: O(n)입니다. n은 단계 개수입니다.
    public func detent(for identifier: BottomSheetDetent.Identifier) -> BottomSheetDetent? {
        return self.detents.first { $0.identifier == identifier }
    }

    /// 허용 목록에 든 단계만 돌려줍니다.
    ///
    /// 허용 목록이 `nil`이면 모든 단계를, 허용 목록과 겹치는 단계가 하나도 없으면
    /// 시트가 갈 곳을 잃지 않도록 모든 단계를 돌려줍니다.
    ///
    /// - Parameter allowed: 허용할 단계의 이름입니다.
    /// - Complexity: O(n)입니다.
    public func detents(among allowed: Set<BottomSheetDetent.Identifier>?) -> [BottomSheetDetent] {
        guard let allowed else { return self.detents }

        let filtered = self.detents.filter { allowed.contains($0.identifier) }

        return filtered.isEmpty ? self.detents : filtered
    }
}



// MARK: - Offset

extension BottomSheetLayout {

    /// 단계에 해당하는 offset을 계산합니다.
    ///
    /// - Parameters:
    ///   - detent: 위치를 구할 단계입니다.
    ///   - availableHeight: 시트가 쓸 수 있는 안전 영역의 높이입니다.
    /// - Returns: 안전 영역 위쪽 끝에서 시트 위쪽 끝까지의 거리입니다.
    /// - Complexity: O(1)입니다.
    public func offset(for detent: BottomSheetDetent, availableHeight: CGFloat) -> CGFloat {
        return detent.anchor.offset(in: availableHeight)
    }

    /// 가장 높은 단계, 즉 offset이 가장 작은 단계입니다.
    ///
    /// - Parameters:
    ///   - availableHeight: 시트가 쓸 수 있는 안전 영역의 높이입니다.
    ///   - allowed: 고를 수 있는 단계이며 `nil`이면 전부입니다.
    /// - Complexity: O(n)입니다.
    public func highestDetent(
        availableHeight: CGFloat,
        among allowed: Set<BottomSheetDetent.Identifier>? = nil
    ) -> BottomSheetDetent {
        let candidates = self.detents(among: allowed)

        return candidates.min {
            self.offset(for: $0, availableHeight: availableHeight)
                < self.offset(for: $1, availableHeight: availableHeight)
        } ?? candidates[0]
    }

    /// 가장 낮은 단계, 즉 offset이 가장 큰 단계입니다.
    ///
    /// - Parameters:
    ///   - availableHeight: 시트가 쓸 수 있는 안전 영역의 높이입니다.
    ///   - allowed: 고를 수 있는 단계이며 `nil`이면 전부입니다.
    /// - Complexity: O(n)입니다.
    public func lowestDetent(
        availableHeight: CGFloat,
        among allowed: Set<BottomSheetDetent.Identifier>? = nil
    ) -> BottomSheetDetent {
        let candidates = self.detents(among: allowed)

        return candidates.max {
            self.offset(for: $0, availableHeight: availableHeight)
                < self.offset(for: $1, availableHeight: availableHeight)
        } ?? candidates[0]
    }

    /// 주어진 위치에서 가장 가까운 단계를 찾습니다.
    ///
    /// - Parameters:
    ///   - offset: 비교할 위치입니다.
    ///   - availableHeight: 시트가 쓸 수 있는 안전 영역의 높이입니다.
    ///   - allowed: 고를 수 있는 단계이며 내용이 많을 때 낮은 단계를 빼는 데 씁니다.
    /// - Returns: 거리가 가장 가까운 단계입니다. 거리가 같으면 목록에서 앞선 단계입니다.
    /// - Complexity: O(n)입니다.
    public func nearestDetent(
        to offset: CGFloat,
        availableHeight: CGFloat,
        among allowed: Set<BottomSheetDetent.Identifier>? = nil
    ) -> BottomSheetDetent {
        let candidates = self.detents(among: allowed)

        return candidates.min {
            abs(self.offset(for: $0, availableHeight: availableHeight) - offset)
                < abs(self.offset(for: $1, availableHeight: availableHeight) - offset)
        } ?? candidates[0]
    }

    /// 단계보다 위쪽에 있는 단계 중 가장 가까운 단계입니다.
    ///
    /// - Returns: 더 높은 단계가 없으면 `nil`입니다.
    /// - Complexity: O(n)입니다.
    public func detent(
        above detent: BottomSheetDetent,
        availableHeight: CGFloat,
        among allowed: Set<BottomSheetDetent.Identifier>? = nil
    ) -> BottomSheetDetent? {
        let current = self.offset(for: detent, availableHeight: availableHeight)

        return self.detents(among: allowed)
            .filter { self.offset(for: $0, availableHeight: availableHeight) < current }
            .max {
                self.offset(for: $0, availableHeight: availableHeight)
                    < self.offset(for: $1, availableHeight: availableHeight)
            }
    }

    /// 단계보다 아래쪽에 있는 단계 중 가장 가까운 단계입니다.
    ///
    /// - Returns: 더 낮은 단계가 없으면 `nil`입니다.
    /// - Complexity: O(n)입니다.
    public func detent(
        below detent: BottomSheetDetent,
        availableHeight: CGFloat,
        among allowed: Set<BottomSheetDetent.Identifier>? = nil
    ) -> BottomSheetDetent? {
        let current = self.offset(for: detent, availableHeight: availableHeight)

        return self.detents(among: allowed)
            .filter { self.offset(for: $0, availableHeight: availableHeight) > current }
            .min {
                self.offset(for: $0, availableHeight: availableHeight)
                    < self.offset(for: $1, availableHeight: availableHeight)
            }
    }
}



// MARK: - Drag

extension BottomSheetLayout {

    /// 끌고 있는 위치를 허용 범위 안으로 되돌립니다.
    ///
    /// 범위를 벗어나면 막지 않고 저항을 주어 조금만 따라오게 합니다.
    /// 딱 멈추면 제스처가 끊긴 것처럼 느껴집니다.
    ///
    /// - Parameters:
    ///   - offset: 손가락을 따라 계산한 위치입니다.
    ///   - availableHeight: 시트가 쓸 수 있는 안전 영역의 높이입니다.
    ///   - allowed: 고를 수 있는 단계이며 `nil`이면 전부입니다.
    ///   - behavior: 저항의 세기를 정하는 값입니다.
    /// - Returns: 저항을 반영한 위치입니다.
    /// - Complexity: O(n)입니다.
    public func resistedOffset(
        _ offset: CGFloat,
        availableHeight: CGFloat,
        among allowed: Set<BottomSheetDetent.Identifier>? = nil,
        behavior: BottomSheetBehavior
    ) -> CGFloat {
        let highest = self.offset(
            for: self.highestDetent(availableHeight: availableHeight, among: allowed),
            availableHeight: availableHeight
        )
        let lowest = self.offset(
            for: self.lowestDetent(availableHeight: availableHeight, among: allowed),
            availableHeight: availableHeight
        )

        if offset < highest {
            return highest - behavior.resistedDistance(highest - offset)
        }

        if offset > lowest {
            return lowest + behavior.resistedDistance(offset - lowest)
        }

        return offset
    }

    /// 손을 뗀 위치와 속도로 도착할 단계를 고릅니다.
    ///
    /// 속도로 관성이 멈출 지점을 먼저 예측한 뒤 그곳에서 가장 가까운 단계를 고릅니다.
    ///
    /// - Parameters:
    ///   - offset: 손을 뗀 순간의 위치입니다.
    ///   - velocity: 손을 뗀 순간의 초당 이동 거리입니다. 아래로 끌면 양수입니다.
    ///   - availableHeight: 시트가 쓸 수 있는 안전 영역의 높이입니다.
    ///   - allowed: 고를 수 있는 단계이며 `nil`이면 전부입니다.
    ///   - behavior: 관성의 세기를 정하는 값입니다.
    /// - Complexity: O(n)입니다.
    public func targetDetent(
        releasedAt offset: CGFloat,
        velocity: CGFloat,
        availableHeight: CGFloat,
        among allowed: Set<BottomSheetDetent.Identifier>? = nil,
        behavior: BottomSheetBehavior
    ) -> BottomSheetDetent {
        let projected = offset + behavior.projectedDistance(for: velocity)

        return self.nearestDetent(
            to: projected,
            availableHeight: availableHeight,
            among: allowed
        )
    }
}
