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
        content: UIViewController = UIViewController()
    ) {
        self.content = content
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
#endif
