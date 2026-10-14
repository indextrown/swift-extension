#if !os(tvOS)
import Foundation
import SwiftUI
import Testing
@testable import SwiftUIExtension

private let designatedA = BottomSheetDragSource.designated(UUID())
private let designatedB = BottomSheetDragSource.designated(UUID())
private let point = CGPoint(x: 120, y: 400)

// MARK: - Source

@Test("제스처 출처는 Core 출발지로 바뀌어요")
func dragSourceMapsToOrigin() {
    #expect(BottomSheetDragSource.grabber.origin(hasTrackedScroll: true) == .handle)
    #expect(designatedA.origin(hasTrackedScroll: true) == .handle)
    #expect(BottomSheetDragSource.background.origin(hasTrackedScroll: true) == .background)
    #expect(BottomSheetDragSource.content.origin(hasTrackedScroll: true) == .trackedScrollView)
    #expect(BottomSheetDragSource.content.origin(hasTrackedScroll: false) == .content)
}

// MARK: - Arbitration

@Test("먼저 잡은 제스처가 끌기를 갖고, 같은 손가락이면 지정한 View가 콘텐츠 끌기를 넘겨받아요")
func arbitrationFollowsFirstClaim() {
    func arbitrate(_ source: BottomSheetDragSource, against owner: BottomSheetDragSource?) -> BottomSheetDragArbitration {
        let claim = BottomSheetDragClaim(source: source, startLocation: point)

        return claim.arbitrate(against: owner.map { BottomSheetDragClaim(source: $0, startLocation: point) })
    }

    #expect(arbitrate(.content, against: nil) == .begin)
    #expect(arbitrate(.grabber, against: .grabber) == .follow)
    #expect(arbitrate(designatedA, against: designatedA) == .follow)
    #expect(arbitrate(designatedA, against: .content) == .takeOver)

    #expect(arbitrate(.content, against: designatedA) == .ignore)
    #expect(arbitrate(designatedB, against: designatedA) == .ignore)
    #expect(arbitrate(.content, against: .grabber) == .ignore)
    #expect(arbitrate(designatedA, against: .background) == .ignore)
    #expect(arbitrate(.grabber, against: designatedA) == .ignore)
}

@Test("같은 손가락으로 보는 시작 위치의 경계는 1pt예요")
func sameTouchToleranceBoundary() {
    let owner = BottomSheetDragClaim(source: .content, startLocation: point)

    func arbitrate(dx: CGFloat, dy: CGFloat) -> BottomSheetDragArbitration {
        let claim = BottomSheetDragClaim(
            source: designatedA,
            startLocation: CGPoint(x: point.x + dx, y: point.y + dy)
        )

        return claim.arbitrate(against: owner)
    }

    #expect(arbitrate(dx: 0, dy: 0) == .takeOver)
    #expect(arbitrate(dx: 1, dy: 0) == .takeOver)
    #expect(arbitrate(dx: 1.01, dy: 0) == .ignore)
    #expect(arbitrate(dx: 0.8, dy: 0.8) == .ignore)
}

// MARK: - Gesture Mask

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
@Test("손잡이·배경·콘텐츠 제스처 마스크는 Core가 받는 출발지를 따라요")
func gestureMasksFollowCoreAcceptance() {
    let entire = BottomSheetBehavior.default
    let handleAndBackground = BottomSheetBehavior(dragArea: .handleAndBackground)

    #expect(entire.handleDragGestureMask == .all)
    #expect(entire.backgroundDragGestureMask == .all)
    #expect(entire.contentDragGestureMask == .all)

    #expect(handleAndBackground.handleDragGestureMask == .all)
    #expect(handleAndBackground.backgroundDragGestureMask == .all)
    #expect(handleAndBackground.contentDragGestureMask == .subviews)
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
@Test("지정한 View의 제스처는 켜져 있고 시트가 손잡이를 받을 때만 켜져요")
func designatedHandleMask() {
    for isEnabled in [true, false] {
        for sinkAcceptsDrag in [true, false, nil] as [Bool?] {
            let expected: GestureMask = isEnabled && sinkAcceptsDrag == true ? .all : .subviews

            #expect(BottomSheetDragHandleModifier.gestureMask(isEnabled: isEnabled, sinkAcceptsDrag: sinkAcceptsDrag) == expected)
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
@Test("시트 밖에는 끌기 통로가 없어요")
func dragSinkIsAbsentOutsideSheet() {
    #expect(EnvironmentValues().bottomSheetDragSink == nil)
}
#endif
