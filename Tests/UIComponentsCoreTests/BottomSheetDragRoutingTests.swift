import Foundation
import Testing
import UIComponentsCore

private let highest: CGFloat = 100
private let belowHighest: CGFloat = 300

private let origins: [BottomSheetDragOrigin] = [.handle, .background, .trackedScrollView, .content]
private let dragAreas: [BottomSheetDragArea] = [.entireSheet, .handleAndBackground]

/// 값이나 출발지가 늘면 `switch`가 컴파일 오류로 알려 줘요.
private func expectedAcceptance(_ area: BottomSheetDragArea, _ origin: BottomSheetDragOrigin) -> Bool {
    switch (area.kind, origin) {
    case (.entireSheet, .handle), (.entireSheet, .background), (.entireSheet, .trackedScrollView), (.entireSheet, .content):
        return true

    case (.handleAndBackground, .handle), (.handleAndBackground, .background):
        return true

    case (.handleAndBackground, .trackedScrollView), (.handleAndBackground, .content):
        return false
    }
}

// MARK: - Default and Equality

@Test("기본값은 시트 어디서나 끌어요")
func dragAreaDefaultsToEntireSheet() {
    #expect(BottomSheetBehavior.default.dragArea == .entireSheet)
    #expect(BottomSheetBehavior().dragArea == .entireSheet)
    #expect(BottomSheetBehavior(animatesInitialAppearance: false, scrollingExpandsSheet: false).dragArea == .entireSheet)
}

@Test("끌기 영역이 다르면 다른 움직임 값이에요")
func dragAreaTakesPartInEquality() {
    #expect(BottomSheetBehavior(dragArea: .handleAndBackground) != .default)
    #expect(BottomSheetDragArea.handleAndBackground != .entireSheet)
    #expect(Set<BottomSheetDragArea>([.handleAndBackground, .entireSheet, .handleAndBackground]).count == 2)
}

// MARK: - Acceptance

@Test("시트가 받는 출발지는 표와 같아요", arguments: dragAreas, origins)
func acceptanceMatrix(area: BottomSheetDragArea, origin: BottomSheetDragOrigin) {
    #expect(BottomSheetBehavior(dragArea: area).acceptsDrag(from: origin) == expectedAcceptance(area, origin))
}

// MARK: - Sheet-Only Origins

@Test("손잡이와 빈 배경에서 시작한 끌기는 어떤 설정에서든 시트만 움직여요", arguments: dragAreas, [true, false])
func sheetOnlyOriginsAlwaysMoveSheet(dragArea: BottomSheetDragArea, scrollingExpandsSheet: Bool) {
    let behavior = BottomSheetBehavior(scrollingExpandsSheet: scrollingExpandsSheet, dragArea: dragArea)

    for origin in [BottomSheetDragOrigin.handle, .background] {
        #expect(behavior.acceptsDrag(from: origin))
        #expect(behavior.sharesDragWithTrackedScroll(from: origin) == false)
        #expect(behavior.locksTrackedScroll(whileDragging: .sheet, from: origin) == false)
        #expect(behavior.locksTrackedScroll(whileDragging: .scroll, from: origin) == false)

        for offset in [highest, highest + 0.5, highest + 0.51, belowHighest] {
            for isScrollAtTop in [true, false] {
                for isDraggingDown in [true, false] {
                    let target = behavior.initialDragTarget(
                        from: origin,
                        offset: offset,
                        highestOffset: highest,
                        isScrollAtTop: isScrollAtTop,
                        isDraggingDown: isDraggingDown
                    )
                    #expect(target == .sheet)
                }
            }
        }
    }
}

// MARK: - Handle and Background

@Test("손잡이·빈 배경으로만 끌면 콘텐츠와 따라가는 스크롤의 끌기는 시트가 받지 않아요", arguments: [true, false])
func handleAndBackgroundIgnoresContentAndTrackedScroll(scrollingExpandsSheet: Bool) {
    let behavior = BottomSheetBehavior(scrollingExpandsSheet: scrollingExpandsSheet, dragArea: .handleAndBackground)

    for origin in [BottomSheetDragOrigin.content, .trackedScrollView] {
        #expect(behavior.acceptsDrag(from: origin) == false)

        for offset in [highest, belowHighest] {
            for isScrollAtTop in [true, false] {
                for isDraggingDown in [true, false] {
                    let target = behavior.initialDragTarget(
                        from: origin,
                        offset: offset,
                        highestOffset: highest,
                        isScrollAtTop: isScrollAtTop,
                        isDraggingDown: isDraggingDown
                    )
                    #expect(target == .ignored)
                }
            }
        }
    }
}

// MARK: - Entire Sheet Regression

@Test("시트 어디서나 끌 때의 규칙은 예전과 같아요")
func entireSheetKeepsExistingRouting() {
    let expands = BottomSheetBehavior(scrollingExpandsSheet: true)
    let scrolls = BottomSheetBehavior(scrollingExpandsSheet: false)

    func target(
        _ behavior: BottomSheetBehavior,
        _ origin: BottomSheetDragOrigin,
        offset: CGFloat,
        atTop: Bool,
        down: Bool
    ) -> BottomSheetDragTarget {
        return behavior.initialDragTarget(
            from: origin,
            offset: offset,
            highestOffset: highest,
            isScrollAtTop: atTop,
            isDraggingDown: down
        )
    }

    /// 스크롤 밖 콘텐츠와 빈 배경은 언제나 시트예요.
    #expect(target(expands, .content, offset: belowHighest, atTop: false, down: false) == .sheet)
    #expect(target(scrolls, .content, offset: highest, atTop: false, down: false) == .sheet)
    #expect(target(expands, .background, offset: highest, atTop: false, down: false) == .sheet)
    #expect(target(scrolls, .background, offset: belowHighest, atTop: true, down: true) == .sheet)

    /// 스크롤이 시트를 올리는 모드에서는 가장 높은 단계 아래면 스크롤뷰를 끌어도 시트예요.
    #expect(target(expands, .trackedScrollView, offset: belowHighest, atTop: false, down: false) == .sheet)

    /// 경계값: 0.5까지는 가장 높은 단계로 보고, 그보다 아래여야 시트가 먼저 움직여요.
    #expect(target(expands, .trackedScrollView, offset: highest + 0.5, atTop: true, down: false) == .scroll)
    #expect(target(expands, .trackedScrollView, offset: highest + 0.51, atTop: false, down: false) == .sheet)

    /// 가장 높은 단계에서는 맨 위에서 아래로 끌 때만 시트, 맨 위가 아니면 스크롤이에요.
    #expect(target(expands, .trackedScrollView, offset: highest, atTop: true, down: true) == .sheet)
    #expect(target(expands, .trackedScrollView, offset: highest, atTop: true, down: false) == .scroll)
    #expect(target(expands, .trackedScrollView, offset: highest, atTop: false, down: true) == .scroll)

    /// 스크롤이 시트를 올리지 않으면 위로 끌 때는 스크롤, 맨 위에서 아래로 끌면 시트예요.
    #expect(target(scrolls, .trackedScrollView, offset: belowHighest, atTop: false, down: false) == .scroll)
    #expect(target(scrolls, .trackedScrollView, offset: belowHighest, atTop: true, down: true) == .sheet)
    #expect(target(scrolls, .trackedScrollView, offset: belowHighest, atTop: false, down: true) == .scroll)
}

// MARK: - Multiple Touches

@Test("끌기 전에 손가락이 더해지면 스크롤과 덜 엮이는 출발지를 남겨요")
func mergingKeepsTheLessScrollCoupledOrigin() {
    let order: [BottomSheetDragOrigin] = [.handle, .background, .content, .trackedScrollView]

    for first in origins {
        for second in origins {
            let merged = first.merging(second)
            let expected = order.first { $0 == first || $0 == second }

            #expect(merged == expected)
            #expect(merged == second.merging(first))
            #expect(merged == first || merged == second)
        }
    }

    #expect(BottomSheetDragOrigin.handle.merging(.background) == .handle)
    #expect(BottomSheetDragOrigin.background.merging(.trackedScrollView) == .background)
    #expect(BottomSheetDragOrigin.content.merging(.trackedScrollView) == .content)
    #expect(BottomSheetDragOrigin.trackedScrollView.merging(.handle) == .handle)
}

@Test("받는 출발지끼리 합쳐도 받고, 다른 출발지를 합치면 스크롤과 엮이지 않아요", arguments: dragAreas)
func mergedOriginStaysAcceptedAndUncoupled(area: BottomSheetDragArea) {
    let behavior = BottomSheetBehavior(dragArea: area)

    for first in origins where behavior.acceptsDrag(from: first) {
        for second in origins where behavior.acceptsDrag(from: second) {
            let merged = first.merging(second)

            #expect(behavior.acceptsDrag(from: merged))

            if first != second {
                #expect(behavior.sharesDragWithTrackedScroll(from: merged) == false)
                #expect(behavior.locksTrackedScroll(whileDragging: .sheet, from: merged) == false)
            }
        }
    }
}

// MARK: - Scroll Sharing and Locking

@Test("시트와 스크롤 사이를 오가는 건 시트 어디서나 끌 때 따라가는 스크롤에서 시작한 끌기뿐이에요")
func scrollHandoffOnlyFromTrackedScrollInEntireSheet() {
    for dragArea in dragAreas {
        let behavior = BottomSheetBehavior(dragArea: dragArea)

        for origin in origins {
            let expected = dragArea == .entireSheet && origin == .trackedScrollView
            #expect(behavior.sharesDragWithTrackedScroll(from: origin) == expected)
        }
    }
}

@Test("끄는 동안 스크롤을 붙잡는 건 스크롤뷰 위에서 시트를 움직일 때뿐이에요")
func scrollLockWhileDraggingNeedsTrackedOrigin() {
    let entire = BottomSheetBehavior(dragArea: .entireSheet)
    let handleAndBackground = BottomSheetBehavior(dragArea: .handleAndBackground)

    #expect(entire.locksTrackedScroll(whileDragging: .sheet, from: .trackedScrollView))
    #expect(entire.locksTrackedScroll(whileDragging: .sheet, from: .handle) == false)
    #expect(entire.locksTrackedScroll(whileDragging: .sheet, from: .background) == false)
    #expect(entire.locksTrackedScroll(whileDragging: .sheet, from: .content) == false)
    #expect(entire.locksTrackedScroll(whileDragging: .scroll, from: .trackedScrollView) == false)

    for origin in origins {
        for target in [BottomSheetDragTarget.sheet, .scroll, .ignored] {
            #expect(handleAndBackground.locksTrackedScroll(whileDragging: target, from: origin) == false)
        }
    }
}

@Test("끌지 않을 때 스크롤을 붙잡는 경계와, 손잡이·빈 배경으로만 끌 때 붙잡지 않는 것")
func scrollLockWhileIdleBoundary() {
    let expands = BottomSheetBehavior(scrollingExpandsSheet: true)

    #expect(expands.locksTrackedScrollWhileIdle(offset: highest + 0.5, highestOffset: highest) == false)
    #expect(expands.locksTrackedScrollWhileIdle(offset: highest + 0.51, highestOffset: highest))
    #expect(BottomSheetBehavior(scrollingExpandsSheet: false).locksTrackedScrollWhileIdle(offset: belowHighest, highestOffset: highest) == false)

    /// 붙잡으면 콘텐츠로 시트를 올릴 수도 없어 시트도 목록도 움직이지 않아요.
    let handleAndBackground = BottomSheetBehavior(scrollingExpandsSheet: true, dragArea: .handleAndBackground)
    #expect(handleAndBackground.locksTrackedScrollWhileIdle(offset: belowHighest, highestOffset: highest) == false)
}
