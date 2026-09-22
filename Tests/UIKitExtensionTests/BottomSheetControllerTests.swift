#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import Testing
import UIKit
@testable import UIKitExtension

/// 시트를 실제 창에 붙여 배치까지 돌린 뒤 검증하는 도우미예요.
@MainActor
private struct SheetFixture {
    let window: UIWindow
    let host: UIViewController
    let sheet: BottomSheetController
    let content: UIViewController

    init(
        layout: BottomSheetLayout = .standard,
        initialDetent: BottomSheetDetent.Identifier = .tip,
        contentMode: BottomSheetContentMode = .static,
        behavior: BottomSheetBehavior = BottomSheetBehavior(animatesInitialAppearance: false)
    ) {
        self.content = UIViewController()
        self.sheet = BottomSheetController(
            contentViewController: self.content,
            layout: layout,
            initialDetent: initialDetent,
            behavior: behavior,
            contentMode: contentMode
        )
        self.host = UIViewController()
        self.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        self.window.rootViewController = self.host
        self.window.makeKeyAndVisible()

        self.sheet.add(to: self.host)
        self.host.view.layoutIfNeeded()
    }

    var availableHeight: CGFloat {
        return self.host.view.safeAreaLayoutGuide.layoutFrame.height
    }

    func offset(for identifier: BottomSheetDetent.Identifier) -> CGFloat {
        let detent = self.sheet.layout.detent(for: identifier)!
        return self.sheet.layout.offset(for: detent, availableHeight: self.availableHeight)
    }

    /// 콘텐츠 안에 화면보다 긴 스크롤뷰를 넣고 시트가 따라가게 합니다. 안전 영역 보정을 꺼서 맨 위가 0이 되게 해요.
    func trackTallScrollView() -> UIScrollView {
        let scrollView = UIScrollView(frame: self.content.view.bounds)
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: scrollView.bounds.height * 4)
        self.content.view.addSubview(scrollView)
        self.sheet.track(scrollView: scrollView)

        return scrollView
    }
}

@Test @MainActor func addEmbedsSheetAndContentAsChildren() {
    let fixture = SheetFixture()

    #expect(fixture.sheet.parent === fixture.host)
    #expect(fixture.content.parent === fixture.sheet)
    #expect(fixture.sheet.view.superview === fixture.host.view)
    #expect(fixture.content.view.isDescendant(of: fixture.sheet.view))
}

@Test @MainActor func sheetStartsAtInitialDetentAfterLayout() {
    let fixture = SheetFixture(initialDetent: .half)

    #expect(fixture.sheet.currentDetent.identifier == BottomSheetDetent.Identifier.half)
    #expect(fixture.sheet.currentOffset == fixture.offset(for: .half))
    #expect(fixture.sheet.view.isHidden == false)
}

@Test("fitToBounds에서는 시트 바닥이 부모 View 바닥에 붙어 탭바 뒤까지 이어져요") @MainActor
func fitToBoundsSheetExtendsToHostBottom() {
    let fixture = SheetFixture(contentMode: .fitToBounds)

    #expect(fixture.sheet.view.frame.maxY == fixture.host.view.bounds.maxY)
    #expect(fixture.sheet.view.frame.minY
            == fixture.host.view.safeAreaLayoutGuide.layoutFrame.minY + fixture.offset(for: .tip))
}

@Test("static에서는 시트 높이가 가장 높은 단계 기준으로 고정돼요") @MainActor
func staticSheetKeepsHeightAcrossDetents() {
    let fixture = SheetFixture(contentMode: .static)
    let host = fixture.host.view!
    let bottomInset = host.bounds.maxY - host.safeAreaLayoutGuide.layoutFrame.maxY
    let expected = fixture.availableHeight - fixture.offset(for: .full) + bottomInset + fixture.sheet.behavior.overDragLimit

    #expect(fixture.sheet.view.frame.height == expected)
    #expect(fixture.sheet.view.frame.minY
            == host.safeAreaLayoutGuide.layoutFrame.minY + fixture.offset(for: .tip))

    fixture.sheet.move(to: .full, animated: false)

    #expect(fixture.sheet.view.frame.height == expected)
    #expect(fixture.sheet.view.frame.maxY == host.bounds.maxY + fixture.sheet.behavior.overDragLimit)
}

@Test @MainActor func moveWithoutAnimationJumpsToDetent() {
    let fixture = SheetFixture()

    fixture.sheet.move(to: .full, animated: false)

    #expect(fixture.sheet.currentDetent.identifier == BottomSheetDetent.Identifier.full)
    #expect(fixture.sheet.currentOffset == fixture.offset(for: .full))
}

@Test @MainActor func moveToUnknownDetentIsIgnored() {
    let fixture = SheetFixture()

    fixture.sheet.move(to: "nope", animated: false)

    #expect(fixture.sheet.currentDetent.identifier == BottomSheetDetent.Identifier.tip)
}

@Test("허용 목록에서 빠지면 가장 가까운 허용 단계로 옮겨요") @MainActor
func disallowingCurrentDetentMovesToNearestAllowed() {
    let fixture = SheetFixture(initialDetent: .tip)

    fixture.sheet.allowedDetents = [.half, .full]

    #expect(fixture.sheet.currentDetent.identifier == BottomSheetDetent.Identifier.half)
}

@Test @MainActor func moveBeforeLayoutIsAppliedOnFirstLayout() {
    let content = UIViewController()
    let sheet = BottomSheetController(
        contentViewController: content,
        behavior: BottomSheetBehavior(animatesInitialAppearance: false)
    )

    sheet.move(to: .full, animated: true)

    let host = UIViewController()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = host
    window.makeKeyAndVisible()
    sheet.add(to: host)
    host.view.layoutIfNeeded()

    let full = sheet.layout.detent(for: .full)!
    let expected = sheet.layout.offset(
        for: full,
        availableHeight: host.view.safeAreaLayoutGuide.layoutFrame.height
    )

    #expect(sheet.currentDetent.identifier == BottomSheetDetent.Identifier.full)
    #expect(sheet.currentOffset == expected)
}

@Test @MainActor func removeDetachesEverything() {
    let fixture = SheetFixture()

    fixture.sheet.remove()

    #expect(fixture.sheet.parent == nil)
    #expect(fixture.sheet.view.superview == nil)
    #expect(fixture.host.children.isEmpty)
}

@Test @MainActor func addTwiceIsNoOp() {
    let fixture = SheetFixture()

    fixture.sheet.add(to: fixture.host)

    #expect(fixture.host.children.count == 1)
}

@Test @MainActor func delegateReceivesDetentChanges() {
    final class Recorder: BottomSheetControllerDelegate {
        var detents: [BottomSheetDetent.Identifier] = []

        func bottomSheet(_ controller: BottomSheetController, didChangeDetent detent: BottomSheetDetent) {
            self.detents.append(detent.identifier)
        }
    }

    let fixture = SheetFixture()
    let recorder = Recorder()
    fixture.sheet.delegate = recorder

    fixture.sheet.move(to: .half, animated: false)
    fixture.sheet.move(to: .half, animated: false)
    fixture.sheet.move(to: .full, animated: false)

    #expect(recorder.detents == [.half, .full])
}

@Test("hidden 단계는 안전 영역이 아니라 창 바닥까지 내려가요") @MainActor
func hiddenDetentSitsBelowWindowBottom() {
    let fixture = SheetFixture(layout: .dismissible, initialDetent: .tip)

    fixture.sheet.move(to: .hidden, animated: false)

    let top = fixture.sheet.view.convert(fixture.sheet.view.bounds, to: fixture.window).minY

    #expect(top == fixture.window.bounds.maxY)
}

@Test("부모 View가 창보다 짧아도 hidden은 창 바닥까지 내려가요") @MainActor
func hiddenDetentIgnoresShortenedHost() {
    let fixture = SheetFixture(layout: .dismissible, initialDetent: .tip)

    // 불투명 탭바가 콘텐츠 View를 줄인 상황을 흉내내요.
    fixture.host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844 - 83)
    fixture.host.view.layoutIfNeeded()

    fixture.sheet.move(to: .hidden, animated: false)

    let top = fixture.sheet.view.convert(fixture.sheet.view.bounds, to: fixture.window).minY

    #expect(top == fixture.window.bounds.maxY)
    #expect(top > fixture.host.view.bounds.maxY)
}

@Test("static에서는 콘텐츠 안전 영역 바닥이 부모 안전 영역 바닥에 맞춰져요") @MainActor
func staticContentSafeAreaEndsAtHostSafeBottom() {
    let fixture = SheetFixture(contentMode: .static)

    // 불투명 탭바가 부모 View를 줄인 상황을 흉내내요. 창 안전 영역은 그대로예요.
    fixture.host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844 - 83)
    fixture.host.view.layoutIfNeeded()
    fixture.sheet.view.layoutIfNeeded()

    let host = fixture.host.view!
    let window = fixture.window
    let overDrag = fixture.sheet.behavior.overDragLimit
    let desired = (host.bounds.maxY - host.safeAreaLayoutGuide.layoutFrame.maxY) + overDrag
    let inherited = max((host.bounds.maxY + overDrag) - (window.bounds.maxY - window.safeAreaInsets.bottom), 0)

    #expect(fixture.content.additionalSafeAreaInsets.bottom == max(desired - inherited, 0))
    #expect(fixture.content.additionalSafeAreaInsets.bottom > 0)
}

@Test @MainActor func fitToBoundsAddsNoSafeArea() {
    let fixture = SheetFixture(contentMode: .fitToBounds)

    #expect(fixture.content.additionalSafeAreaInsets.bottom == 0)
}

@Test("스크롤이 시트를 올리는 모드(기본값)에서는 가장 높은 단계 아래에서 스크롤을 맨 위에 붙잡아요") @MainActor
func trackedScrollIsPinnedBelowHighestDetentByDefault() {
    let fixture = SheetFixture(initialDetent: .tip)
    let scrollView = fixture.trackTallScrollView()

    #expect(BottomSheetBehavior.default.scrollingExpandsSheet)

    scrollView.contentOffset = CGPoint(x: 0, y: 120)
    #expect(scrollView.contentOffset.y == 0)

    /// 가장 높은 단계에 닿으면 붙잡지 않아요.
    fixture.sheet.move(to: .full, animated: false)
    scrollView.contentOffset = CGPoint(x: 0, y: 120)
    #expect(scrollView.contentOffset.y == 120)
}

@Test("스크롤이 시트를 올리지 않는 모드에서는 어느 단계에서든 스크롤이 자유로워요") @MainActor
func trackedScrollIsFreeWhenScrollingDoesNotExpandSheet() {
    let fixture = SheetFixture(
        initialDetent: .tip,
        behavior: BottomSheetBehavior(animatesInitialAppearance: false, scrollingExpandsSheet: false)
    )
    let scrollView = fixture.trackTallScrollView()

    scrollView.contentOffset = CGPoint(x: 0, y: 120)
    #expect(scrollView.contentOffset.y == 120)

    fixture.sheet.move(to: .half, animated: false)
    scrollView.contentOffset = CGPoint(x: 0, y: 240)
    #expect(scrollView.contentOffset.y == 240)
}
#endif
