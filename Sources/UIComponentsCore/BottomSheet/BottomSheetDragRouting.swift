//
//  BottomSheetDragRouting.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/13/26.
//

import Foundation

/// 끌기가 처음 닿은 자리입니다. UIKit은 손가락이 처음 닿은 View로, SwiftUI는 끌기를 알린 제스처로 고릅니다.
package enum BottomSheetDragOrigin: Hashable, Sendable {

    /// 손잡이 영역과, 끌기 손잡이로 지정한 View입니다.
    case handle

    /// 콘텐츠가 터치를 받지 않는 시트 배경입니다.
    case background

    /// 시트가 따라가는 스크롤뷰입니다. UIKit은 `track(scrollView:)`로 넘긴 스크롤뷰, SwiftUI는 `BottomSheetScrollView`입니다.
    case trackedScrollView

    /// 그 밖에 터치를 받는 콘텐츠입니다. 컨트롤, 따라가지 않는 스크롤뷰, SwiftUI의 그려진 View가 여기에 듭니다.
    case content

    /// 끌기가 시작되기 전에 손가락이 하나 더 닿았을 때 두 출발지를 합칩니다.
    ///
    /// 같으면 그대로 둡니다. 다르면 어느 손가락이 끌지 알 수 없어, 두 출발지 가운데 따라가는 스크롤과 덜 엮이는 쪽을
    /// 남깁니다. 순서는 `handle`, `background`, `content`, `trackedScrollView`이고 손가락이 닿은 순서와 상관없습니다.
    /// 결과는 늘 두 출발지 가운데 하나라서, 시트가 둘 다 받았다면 합친 출발지도 받고, 둘이 다르면 따라가는 스크롤과
    /// 엮이지 않아 손잡이를 끄는 중에 목록이 맨 위로 붙잡혀 튀지 않습니다.
    ///
    /// - Parameter other: 새로 닿은 손가락의 출발지입니다.
    /// - Returns: 합친 출발지입니다.
    /// - Complexity: O(1)입니다.
    package func merging(_ other: BottomSheetDragOrigin) -> BottomSheetDragOrigin {
        return self.mergePriority >= other.mergePriority ? self : other
    }

    /// 합칠 때 남길 순서입니다. 클수록 먼저 남깁니다.
    private var mergePriority: Int {
        switch self {
        case .handle:
            return 3

        case .background:
            return 2

        case .content:
            return 1

        case .trackedScrollView:
            return 0
        }
    }
}

/// 끌기가 시작될 때 무엇을 움직일지입니다.
package enum BottomSheetDragTarget: Hashable, Sendable {

    /// 시트가 움직입니다.
    case sheet

    /// 따라가는 스크롤이 움직입니다.
    case scroll

    /// 시트가 끼어들지 않습니다. 콘텐츠의 스크롤과 제스처가 받습니다.
    case ignored
}



// MARK: - Routing

/// UIKit `BottomSheetController`와 SwiftUI `bottomSheet(detent:)`가 함께 쓰는 끌기 규칙입니다.
///
/// 두 판이 같은 규칙을 따로 들고 있으면 한쪽만 고쳐질 수 있어 한곳에 모았습니다. Foundation만 써서
/// macOS `swift test`와 CI에서 검증됩니다.
extension BottomSheetBehavior {

    /// 이 자리에서 시작한 끌기를 시트가 받을지 정합니다. 방향과 상관없어 손가락이 닿는 순간 부를 수 있습니다.
    ///
    /// - Parameter origin: 손가락이 처음 닿은 자리입니다.
    /// - Returns: 시트가 받으면 `true`입니다.
    /// - Complexity: O(1)입니다.
    package func acceptsDrag(from origin: BottomSheetDragOrigin) -> Bool {
        switch (self.dragArea.kind, origin) {
        case (.entireSheet, _):
            return true

        case (.handleAndBackground, .handle), (.handleAndBackground, .background):
            return true

        case (.handleAndBackground, .trackedScrollView), (.handleAndBackground, .content):
            return false
        }
    }

    /// 끌기가 시작될 때 시트와 스크롤 중 무엇을 움직일지 정합니다.
    ///
    /// - Parameters:
    ///   - origin: 손가락이 처음 닿은 자리입니다.
    ///   - offset: 지금 시트 위치입니다.
    ///   - highestOffset: 허용된 가장 높은 단계의 위치입니다.
    ///   - isScrollAtTop: 따라가는 스크롤이 맨 위에 닿아 있는지입니다. 스크롤뷰가 없으면 `true`를 넘깁니다.
    ///   - isDraggingDown: 아래로 끄는 중인지입니다.
    /// - Returns: 움직일 대상입니다. 시트가 받지 않는 끌기면 `.ignored`입니다.
    /// - Complexity: O(1)입니다.
    package func initialDragTarget(
        from origin: BottomSheetDragOrigin,
        offset: CGFloat,
        highestOffset: CGFloat,
        isScrollAtTop: Bool,
        isDraggingDown: Bool
    ) -> BottomSheetDragTarget {
        guard self.acceptsDrag(from: origin) else { return .ignored }

        switch origin {
        case .handle, .background, .content:
            return .sheet

        case .trackedScrollView:
            /// 스크롤이 시트를 올리는 모드에서는 가장 높은 단계 아래에 있으면 언제나 시트가 움직입니다.
            if self.scrollingExpandsSheet, Self.isBelowHighest(offset, highestOffset) {
                return .sheet
            }

            /// 맨 위에서 아래로 끌면 시트가, 그 밖에는 스크롤이 움직입니다.
            return isScrollAtTop && isDraggingDown ? .sheet : .scroll
        }
    }

    /// 이 끌기가 시트와 따라가는 스크롤 사이를 오갈 수 있는지 정합니다.
    ///
    /// UIKit의 동시 인식, 두 판의 "맨 위에서 아래로 끌면 시트로" 넘김, UIKit의 "가장 높은 단계 너머로 밀면
    /// 스크롤로" 넘김에 씁니다. 따라가는 스크롤뷰에서 시작한 끌기만 오가므로, 손잡이를 끄는 중에 다른 손가락이
    /// 스크롤뷰를 끌어도 섞이지 않습니다.
    ///
    /// - Parameter origin: 손가락이 처음 닿은 자리입니다.
    /// - Returns: 시트와 스크롤 사이를 오갈 수 있으면 `true`입니다.
    /// - Complexity: O(1)입니다.
    package func sharesDragWithTrackedScroll(from origin: BottomSheetDragOrigin) -> Bool {
        switch self.dragArea.kind {
        case .entireSheet:
            return origin == .trackedScrollView

        case .handleAndBackground:
            return false
        }
    }

    /// 끄는 동안 따라가는 스크롤을 붙잡아(SwiftUI는 잠가) 둘지 정합니다.
    ///
    /// 손가락이 스크롤뷰 위에서 시트를 움직일 때만 붙잡습니다. 손잡이·빈 배경이나 스크롤 밖 콘텐츠로 끄는 동안
    /// 붙잡으면 감속 중인 목록이 맨 위로 튑니다.
    ///
    /// - Parameters:
    ///   - target: 이 끌기가 지금 움직이는 대상입니다.
    ///   - origin: 손가락이 처음 닿은 자리입니다.
    /// - Returns: 스크롤을 붙잡아야 하면 `true`입니다.
    /// - Complexity: O(1)입니다.
    package func locksTrackedScroll(
        whileDragging target: BottomSheetDragTarget,
        from origin: BottomSheetDragOrigin
    ) -> Bool {
        return target == .sheet && self.sharesDragWithTrackedScroll(from: origin)
    }

    /// 끌지 않는 동안 따라가는 스크롤을 맨 위에 붙잡아(SwiftUI는 잠가) 둘지 정합니다.
    ///
    /// 스크롤이 시트를 올리는 모드에서 시트가 가장 높은 단계 아래에 있을 때만 붙잡습니다. `.handleAndBackground`에서는
    /// 콘텐츠로 시트를 올릴 수 없으므로 붙잡지 않습니다. 붙잡으면 시트도 목록도 움직이지 않습니다. UIKit `static`은 이 값으로
    /// 낮은 단계에서 콘텐츠 바닥을 맞출지도 정합니다(`contentBottomReferenceOffset`).
    ///
    /// - Parameters:
    ///   - offset: 지금 시트 위치입니다.
    ///   - highestOffset: 허용된 가장 높은 단계의 위치입니다.
    /// - Returns: 스크롤을 붙잡아야 하면 `true`입니다.
    /// - Complexity: O(1)입니다.
    package func locksTrackedScrollWhileIdle(offset: CGFloat, highestOffset: CGFloat) -> Bool {
        switch self.dragArea.kind {
        case .entireSheet:
            return self.scrollingExpandsSheet && Self.isBelowHighest(offset, highestOffset)

        case .handleAndBackground:
            return false
        }
    }

    /// 두 UI 판이 따로 쓰던 `+ 0.5` 오차를 한곳에 둡니다.
    private static func isBelowHighest(_ offset: CGFloat, _ highestOffset: CGFloat) -> Bool {
        return offset > highestOffset + 0.5
    }
}
