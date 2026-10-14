//
//  BottomSheetContentBottom.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/13/26.
//

import Foundation

// MARK: - Fixed-Height Content

/// 높이를 고정하고 위치만 옮기는 시트(UIKit `BottomSheetController`의 `static`)가 콘텐츠 바닥을 어디에 맞출지 정하는 계산입니다.
///
/// UI 계층은 돌려받은 위치에서 시트 바닥이 부모 View 바닥 아래로 나간 길이를 콘텐츠의 아래쪽 안전 영역에 더합니다.
/// Foundation만 써서 macOS `swift test`와 CI에서 검증됩니다.
extension BottomSheetLayout {

    /// 높이를 고정한 콘텐츠가 아래쪽 안전 영역을 맞출 시트 위치를 계산합니다.
    ///
    /// 시트가 멈춘 위치에서 콘텐츠가 스스로 스크롤하면(`locksTrackedScrollWhileIdle`가 `false`) 그 위치를 돌려줘 목록 끝과
    /// 아래에 붙인 View가 보이는 바닥에 오게 합니다. 스크롤이 시트를 먼저 올리는 위치(기본 동작에서 허용된 가장 높은 단계 아래)는
    /// 레이아웃 전체의 가장 높은 단계 위치를 돌려줘 높이를 고정한 본래 배치를 유지합니다.
    ///
    /// 콘텐츠가 보이지 않는 위치(완전히 내린 단계, 보이는 높이가 손잡이 이하인 단계)는 콘텐츠가 보이는 단계 중 가장 낮은 단계로
    /// 대신합니다. 내렸다 다시 올릴 때 콘텐츠를 다시 배치하지 않고, 안전 영역 높이가 0 아래로 내려가지 않습니다.
    ///
    /// - Parameters:
    ///   - offset: 시트가 멈춘 위치입니다. 애니메이션으로 옮기는 중이면 도착 위치입니다.
    ///   - availableHeight: 시트가 쓸 수 있는 안전 영역의 높이입니다.
    ///   - handleHeight: 손잡이 영역의 높이입니다. 콘텐츠가 보이는 단계를 가리는 데 씁니다.
    ///   - allowed: 멈출 수 있는 단계이며 `nil`이면 전부입니다.
    ///   - behavior: 스크롤이 시트를 먼저 올리는지 판단할 움직임 값입니다.
    /// - Returns: 레이아웃 전체의 가장 높은 단계 위치 이상, 콘텐츠가 보이는 가장 낮은 단계 위치 이하의 값입니다.
    /// - Complexity: O(n)입니다. n은 단계 개수입니다.
    package func contentBottomReferenceOffset(
        restingAt offset: CGFloat,
        availableHeight: CGFloat,
        handleHeight: CGFloat,
        among allowed: Set<BottomSheetDetent.Identifier>? = nil,
        behavior: BottomSheetBehavior
    ) -> CGFloat {
        let highest = self.offset(
            for: self.highestDetent(availableHeight: availableHeight),
            availableHeight: availableHeight
        )
        let allowedHighest = self.offset(
            for: self.highestDetent(availableHeight: availableHeight, among: allowed),
            availableHeight: availableHeight
        )

        /// 스크롤이 시트를 먼저 올리는 위치에서는 콘텐츠가 스크롤하지 않아 끝에 닿을 필요가 없습니다.
        guard behavior.locksTrackedScrollWhileIdle(offset: offset, highestOffset: allowedHighest) == false else {
            return highest
        }

        let lowestVisible = self.detents(among: allowed)
            .filter { $0.anchor != .hidden }
            .map { self.offset(for: $0, availableHeight: availableHeight) }
            .filter { $0 < availableHeight - handleHeight }
            .max() ?? highest

        return min(max(offset, highest), max(lowestVisible, highest))
    }
}
