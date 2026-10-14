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
        behavior: BottomSheetBehavior = BottomSheetBehavior(animatesInitialAppearance: false),
        appearance: BottomSheetAppearance = .default,
        content: UIViewController = UIViewController()
    ) {
        self.content = content
        self.sheet = BottomSheetController(
            contentViewController: self.content,
            layout: layout,
            initialDetent: initialDetent,
            appearance: appearance,
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

/// Auto Layout 제약으로 정해진 높이를 갖는 콘텐츠예요. `.content` 단계 측정을 확인하는 데 써요.
@MainActor
private final class FixedHeightContentViewController: UIViewController {

    let heightConstraint: NSLayoutConstraint
    private let box = UIView()

    init(height: CGFloat) {
        self.heightConstraint = self.box.heightAnchor.constraint(equalToConstant: height)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.box.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.box)

        NSLayoutConstraint.activate([
            self.box.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.box.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.box.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.box.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.heightConstraint
        ])
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

@Test("content 단계는 손잡이 + 콘텐츠 높이 + 여백만큼만 올라오고, 콘텐츠가 바뀌면 다시 재요") @MainActor
func contentDetentFitsMeasuredContent() {
    let content = FixedHeightContentViewController(height: 150)
    let fixture = SheetFixture(
        layout: BottomSheetLayout(detents: [.hidden, .content(padding: 12)]),
        initialDetent: .content,
        content: content
    )
    let handle = fixture.sheet.appearance.handleAreaHeight

    #expect(fixture.sheet.currentOffset == fixture.availableHeight - (handle + 150 + 12))
    #expect(fixture.sheet.currentDetent.identifier == BottomSheetDetent.Identifier.content)

    content.heightConstraint.constant = 230
    fixture.sheet.invalidateContentHeight()

    #expect(fixture.sheet.currentOffset == fixture.availableHeight - (handle + 230 + 12))
}

@Test("preferredContentSize를 정하면 그 높이를 우선하고, 바꾸면 자동으로 다시 재요") @MainActor
func preferredContentSizeOverridesMeasurement() {
    let content = FixedHeightContentViewController(height: 150)
    content.preferredContentSize = CGSize(width: 0, height: 300)
    let fixture = SheetFixture(
        layout: BottomSheetLayout(detents: [.content()]),
        initialDetent: .content,
        content: content
    )
    let handle = fixture.sheet.appearance.handleAreaHeight

    #expect(fixture.sheet.currentOffset == fixture.availableHeight - (handle + 300))

    content.preferredContentSize = CGSize(width: 0, height: 180)

    #expect(fixture.sheet.currentOffset == fixture.availableHeight - (handle + 180))
}

@Test("따라가는 스크롤뷰가 있으면 contentSize로 재요") @MainActor
func contentDetentUsesTrackedScrollViewContentSize() {
    let fixture = SheetFixture(
        layout: BottomSheetLayout(detents: [.content()]),
        initialDetent: .content
    )
    let scrollView = UIScrollView(frame: fixture.content.view.bounds)
    scrollView.contentInsetAdjustmentBehavior = .never
    fixture.content.view.addSubview(scrollView)
    fixture.sheet.track(scrollView: scrollView)

    scrollView.contentSize = CGSize(width: 100, height: 140)

    #expect(fixture.sheet.currentOffset == fixture.availableHeight - (fixture.sheet.appearance.handleAreaHeight + 140))
}

@Test("uncoveredLayoutGuide는 안전 영역 위쪽 끝부터 시트 윗선까지이고 시트를 옮기면 따라가요") @MainActor
func uncoveredLayoutGuideFollowsSheetTop() {
    let fixture = SheetFixture(initialDetent: .half)
    let guide = fixture.sheet.uncoveredLayoutGuide
    let safe = fixture.host.view.safeAreaLayoutGuide.layoutFrame

    #expect(guide.owningView === fixture.host.view)
    #expect(guide.layoutFrame.minY == safe.minY)
    #expect(guide.layoutFrame.minX == safe.minX)
    #expect(guide.layoutFrame.maxX == safe.maxX)
    #expect(guide.layoutFrame.maxY == fixture.sheet.view.frame.minY)

    fixture.sheet.move(to: .tip, animated: false)

    #expect(guide.layoutFrame.maxY == fixture.sheet.view.frame.minY)
}

@Test("시트가 hidden으로 안전 영역 아래에 있으면 uncoveredLayoutGuide는 안전 영역 아래쪽 끝에서 멈춰요") @MainActor
func uncoveredLayoutGuideStopsAtSafeAreaBottomWhenHidden() {
    let fixture = SheetFixture(layout: .dismissible, initialDetent: .hidden)
    let safe = fixture.host.view.safeAreaLayoutGuide.layoutFrame

    #expect(fixture.sheet.view.frame.minY >= safe.maxY)
    #expect(fixture.sheet.uncoveredLayoutGuide.layoutFrame.maxY == safe.maxY)
}

@Test("attachDock은 도크를 시트 아래 층에 넣고 가리지 않은 영역의 아래 모서리에 붙여요") @MainActor
func attachDockPinsViewAboveSheet() {
    let fixture = SheetFixture(initialDetent: .half)
    let host = fixture.host.view!
    let button = BottomSheetDockView.makeButton(systemImage: "location.fill", accessibilityLabel: "현재 위치", action: UIAction { _ in })
    let dock = BottomSheetDockView(arrangedSubviews: [button])

    let constraints = fixture.sheet.attachDock(dock)
    host.layoutIfNeeded()

    #expect(constraints.count == 2)
    #expect(dock.superview === host)
    #expect(host.subviews.firstIndex(of: dock)! < host.subviews.firstIndex(of: fixture.sheet.view)!)
    #expect(dock.frame.maxY == fixture.sheet.view.frame.minY - 12)
    #expect(dock.frame.maxX == host.safeAreaLayoutGuide.layoutFrame.maxX - 16)
    #expect(dock.frame.height == BottomSheetDockView.buttonSize)

    /// 시트가 움직이면 같은 배치 패스에서 따라가요.
    fixture.sheet.move(to: .tip, animated: false)
    #expect(dock.frame.maxY == fixture.sheet.view.frame.minY - 12)

    /// 왼쪽 정렬과 다른 여백도 돼요.
    let leadingDock = UIView()
    leadingDock.heightAnchor.constraint(equalToConstant: 30).isActive = true
    leadingDock.widthAnchor.constraint(equalToConstant: 30).isActive = true
    fixture.sheet.attachDock(leadingDock, alignment: .leading, insets: UIEdgeInsets(top: 0, left: 8, bottom: 4, right: 0))
    host.layoutIfNeeded()
    #expect(leadingDock.frame.minX == host.safeAreaLayoutGuide.layoutFrame.minX + 8)
    #expect(leadingDock.frame.maxY == fixture.sheet.view.frame.minY - 4)
}

@Test("도크 항목은 표시 규칙에 따라 단계가 바뀔 때 나타나고 사라져요") @MainActor
func dockItemsFollowVisibilityRules() {
    let fixture = SheetFixture(layout: .dismissible, initialDetent: .half)
    let open = BottomSheetDockView.makeButton(systemImage: "chevron.up", accessibilityLabel: "시트 열기", action: UIAction { _ in })
    let locate = BottomSheetDockView.makeButton(systemImage: "location.fill", accessibilityLabel: "현재 위치", action: UIAction { _ in })
    let dock = BottomSheetDockView(arrangedSubviews: [open, locate])
    dock.setVisibility(.whenHidden, for: open)

    fixture.sheet.attachDock(dock)

    /// 붙는 순간 지금 단계(half)에 맞춰요.
    #expect(open.isHidden)
    #expect(locate.isHidden == false)
    #expect(dock.visibility(for: open) == .whenHidden)
    #expect(dock.visibility(for: locate) == .always)

    fixture.sheet.move(to: .hidden, animated: false)
    #expect(open.isHidden == false)
    #expect(locate.isHidden == false)

    fixture.sheet.move(to: .tip, animated: false)
    #expect(open.isHidden)
}

@Test("attachDock은 붙기 전이면 아무 일도 하지 않아요") @MainActor
func attachDockBeforeAddIsNoOp() {
    let sheet = BottomSheetController(contentViewController: UIViewController())
    let dock = UIView()

    #expect(sheet.attachDock(dock).isEmpty)
    #expect(dock.superview == nil)
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

// MARK: - Drag Area

@Test("손잡이·빈 배경으로만 끌면 가장 높은 단계 아래에서도 스크롤이 자유로워요") @MainActor
func trackedScrollIsFreeAtEveryDetentWithHandleAndBackground() {
    let fixture = SheetFixture(
        initialDetent: .tip,
        behavior: BottomSheetBehavior(animatesInitialAppearance: false, dragArea: .handleAndBackground)
    )
    let scrollView = fixture.trackTallScrollView()

    /// 스크롤이 시트를 올리는 기본값을 그대로 둬도, 콘텐츠로 시트를 올릴 수 없으니 붙잡지 않아요.
    #expect(fixture.sheet.behavior.scrollingExpandsSheet)

    scrollView.contentOffset = CGPoint(x: 0, y: 120)
    #expect(scrollView.contentOffset.y == 120)

    fixture.sheet.move(to: .half, animated: false)
    scrollView.contentOffset = CGPoint(x: 0, y: 240)
    #expect(scrollView.contentOffset.y == 240)
}

@Test("끌기 영역을 바꾸면 다음 스크롤 위치 변화부터 붙잡을지가 바뀌어요") @MainActor
func switchingDragAreaUpdatesScrollPinning() {
    let fixture = SheetFixture(initialDetent: .tip)
    let scrollView = fixture.trackTallScrollView()

    scrollView.contentOffset = CGPoint(x: 0, y: 120)
    #expect(scrollView.contentOffset.y == 0)

    fixture.sheet.behavior.dragArea = .handleAndBackground
    scrollView.contentOffset = CGPoint(x: 0, y: 120)
    #expect(scrollView.contentOffset.y == 120)

    fixture.sheet.behavior.dragArea = .entireSheet
    scrollView.contentOffset = CGPoint(x: 0, y: 200)
    #expect(scrollView.contentOffset.y == 0)
}

@Test("끌기 출발지는 손가락이 닿은 View로 정해요") @MainActor
func dragOriginFollowsHitView() {
    let fixture = SheetFixture(initialDetent: .full)
    let sheet = fixture.sheet
    let handleHeight = sheet.appearance.handleAreaHeight

    func origin(at point: CGPoint) -> BottomSheetDragOrigin {
        return sheet.classifyDragOrigin(hitView: sheet.view.hitTest(point, with: nil), location: point)
    }

    /// 손잡이 영역은 손잡이 막대 위든 그 옆이든 손잡이예요. 바로 아래 첫 점부터는 콘텐츠 화면의 빈 배경이에요.
    #expect(origin(at: CGPoint(x: 195, y: 14)) == .handle)
    #expect(origin(at: CGPoint(x: 20, y: handleHeight - 0.5)) == .handle)
    #expect(origin(at: CGPoint(x: 195, y: handleHeight)) == .background)
    #expect(origin(at: CGPoint(x: 195, y: 300)) == .background)

    let scrollView = fixture.trackTallScrollView()
    #expect(origin(at: CGPoint(x: 195, y: 300)) == .trackedScrollView)

    /// 스크롤뷰 위에 떠 있어도 스크롤뷰의 하위 View가 아니면 콘텐츠예요.
    let button = UIButton(frame: CGRect(x: 100, y: 200, width: 120, height: 44))
    fixture.content.view.addSubview(button)
    let buttonCenter = button.convert(CGPoint(x: 60, y: 22), to: sheet.view)
    #expect(origin(at: buttonCenter) == .content)
    #expect(scrollView.point(inside: sheet.view.convert(buttonCenter, to: scrollView), with: nil))
}

@Test("닿은 View를 모르면 위치로 판단해요") @MainActor
func classifiesByLocationWhenHitViewIsUnknown() {
    let fixture = SheetFixture(initialDetent: .full)
    let sheet = fixture.sheet
    let handleHeight = sheet.appearance.handleAreaHeight

    #expect(sheet.classifyDragOrigin(hitView: nil, location: CGPoint(x: 195, y: handleHeight - 0.1)) == .handle)
    #expect(sheet.classifyDragOrigin(hitView: nil, location: CGPoint(x: 195, y: handleHeight)) == .content)

    _ = fixture.trackTallScrollView()
    #expect(sheet.classifyDragOrigin(hitView: nil, location: CGPoint(x: 195, y: 300)) == .trackedScrollView)
}

@Test("손잡이를 숨겨도 손잡이·빈 배경으로만 끄는 시트는 빈 배경으로 끌어요") @MainActor
func hiddenGrabberStillDragsFromBackground() {
    let fixture = SheetFixture(
        initialDetent: .full,
        behavior: BottomSheetBehavior(animatesInitialAppearance: false, dragArea: .handleAndBackground),
        appearance: BottomSheetAppearance(showsGrabber: false)
    )
    let sheet = fixture.sheet
    let point = CGPoint(x: 195, y: 5)
    let origin = sheet.classifyDragOrigin(hitView: sheet.view.hitTest(point, with: nil), location: point)

    #expect(origin == .background)
    #expect(sheet.behavior.acceptsDrag(from: origin))

    /// 닿은 View를 모르면 빈 배경을 가릴 수 없어 콘텐츠로 봐요.
    #expect(sheet.classifyDragOrigin(hitView: nil, location: point) == .content)
}

@Test("손잡이·빈 배경으로만 끌어도 따라가는 스크롤뷰로 content 단계 높이를 재요") @MainActor
func contentDetentStillMeasuresTrackedScrollWithHandleAndBackground() {
    let fixture = SheetFixture(
        layout: BottomSheetLayout(detents: [.content()]),
        initialDetent: .content,
        behavior: BottomSheetBehavior(animatesInitialAppearance: false, dragArea: .handleAndBackground)
    )
    let scrollView = UIScrollView(frame: fixture.content.view.bounds)
    scrollView.contentInsetAdjustmentBehavior = .never
    fixture.content.view.addSubview(scrollView)
    fixture.sheet.track(scrollView: scrollView)

    scrollView.contentSize = CGSize(width: 100, height: 140)

    #expect(fixture.sheet.currentOffset == fixture.availableHeight - (fixture.sheet.appearance.handleAreaHeight + 140))
}

@Test("앱이 끈 스크롤 인디케이터는 시트가 다시 켜지 않아요") @MainActor
func trackingKeepsIndicatorTheAppTurnedOff() {
    let fixture = SheetFixture(
        initialDetent: .tip,
        behavior: BottomSheetBehavior(animatesInitialAppearance: false, dragArea: .handleAndBackground)
    )
    let scrollView = UIScrollView(frame: fixture.content.view.bounds)
    scrollView.showsVerticalScrollIndicator = false
    fixture.content.view.addSubview(scrollView)

    /// 따라가기를 바꾸거나 멈출 때 인디케이터를 되돌리는데, 시트가 숨긴 적이 없으면 건드리지 않아요.
    fixture.sheet.track(scrollView: scrollView)
    fixture.sheet.track(scrollView: nil)
    #expect(scrollView.showsVerticalScrollIndicator == false)

    let other = UIScrollView(frame: fixture.content.view.bounds)
    fixture.sheet.track(scrollView: scrollView)
    fixture.sheet.track(scrollView: other)
    #expect(scrollView.showsVerticalScrollIndicator == false)
    #expect(other.showsVerticalScrollIndicator)
}
// MARK: - Background and Drag Handle

/// 시트 View 좌표로 바꿔 hit-test한 View로 출발지를 정해요. UIKit이 실제로 고르는 View를 그대로 써요.
@MainActor
private func hitOrigin(of view: UIView, at local: CGPoint, in sheet: BottomSheetController) -> BottomSheetDragOrigin {
    let point = view.convert(local, to: sheet.view)

    return sheet.classifyDragOrigin(hitView: sheet.view.hitTest(point, with: nil), location: point)
}

@Test("빈 배경은 닿은 View에서 시트까지 터치를 받아 쓰는 View가 없는 곳이에요") @MainActor
func emptyBackgroundIsWhereNothingUsesTouches() {
    let fixture = SheetFixture(initialDetent: .full)
    let sheet = fixture.sheet
    let root = fixture.content.view!

    let stack = UIStackView(frame: CGRect(x: 20, y: 40, width: 200, height: 100))
    stack.axis = .vertical
    stack.spacing = 20
    stack.distribution = .fillEqually
    stack.addArrangedSubview(UIView())
    stack.addArrangedSubview(UIView())
    root.addSubview(stack)
    stack.layoutIfNeeded()

    let colored = UIView(frame: CGRect(x: 20, y: 160, width: 100, height: 40))
    colored.backgroundColor = .systemBlue
    root.addSubview(colored)

    let label = UILabel(frame: CGRect(x: 20, y: 220, width: 200, height: 30))
    label.text = "지역 선택"
    root.addSubview(label)

    let image = UIImageView(frame: CGRect(x: 20, y: 260, width: 40, height: 40))
    root.addSubview(image)

    #expect(hitOrigin(of: root, at: CGPoint(x: 300, y: 400), in: sheet) == .background)
    #expect(hitOrigin(of: stack, at: CGPoint(x: 100, y: 50), in: sheet) == .background)
    #expect(hitOrigin(of: colored, at: CGPoint(x: 50, y: 20), in: sheet) == .background)

    /// 라벨과 이미지뷰는 터치를 받지 않아 UIKit이 감싸는 View를 골라요.
    #expect(hitOrigin(of: label, at: CGPoint(x: 50, y: 15), in: sheet) == .background)
    #expect(hitOrigin(of: image, at: CGPoint(x: 20, y: 20), in: sheet) == .background)
}

@Test("컨트롤, 켜진 제스처 인식기가 달린 View, 따라가지 않는 스크롤뷰는 콘텐츠예요") @MainActor
func touchConsumersAreContent() {
    let fixture = SheetFixture(initialDetent: .full)
    let sheet = fixture.sheet
    let root = fixture.content.view!

    let button = UIButton(type: .system)
    button.frame = CGRect(x: 20, y: 20, width: 120, height: 44)
    button.setTitle("초기화", for: .normal)
    root.addSubview(button)

    let segmented = UISegmentedControl(items: ["거리순", "인기순"])
    segmented.frame = CGRect(x: 20, y: 80, width: 200, height: 32)
    root.addSubview(segmented)

    let card = UIView(frame: CGRect(x: 20, y: 130, width: 200, height: 80))
    let tap = UITapGestureRecognizer()
    card.addGestureRecognizer(tap)
    let cardChild = UIView(frame: CGRect(x: 10, y: 10, width: 50, height: 50))
    card.addSubview(cardChild)
    root.addSubview(card)

    let scrollView = UIScrollView(frame: CGRect(x: 20, y: 230, width: 200, height: 100))
    scrollView.contentSize = CGSize(width: 200, height: 400)
    let scrollChild = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    scrollView.addSubview(scrollChild)
    root.addSubview(scrollView)

    #expect(hitOrigin(of: button, at: CGPoint(x: 60, y: 22), in: sheet) == .content)
    #expect(hitOrigin(of: segmented, at: CGPoint(x: 50, y: 16), in: sheet) == .content)
    #expect(hitOrigin(of: card, at: CGPoint(x: 150, y: 40), in: sheet) == .content)
    #expect(hitOrigin(of: cardChild, at: CGPoint(x: 25, y: 25), in: sheet) == .content)
    #expect(hitOrigin(of: scrollView, at: CGPoint(x: 100, y: 80), in: sheet) == .content)
    #expect(hitOrigin(of: scrollChild, at: CGPoint(x: 100, y: 25), in: sheet) == .content)

    /// 인식기를 끄면 터치를 받아 쓰지 않아 빈 배경이에요.
    tap.isEnabled = false
    #expect(hitOrigin(of: card, at: CGPoint(x: 150, y: 40), in: sheet) == .background)
}

@Test("콘텐츠 화면 루트에 붙은 제스처는 빈 배경을 지우지 않고, 루트가 스크롤뷰면 콘텐츠예요") @MainActor
func rootGesturesDoNotHideBackground() {
    let fixture = SheetFixture(initialDetent: .full)
    fixture.content.view.addGestureRecognizer(UITapGestureRecognizer())

    #expect(hitOrigin(of: fixture.content.view, at: CGPoint(x: 200, y: 300), in: fixture.sheet) == .background)

    let tableContent = UITableViewController(style: .plain)
    let tableFixture = SheetFixture(initialDetent: .full, content: tableContent)
    let tableView = tableContent.tableView!

    #expect(hitOrigin(of: tableView, at: CGPoint(x: 200, y: 300), in: tableFixture.sheet) == .content)

    tableFixture.sheet.track(scrollView: tableView)
    #expect(hitOrigin(of: tableView, at: CGPoint(x: 200, y: 300), in: tableFixture.sheet) == .trackedScrollView)
}

@Test("끌기 손잡이로 지정한 View는 라벨·빈 곳이 손잡이이고 안쪽 버튼은 자기 터치를 지켜요") @MainActor
func designatedDragHandleCoversItsSubtree() {
    let fixture = SheetFixture(initialDetent: .full)
    let sheet = fixture.sheet

    let header = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 56))
    let title = UILabel(frame: CGRect(x: 16, y: 13, width: 160, height: 30))
    title.text = "지역 선택"
    let reset = UIButton(type: .system)
    reset.frame = CGRect(x: 300, y: 6, width: 80, height: 44)
    reset.setTitle("초기화", for: .normal)
    header.addSubview(title)
    header.addSubview(reset)
    fixture.content.view.addSubview(header)

    #expect(header.isBottomSheetDragHandle == false)
    #expect(hitOrigin(of: header, at: CGPoint(x: 220, y: 28), in: sheet) == .background)
    #expect(hitOrigin(of: reset, at: CGPoint(x: 40, y: 22), in: sheet) == .content)

    header.isBottomSheetDragHandle = true
    #expect(header.isBottomSheetDragHandle)
    #expect(hitOrigin(of: header, at: CGPoint(x: 220, y: 28), in: sheet) == .handle)
    #expect(hitOrigin(of: title, at: CGPoint(x: 40, y: 15), in: sheet) == .handle)
    #expect(hitOrigin(of: reset, at: CGPoint(x: 40, y: 22), in: sheet) == .content)

    /// 컨트롤 자체를 지정하면 손잡이예요.
    reset.isBottomSheetDragHandle = true
    #expect(hitOrigin(of: reset, at: CGPoint(x: 40, y: 22), in: sheet) == .handle)
    reset.isBottomSheetDragHandle = false

    header.isBottomSheetDragHandle = false
    #expect(hitOrigin(of: header, at: CGPoint(x: 220, y: 28), in: sheet) == .background)
    #expect(hitOrigin(of: reset, at: CGPoint(x: 40, y: 22), in: sheet) == .content)
}

@Test("손가락에서 가까운 표시가 이겨요") @MainActor
func nearestMarkerWins() {
    let fixture = SheetFixture(initialDetent: .full)
    let sheet = fixture.sheet
    let tracked = fixture.trackTallScrollView()

    /// 따라가는 스크롤 안의 지정 View는 손잡이예요.
    let rowHeader = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 44))
    rowHeader.isBottomSheetDragHandle = true
    tracked.addSubview(rowHeader)
    #expect(sheet.classifyDragOrigin(hitView: rowHeader, location: .zero) == .handle)

    /// 따라가는 스크롤 안의 가로 스크롤뷰는 지금처럼 따라가는 스크롤이에요.
    let carousel = UIScrollView(frame: CGRect(x: 0, y: 60, width: 390, height: 80))
    tracked.addSubview(carousel)
    #expect(sheet.classifyDragOrigin(hitView: carousel, location: .zero) == .trackedScrollView)

    /// 지정 View 안의 가로 스크롤뷰는 자기 터치를 지켜 콘텐츠예요.
    let header = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 100))
    header.isBottomSheetDragHandle = true
    let chips = UIScrollView(frame: CGRect(x: 0, y: 50, width: 390, height: 40))
    header.addSubview(chips)
    fixture.content.view.addSubview(header)
    #expect(sheet.classifyDragOrigin(hitView: chips, location: .zero) == .content)

    /// 지정 View 안의 따라가는 스크롤뷰는 따라가는 스크롤이에요.
    let wrapper = UIView(frame: fixture.content.view.bounds)
    wrapper.isBottomSheetDragHandle = true
    fixture.content.view.addSubview(wrapper)
    let inner = UIScrollView(frame: wrapper.bounds)
    wrapper.addSubview(inner)
    sheet.track(scrollView: inner)
    #expect(sheet.classifyDragOrigin(hitView: inner, location: .zero) == .trackedScrollView)
}

@Test("터치를 받지 않는 라벨을 지정하면 효과가 없어요") @MainActor
func nonInteractiveDesignatedLabelHasNoEffect() {
    let fixture = SheetFixture(initialDetent: .full)
    let label = UILabel(frame: CGRect(x: 20, y: 20, width: 200, height: 30))
    label.text = "지역 선택"
    label.isBottomSheetDragHandle = true
    fixture.content.view.addSubview(label)

    #expect(hitOrigin(of: label, at: CGPoint(x: 50, y: 15), in: fixture.sheet) == .background)
}

@Test("시트 밖 View는 지정했어도 콘텐츠예요") @MainActor
func viewsOutsideSheetAreContent() {
    let fixture = SheetFixture(initialDetent: .tip)
    let outside = UIView(frame: CGRect(x: 0, y: 100, width: 100, height: 100))
    outside.isBottomSheetDragHandle = true
    fixture.host.view.addSubview(outside)

    #expect(fixture.sheet.classifyDragOrigin(hitView: outside, location: .zero) == .content)
}

@Test("안쪽 시트 안의 터치는 안쪽 시트가 판단해요") @MainActor
func nestedSheetLeavesTouchesToInnerSheet() {
    let fixture = SheetFixture(initialDetent: .full)
    let innerContent = UIViewController()
    let inner = BottomSheetController(
        contentViewController: innerContent,
        initialDetent: .half,
        behavior: BottomSheetBehavior(animatesInitialAppearance: false)
    )
    inner.add(to: fixture.content)
    fixture.content.view.layoutIfNeeded()

    let header = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
    header.isBottomSheetDragHandle = true
    innerContent.view.addSubview(header)

    #expect(fixture.sheet.classifyDragOrigin(hitView: header, location: .zero) == .content)
    #expect(inner.classifyDragOrigin(hitView: header, location: .zero) == .handle)
}

// MARK: - Content Bottom

/// 탭바가 있는 부모를 흉내 내는 방법이에요.
enum HostVariant: CaseIterable, Sendable {

    /// 부모가 창 전체이고 아래 안전 영역은 홈 인디케이터뿐이에요.
    case fullWindow

    /// 불투명 탭바처럼 부모 View가 탭바 위까지로 줄었어요.
    case opaqueTabBar

    /// 반투명 탭바처럼 부모의 아래 안전 영역이 탭바 높이예요.
    case translucentTabBar
}

/// 화면 가장자리에 붙인 목록과, 안전 영역 바닥에 붙인 표시를 가진 콘텐츠예요.
@MainActor
private final class RowListViewController: UIViewController, UITableViewDataSource {

    let tableView = UITableView(frame: .zero, style: .plain)
    let bottomMarker = UIView()
    private let rowCount: Int

    init(rowCount: Int = 60) {
        self.rowCount = rowCount
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.tableView.dataSource = self
        self.tableView.rowHeight = 44
        self.tableView.estimatedRowHeight = 0
        self.tableView.contentInsetAdjustmentBehavior = .automatic
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        self.view.addSubview(self.tableView)

        self.bottomMarker.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.bottomMarker)

        NSLayoutConstraint.activate([
            self.tableView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.bottomMarker.widthAnchor.constraint(equalToConstant: 1),
            self.bottomMarker.heightAnchor.constraint(equalToConstant: 1),
            self.bottomMarker.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.bottomMarker.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.rowCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
    }
}

/// 목록 끝과 안전 영역 바닥 표시가 실제로 어디에 보이는지 재는 도우미예요.
@MainActor
private struct VisibleBottomFixture {
    let window: UIWindow
    let host: UIViewController
    let sheet: BottomSheetController
    let list: RowListViewController

    init(
        host variant: HostVariant,
        behavior: BottomSheetBehavior,
        layout: BottomSheetLayout = .standard,
        initialDetent: BottomSheetDetent.Identifier = .full,
        contentMode: BottomSheetContentMode = .static,
        rowCount: Int = 60
    ) {
        self.list = RowListViewController(rowCount: rowCount)
        self.sheet = BottomSheetController(
            contentViewController: self.list,
            layout: layout,
            initialDetent: initialDetent,
            behavior: behavior,
            contentMode: contentMode
        )
        self.host = UIViewController()
        self.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        self.window.rootViewController = self.host
        self.window.makeKeyAndVisible()

        let windowBottom = self.window.safeAreaInsets.bottom

        switch variant {
        case .fullWindow:
            /// 창에 안전 영역이 없으면 홈 인디케이터 높이를 부모에 줘요.
            if windowBottom == 0 {
                self.host.additionalSafeAreaInsets.bottom = 34
            }

        case .opaqueTabBar:
            break

        case .translucentTabBar:
            self.host.additionalSafeAreaInsets.bottom = 83 - windowBottom
        }

        self.sheet.add(to: self.host)
        self.host.view.layoutIfNeeded()

        if variant == .opaqueTabBar {
            self.host.view.frame = CGRect(x: 0, y: 0, width: self.window.bounds.width, height: self.window.bounds.height - 83)
            self.host.view.layoutIfNeeded()
        }

        self.settle()
    }

    /// 부모 안전 영역 바닥의 창 좌표예요. 탭바나 홈 인디케이터 윗선이에요.
    var hostSafeBottom: CGFloat {
        let host = self.host.view!

        return host.convert(CGPoint(x: 0, y: host.safeAreaLayoutGuide.layoutFrame.maxY), to: nil).y
    }

    /// 목록 끝이 부모 안전 영역 바닥보다 아래에 있는 길이예요. 0이면 마지막 줄이 보이는 바닥에 닿아요.
    var listEndGap: CGFloat {
        let tableView = self.list.tableView

        return tableView.convert(CGPoint(x: 0, y: tableView.contentSize.height), to: nil).y - self.hostSafeBottom
    }

    /// 안전 영역 바닥에 붙인 표시가 부모 안전 영역 바닥보다 아래에 있는 길이예요.
    var bottomMarkerGap: CGFloat {
        let marker = self.list.bottomMarker

        return marker.convert(CGPoint(x: 0, y: marker.bounds.maxY), to: nil).y - self.hostSafeBottom
    }

    func offset(for identifier: BottomSheetDetent.Identifier) -> CGFloat {
        return self.sheet.offset(for: self.sheet.layout.detent(for: identifier)!)
    }

    func settle() {
        self.host.view.layoutIfNeeded()
        self.sheet.view.layoutIfNeeded()
        self.list.view.layoutIfNeeded()
        self.list.tableView.layoutIfNeeded()
    }

    func scrollListToEnd() {
        let tableView = self.list.tableView
        tableView.layoutIfNeeded()

        let inset = tableView.adjustedContentInset
        let maxY = max(tableView.contentSize.height + inset.bottom - tableView.bounds.height, -inset.top)
        tableView.contentOffset = CGPoint(x: 0, y: maxY)
        tableView.layoutIfNeeded()
    }
}

/// 멈춘 단계에서 콘텐츠가 스스로 스크롤하는 움직임 값이에요.
private let freelyScrollingBehaviors: [BottomSheetBehavior] = [
    BottomSheetBehavior(animatesInitialAppearance: false, dragArea: .handleAndBackground),
    BottomSheetBehavior(animatesInitialAppearance: false, scrollingExpandsSheet: false)
]

@Test(
    "static에서 콘텐츠가 스스로 스크롤하면 모든 단계에서 목록 끝과 아래 표시가 보이는 바닥에 닿아요",
    arguments: HostVariant.allCases, freelyScrollingBehaviors
)
@MainActor
func staticListEndReachesVisibleBottom(host: HostVariant, behavior: BottomSheetBehavior) {
    let fixture = VisibleBottomFixture(host: host, behavior: behavior)

    for detent in [BottomSheetDetent.Identifier.full, .half, .tip] {
        fixture.sheet.move(to: detent, animated: false)
        fixture.settle()
        fixture.scrollListToEnd()

        #expect(abs(fixture.listEndGap) <= 0.5, "\(detent.rawValue) 목록 끝 \(fixture.listEndGap)")
        #expect(abs(fixture.bottomMarkerGap) <= 0.5, "\(detent.rawValue) 아래 표시 \(fixture.bottomMarkerGap)")
    }
}

@Test("멈춘 상태에서 static과 fitToBounds의 보이는 바닥이 같아요", arguments: HostVariant.allCases)
@MainActor
func fitToBoundsAndStaticShareVisibleBottomAtRest(host: HostVariant) {
    let behavior = BottomSheetBehavior(animatesInitialAppearance: false, dragArea: .handleAndBackground)
    let fixture = VisibleBottomFixture(host: host, behavior: behavior, contentMode: .fitToBounds)

    for detent in [BottomSheetDetent.Identifier.full, .half, .tip] {
        fixture.sheet.move(to: detent, animated: false)
        fixture.settle()
        fixture.scrollListToEnd()

        #expect(abs(fixture.listEndGap) <= 0.5, "\(detent.rawValue) 목록 끝 \(fixture.listEndGap)")
        #expect(abs(fixture.bottomMarkerGap) <= 0.5, "\(detent.rawValue) 아래 표시 \(fixture.bottomMarkerGap)")
    }
}

@Test("static 기본 동작은 가장 높은 단계에서만 바닥을 맞추고 낮은 단계는 그 기준을 유지해요", arguments: HostVariant.allCases)
@MainActor
func staticDefaultBehaviorFitsOnlyAtHighest(host: HostVariant) {
    let fixture = VisibleBottomFixture(host: host, behavior: BottomSheetBehavior(animatesInitialAppearance: false))
    let full = fixture.offset(for: .full)

    fixture.scrollListToEnd()
    #expect(abs(fixture.listEndGap) <= 0.5)
    #expect(abs(fixture.bottomMarkerGap) <= 0.5)

    for detent in [BottomSheetDetent.Identifier.half, .tip] {
        fixture.sheet.move(to: detent, animated: false)
        fixture.settle()

        #expect(abs(fixture.bottomMarkerGap - (fixture.sheet.currentOffset - full)) <= 0.5)
    }
}

/// 시트 View의 애니메이션이 모두 끝날 때까지 기다려요. 시간을 정해 두고 기다리면 부하가 큰 기기에서 흔들려요.
@MainActor
private func waitForAnimations(on view: UIView, timeout: TimeInterval = 5) async throws {
    let deadline = Date().addingTimeInterval(timeout)

    repeat {
        try await Task.sleep(nanoseconds: 50_000_000)
    } while (view.layer.animationKeys()?.isEmpty == false) && Date() < deadline

    /// 완료 블록이 다음 런 루프에서 돌 수 있어 한 번 더 양보해요.
    try await Task.sleep(nanoseconds: 50_000_000)
}

@Test("애니메이션으로 올라가면 끝까지 내린 따라가는 목록이 보이는 바닥에 붙은 채 움직여요") @MainActor
func animatedMoveKeepsTrackedListEnd() async throws {
    let behavior = BottomSheetBehavior(animationDuration: 0.1, animatesInitialAppearance: false, dragArea: .handleAndBackground)
    let fixture = VisibleBottomFixture(host: .fullWindow, behavior: behavior, initialDetent: .half)
    fixture.sheet.track(scrollView: fixture.list.tableView)
    fixture.settle()
    fixture.scrollListToEnd()
    #expect(abs(fixture.listEndGap) <= 0.5)

    /// 애니메이션 블록은 시작할 때 돌아 모델 값은 이미 도착값이에요.
    fixture.sheet.move(to: .full, animated: true)
    #expect(abs(fixture.listEndGap) <= 0.5, "올라간 뒤 목록 끝 \(fixture.listEndGap)")

    try await waitForAnimations(on: fixture.sheet.view)

    let offsetAtFull = fixture.list.tableView.contentOffset.y
    fixture.sheet.move(to: .tip, animated: true)
    try await waitForAnimations(on: fixture.sheet.view)

    /// 내려갈 때는 목록 위치를 그대로 두고, 끝까지 스크롤하면 바닥에 닿아요.
    #expect(abs(fixture.list.tableView.contentOffset.y - offsetAtFull) <= 0.5)

    fixture.scrollListToEnd()
    #expect(abs(fixture.listEndGap) <= 0.5, "tip 목록 끝 \(fixture.listEndGap)")
}

@Test("content 단계가 있는 레이아웃은 시트 몫을 고정해 잰 높이와 위치가 서로를 흔들지 않아요") @MainActor
func contentSizedLayoutKeepsBottomShareFixed() {
    let content = FixedHeightContentViewController(height: 150)
    let fixture = SheetFixture(
        layout: BottomSheetLayout(detents: [.content(padding: 12), .full()]),
        initialDetent: .content,
        behavior: BottomSheetBehavior(animatesInitialAppearance: false, dragArea: .handleAndBackground),
        content: content
    )
    let overDrag = fixture.sheet.behavior.overDragLimit
    let first = fixture.sheet.currentOffset

    for _ in 0..<3 {
        fixture.sheet.invalidateContentHeight()
        fixture.host.view.layoutIfNeeded()
        fixture.sheet.view.layoutIfNeeded()
    }

    #expect(fixture.sheet.currentOffset == first)
    #expect(content.additionalSafeAreaInsets.bottom == overDrag)

    fixture.sheet.move(to: .full, animated: false)
    #expect(content.additionalSafeAreaInsets.bottom == overDrag)
}

@Test("허용된 가장 높은 단계에서도 바닥을 맞춰요") @MainActor
func allowedHighestFitsContentBottom() {
    let fixture = VisibleBottomFixture(
        host: .fullWindow,
        behavior: BottomSheetBehavior(animatesInitialAppearance: false),
        initialDetent: .half
    )
    fixture.sheet.allowedDetents = [.tip, .half]
    fixture.settle()

    #expect(abs(fixture.bottomMarkerGap) <= 0.5)

    fixture.sheet.move(to: .tip, animated: false)
    fixture.settle()

    #expect(abs(fixture.bottomMarkerGap - (fixture.offset(for: .tip) - fixture.offset(for: .full))) <= 0.5)
}

@Test("멈춰 있을 때 끌기 영역을 바꾸면 콘텐츠 바닥을 바로 다시 맞춰요") @MainActor
func switchingDragAreaRefitsAtRest() {
    let fixture = VisibleBottomFixture(
        host: .fullWindow,
        behavior: BottomSheetBehavior(animatesInitialAppearance: false),
        initialDetent: .half
    )
    let expectedDefaultGap = fixture.offset(for: .half) - fixture.offset(for: .full)

    #expect(abs(fixture.bottomMarkerGap - expectedDefaultGap) <= 0.5)

    fixture.sheet.behavior.dragArea = .handleAndBackground
    fixture.settle()
    #expect(abs(fixture.bottomMarkerGap) <= 0.5)

    fixture.sheet.behavior.dragArea = .entireSheet
    fixture.settle()
    #expect(abs(fixture.bottomMarkerGap - expectedDefaultGap) <= 0.5)
}

@Test("멈춘 채 여백이 줄면 끝까지 내린 따라가는 목록을 새 끝으로 당겨요") @MainActor
func restingInsetShrinkClampsTrackedListToEnd() {
    let fixture = VisibleBottomFixture(
        host: .fullWindow,
        behavior: BottomSheetBehavior(animatesInitialAppearance: false, scrollingExpandsSheet: false),
        initialDetent: .half
    )
    fixture.sheet.track(scrollView: fixture.list.tableView)
    fixture.settle()
    fixture.scrollListToEnd()

    /// 스크롤이 시트를 올리는 모드로 바꾸면 half는 가장 높은 단계 기준이라 아래 여백이 줄어요.
    fixture.sheet.behavior.scrollingExpandsSheet = true
    fixture.settle()

    let tableView = fixture.list.tableView
    let maxY = max(tableView.contentSize.height + tableView.adjustedContentInset.bottom - tableView.bounds.height, -tableView.adjustedContentInset.top)

    #expect(tableView.contentOffset.y <= maxY + 0.5)
}

@Test("완전히 내리면 보이는 가장 낮은 단계의 몫을 유지해요") @MainActor
func hiddenKeepsLowestVisibleShare() {
    let fixture = VisibleBottomFixture(
        host: .fullWindow,
        behavior: BottomSheetBehavior(animatesInitialAppearance: false, dragArea: .handleAndBackground),
        layout: .dismissible,
        initialDetent: .tip
    )
    let shareAtTip = fixture.list.additionalSafeAreaInsets.bottom

    fixture.sheet.move(to: .hidden, animated: false)
    fixture.settle()

    #expect(fixture.list.additionalSafeAreaInsets.bottom == shareAtTip)
}

@Test("부모 크기가 바뀌면 멈춘 단계의 콘텐츠 바닥을 다시 맞춰요") @MainActor
func hostResizeRefitsContentBottom() {
    let fixture = VisibleBottomFixture(
        host: .fullWindow,
        behavior: BottomSheetBehavior(animatesInitialAppearance: false, dragArea: .handleAndBackground),
        initialDetent: .half
    )

    fixture.host.view.frame = CGRect(x: 0, y: 0, width: fixture.window.bounds.width, height: fixture.window.bounds.height - 83)
    fixture.settle()

    #expect(abs(fixture.bottomMarkerGap) <= 0.5)
}

@Test(
    "앱이 정한 콘텐츠 아래 안전 영역은 지키고 그 위에 시트 몫만 더해요",
    arguments: [BottomSheetContentMode.static, .fitToBounds]
)
@MainActor
func appBottomInsetIsPreserved(contentMode: BottomSheetContentMode) {
    let content = UIViewController()
    content.additionalSafeAreaInsets.bottom = 20
    let fixture = SheetFixture(contentMode: contentMode, content: content)

    switch contentMode {
    case .static:
        #expect(content.additionalSafeAreaInsets.bottom == 20 + fixture.sheet.behavior.overDragLimit)

    case .fitToBounds:
        #expect(content.additionalSafeAreaInsets.bottom == 20)
    }

    fixture.sheet.remove()
    #expect(content.additionalSafeAreaInsets.bottom == 20)
}
@Test("remove()하면 붙인 도크도 함께 떼어지고, 다시 붙인 뒤 attachDock으로 이어 붙여요") @MainActor
func removeDetachesDocks() {
    let fixture = SheetFixture(initialDetent: .tip)
    let dock = BottomSheetDockView(arrangedSubviews: [UIView()])
    let other = UIView()

    fixture.sheet.attachDock(dock)
    fixture.sheet.attachDock(other)
    #expect(dock.superview === fixture.host.view)

    fixture.sheet.remove()
    #expect(dock.superview == nil)
    #expect(other.superview == nil)

    fixture.sheet.add(to: fixture.host)
    fixture.host.view.layoutIfNeeded()
    #expect(dock.superview == nil)

    #expect(fixture.sheet.attachDock(dock).isEmpty == false)
    #expect(dock.superview === fixture.host.view)
}
#endif
