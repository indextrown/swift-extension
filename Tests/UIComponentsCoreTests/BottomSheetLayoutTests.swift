import Foundation
import Testing
import UIComponentsCore

private let availableHeight: CGFloat = 800

// MARK: - Anchor

@Test func heightAnchorMeasuresFromBottom() {
    #expect(BottomSheetAnchor.height(96).offset(in: availableHeight) == 704)
}

@Test func fractionAnchorMeasuresProportionally() {
    #expect(BottomSheetAnchor.fraction(0.5).offset(in: availableHeight) == 400)
}

@Test func topInsetAnchorMeasuresFromTop() {
    #expect(BottomSheetAnchor.topInset(16).offset(in: availableHeight) == 16)
}

@Test func hiddenAnchorSitsAtBottom() {
    #expect(BottomSheetAnchor.hidden.offset(in: availableHeight) == availableHeight)
}

@Test("요청한 높이가 화면보다 커도 안전 영역 위로 나가지 않아요")
func anchorOffsetIsClampedToAvailableHeight() {
    #expect(BottomSheetAnchor.height(1000).offset(in: availableHeight) == 0)
    #expect(BottomSheetAnchor.topInset(1000).offset(in: availableHeight) == availableHeight)
    #expect(BottomSheetAnchor.fraction(2).offset(in: availableHeight) == 0)
}

@Test("콘텐츠 단계는 재기 전에는 여백만큼만 보이는 것으로 계산해요")
func contentAnchorBeforeMeasurementShowsPaddingOnly() {
    #expect(BottomSheetAnchor.content().offset(in: availableHeight) == availableHeight)
    #expect(BottomSheetAnchor.content(padding: 24).offset(in: availableHeight) == availableHeight - 24)
    #expect(BottomSheetAnchor.content().isContentSized)
    #expect(BottomSheetAnchor.height(10).isContentSized == false)
}

@Test("잰 높이를 넣으면 .content 단계만 .height로 바뀌고 이름과 다른 단계는 그대로예요")
func resolvingContentHeightReplacesOnlyContentDetents() {
    let layout = BottomSheetLayout(detents: [.hidden, .tip(), .content(padding: 12)])
    #expect(layout.hasContentSizedDetent)

    let resolved = layout.resolvingContentHeight(200)
    #expect(resolved.hasContentSizedDetent == false)
    #expect(resolved.detent(for: .content)?.anchor == .height(212))
    #expect(resolved.detent(for: .tip)?.anchor == .height(96))
    #expect(resolved.detent(for: .hidden)?.anchor == .hidden)
    #expect(resolved.offset(for: resolved.detent(for: .content)!, availableHeight: availableHeight) == availableHeight - 212)

    /// 원래 레이아웃에서 꺼낸 .content 단계 값을 넘겨도 같은 이름을 찾아 잰 높이로 계산해요.
    #expect(resolved.offset(for: layout.detent(for: .content)!, availableHeight: availableHeight) == availableHeight - 212)

    /// 레이아웃에 없는 이름은 넘긴 anchor를 그대로 써요.
    #expect(resolved.offset(for: BottomSheetDetent("other", anchor: .height(100)), availableHeight: availableHeight) == availableHeight - 100)

    /// .content가 없으면 자기 자신이에요.
    #expect(BottomSheetLayout.standard.resolvingContentHeight(300) == .standard)
}

@Test("콘텐츠가 화면보다 크면 안전 영역 위로 나가지 않고, 음수 높이는 0으로 봐요")
func resolvedContentDetentIsClamped() {
    let tall = BottomSheetLayout(detents: [.content()]).resolvingContentHeight(5000)
    #expect(tall.offset(for: tall.detents[0], availableHeight: availableHeight) == 0)

    let negative = BottomSheetLayout(detents: [.content(padding: 8)]).resolvingContentHeight(-50)
    #expect(negative.detents[0].anchor == .height(8))
}

// MARK: - Layout lookup

@Test func standardLayoutResolvesEachDetent() {
    let layout = BottomSheetLayout.standard

    #expect(layout.detent(for: .tip)?.anchor == .height(96))
    #expect(layout.detent(for: .half)?.anchor == .fraction(0.5))
    #expect(layout.detent(for: .full)?.anchor == .topInset(16))
    #expect(layout.detent(for: .hidden) == nil)
}

@Test func highestAndLowestFollowResolvedOffsets() {
    let layout = BottomSheetLayout.dismissible

    #expect(layout.highestDetent(availableHeight: availableHeight).identifier == BottomSheetDetent.Identifier.full)
    #expect(layout.lowestDetent(availableHeight: availableHeight).identifier == BottomSheetDetent.Identifier.hidden)
}

@Test("허용 목록이 비어 있으면 갈 곳을 잃지 않도록 전체 단계를 써요")
func emptyAllowedSetFallsBackToAllDetents() {
    let layout = BottomSheetLayout.standard

    #expect(layout.detents(among: []).count == 3)
    #expect(layout.detents(among: ["nope"]).count == 3)
    #expect(layout.detents(among: [.tip]).map(\.identifier) == [.tip])
}

@Test func nearestDetentPicksClosestOffset() {
    let layout = BottomSheetLayout.standard

    // tip=704, half=400, full=16
    #expect(layout.nearestDetent(to: 650, availableHeight: availableHeight).identifier == .tip)
    #expect(layout.nearestDetent(to: 300, availableHeight: availableHeight).identifier == .half)
    #expect(layout.nearestDetent(to: 100, availableHeight: availableHeight).identifier == .full)
}

@Test func nearestDetentRespectsAllowedSet() {
    let layout = BottomSheetLayout.standard

    // tip=704, full=16. 300은 half(400)에 가장 가깝지만 half가 허용되지 않아요.
    let detent = layout.nearestDetent(
        to: 300,
        availableHeight: availableHeight,
        among: [.tip, .full]
    )

    #expect(detent.identifier == BottomSheetDetent.Identifier.full)
}

@Test func neighboursAreResolvedByPosition() {
    let layout = BottomSheetLayout.standard
    let half = layout.detent(for: .half)!

    let above = layout.detent(above: half, availableHeight: availableHeight)
    let below = layout.detent(below: half, availableHeight: availableHeight)

    #expect(above?.identifier == BottomSheetDetent.Identifier.full)
    #expect(below?.identifier == BottomSheetDetent.Identifier.tip)

    let full = layout.detent(for: .full)!
    #expect(layout.detent(above: full, availableHeight: availableHeight) == nil)
}

// MARK: - Drag

@Test("범위 안에서는 위치를 그대로 돌려줘요")
func resistedOffsetLeavesInRangeValuesAlone() {
    let layout = BottomSheetLayout.standard

    let resisted = layout.resistedOffset(
        500,
        availableHeight: availableHeight,
        behavior: .default
    )

    #expect(resisted == 500)
}

@Test("범위를 넘으면 한계 안에서 점점 덜 따라와요")
func resistedOffsetIsBoundedByOverDragLimit() {
    let layout = BottomSheetLayout.standard
    let behavior = BottomSheetBehavior(overDragLimit: 64)

    // 가장 높은 단계(16)보다 위로 끌 때
    let slightly = layout.resistedOffset(0, availableHeight: availableHeight, behavior: behavior)
    let far = layout.resistedOffset(-500, availableHeight: availableHeight, behavior: behavior)

    #expect(slightly < 16)
    #expect(far < slightly)
    #expect(far > 16 - 64)

    // 가장 낮은 단계(704)보다 아래로 끌 때
    let below = layout.resistedOffset(800, availableHeight: availableHeight, behavior: behavior)
    let farBelow = layout.resistedOffset(5000, availableHeight: availableHeight, behavior: behavior)

    #expect(below > 704)
    #expect(below < 800)
    #expect(farBelow <= 704 + 64)
}

@Test func zeroOverDragLimitStopsHard() {
    let layout = BottomSheetLayout.standard
    let behavior = BottomSheetBehavior(overDragLimit: 0)

    #expect(layout.resistedOffset(-100, availableHeight: availableHeight, behavior: behavior) == 16)
    #expect(layout.resistedOffset(2000, availableHeight: availableHeight, behavior: behavior) == 704)
}

@Test("느리게 놓으면 위치가, 빠르게 튕기면 속도가 도착 단계를 정해요")
func targetDetentUsesVelocityProjection() {
    let layout = BottomSheetLayout.standard

    // half(400)와 tip(704) 사이, half에 더 가까운 위치에서
    let slow = layout.targetDetent(
        releasedAt: 480,
        velocity: 0,
        availableHeight: availableHeight,
        behavior: .default
    )
    let flickDown = layout.targetDetent(
        releasedAt: 480,
        velocity: 3000,
        availableHeight: availableHeight,
        behavior: .default
    )
    let flickUp = layout.targetDetent(
        releasedAt: 480,
        velocity: -4000,
        availableHeight: availableHeight,
        behavior: .default
    )

    #expect(slow.identifier == .half)
    #expect(flickDown.identifier == .tip)
    #expect(flickUp.identifier == .full)
}

// MARK: - Behavior

@Test func projectionScalesWithVelocity() {
    let behavior = BottomSheetBehavior(decelerationRate: 0.99)

    #expect(behavior.projectedDistance(for: 0) == 0)
    #expect(abs(behavior.projectedDistance(for: 1000) - 99) < 0.000_001)
    #expect(abs(behavior.projectedDistance(for: -1000) + 99) < 0.000_001)
}

@Test func projectionIgnoresInvalidDecelerationRate() {
    #expect(BottomSheetBehavior(decelerationRate: 1).projectedDistance(for: 1000) == 0)
    #expect(BottomSheetBehavior(decelerationRate: 0).projectedDistance(for: 1000) == 0)
}

@Test func resistanceNeverExceedsLimit() {
    let behavior = BottomSheetBehavior(overDragLimit: 64)

    #expect(behavior.resistedDistance(0) == 0)
    #expect(behavior.resistedDistance(-10) == 0)
    #expect(behavior.resistedDistance(10) < 10)
    #expect(behavior.resistedDistance(100) < 64)
    #expect(behavior.resistedDistance(10_000) <= 64)
    #expect(behavior.resistedDistance(10_000) > 63.9)
}

// MARK: - Backdrop

@Test("뒷판은 가장 낮은 단계에서 0, 가장 높은 단계에서 1이에요")
func backdropProgressSpansLowestToHighest() {
    let layout = BottomSheetLayout.standard

    // tip=704, full=16
    #expect(layout.backdropProgress(at: 704, availableHeight: availableHeight) == 0)
    #expect(layout.backdropProgress(at: 16, availableHeight: availableHeight) == 1)
    #expect(layout.backdropProgress(at: 360, availableHeight: availableHeight) == 0.5)
    #expect(layout.backdropProgress(at: 900, availableHeight: availableHeight) == 0)
    #expect(layout.backdropProgress(at: -50, availableHeight: availableHeight) == 1)
}

@Test("어둡게 하지 않을 단계를 정하면 그 아래에서는 0이에요")
func backdropProgressRespectsUndimmedDetent() {
    let layout = BottomSheetLayout.standard

    // half=400, full=16
    #expect(layout.backdropProgress(at: 400, availableHeight: availableHeight, largestUndimmedDetent: .half) == 0)
    #expect(layout.backdropProgress(at: 600, availableHeight: availableHeight, largestUndimmedDetent: .half) == 0)
    #expect(layout.backdropProgress(at: 208, availableHeight: availableHeight, largestUndimmedDetent: .half) == 0.5)
    #expect(layout.backdropProgress(at: 16, availableHeight: availableHeight, largestUndimmedDetent: .half) == 1)
}

@Test func backdropProgressWithSingleDetentIsBinary() {
    let layout = BottomSheetLayout(detents: [.full()])

    #expect(layout.backdropProgress(at: 16, availableHeight: availableHeight) == 1)
    #expect(layout.backdropProgress(at: 100, availableHeight: availableHeight) == 0)
}
