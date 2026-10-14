import Foundation
import Testing
import UIComponentsCore

/// `.standard`에서 full 16, half 389, tip 682인 높이예요.
private let available: CGFloat = 778
private let handle: CGFloat = 28

private let full: CGFloat = 16
private let half: CGFloat = 389
private let tip: CGFloat = 682

private func reference(
    _ layout: BottomSheetLayout = .standard,
    restingAt offset: CGFloat,
    availableHeight: CGFloat = available,
    handleHeight: CGFloat = handle,
    among allowed: Set<BottomSheetDetent.Identifier>? = nil,
    behavior: BottomSheetBehavior
) -> CGFloat {
    return layout.contentBottomReferenceOffset(
        restingAt: offset,
        availableHeight: availableHeight,
        handleHeight: handleHeight,
        among: allowed,
        behavior: behavior
    )
}

// MARK: - Default Behavior

@Test("스크롤이 시트를 올리는 기본 동작은 언제나 가장 높은 단계 기준이에요")
func contentBottomStaysAtHighestByDefault() {
    for offset in [full, half, tip] {
        #expect(reference(restingAt: offset, behavior: .default) == full)
    }
}

@Test("허용 목록이 가장 높은 단계를 빼면 허용된 가장 높은 단계에서도 바닥을 맞춰요")
func contentBottomFollowsAllowedHighest() {
    let allowed: Set<BottomSheetDetent.Identifier> = [.tip, .half]

    #expect(reference(restingAt: half, among: allowed, behavior: .default) == half)
    #expect(reference(restingAt: tip, among: allowed, behavior: .default) == full)
}

// MARK: - Free Scrolling

@Test(
    "콘텐츠가 멈춘 단계에서 스스로 스크롤하면 그 단계에 바닥을 맞춰요",
    arguments: [
        BottomSheetBehavior(dragArea: .handleAndBackground),
        BottomSheetBehavior(scrollingExpandsSheet: false)
    ]
)
func contentBottomFollowsRestingDetent(behavior: BottomSheetBehavior) {
    for offset in [full, half, tip] {
        #expect(reference(restingAt: offset, behavior: behavior) == offset)
    }
}

@Test("콘텐츠가 보이지 않는 단계는 보이는 가장 낮은 단계로 대신해요")
func contentBottomSkipsInvisibleDetents() {
    let behavior = BottomSheetBehavior(dragArea: .handleAndBackground)

    /// 완전히 내린 단계와 창 바닥 아래 위치는 tip으로 대신해요.
    #expect(reference(.dismissible, restingAt: available, behavior: behavior) == tip)
    #expect(reference(.dismissible, restingAt: available + 34, behavior: behavior) == tip)

    /// 보이는 높이가 손잡이 이하인 단계는 콘텐츠가 보이지 않아 쓰지 않아요.
    let shortTip = BottomSheetLayout(detents: [.tip(height: 20), .full()])
    #expect(reference(shortTip, restingAt: available - 20, behavior: behavior) == full)
    #expect(reference(shortTip, restingAt: available - 20, handleHeight: 0, behavior: behavior) == available - 20)
}

// MARK: - Boundaries

@Test("경계값: 가장 높은 단계 위, 높이 0, 보이는 단계가 없는 허용 목록")
func contentBottomBoundaries() {
    let behavior = BottomSheetBehavior(dragArea: .handleAndBackground)

    /// 한계를 넘어 끌어 올린 위치는 가장 높은 단계로 잘라요.
    #expect(reference(restingAt: -40, behavior: behavior) == full)

    /// 아직 높이를 모르면 0이에요.
    #expect(reference(restingAt: 0, availableHeight: 0, behavior: behavior) == 0)

    /// 보이는 단계가 하나도 허용되지 않으면 가장 높은 단계 기준이에요.
    #expect(reference(.dismissible, restingAt: 500, among: [.hidden], behavior: .default) == full)
}
