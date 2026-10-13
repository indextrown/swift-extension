//
//  BottomSheetController.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import UIComponentsCore
import UIKit

/// 부모 화면 안에 자식으로 붙어 탭바 뒤에서 올라오는 바텀시트입니다.
///
/// `present`로 띄우는 시트는 창 전체를 덮어 탭바까지 가립니다. 이 시트는 부모 화면의
/// View에 직접 들어가므로, 부모가 탭바 컨트롤러의 자식이면 시트도 탭바 뒤에 놓이고
/// 탭바는 그대로 눌립니다. 지도 위에 정보를 얹는 화면처럼 시트를 올려 둔 채로
/// 다른 탭으로 옮겨 다녀야 하는 곳에 맞습니다.
///
/// 시트는 `BottomSheetLayout`에 등록된 단계에서만 멈춥니다. 손을 뗀 위치와 속도로
/// 가장 가까운 단계를 골라 스프링으로 옮깁니다. 콘텐츠에 스크롤뷰가 있으면
/// `track(scrollView:)`로 넘겨 두면, 시트가 다 올라가기 전에는 스크롤 대신 시트가
/// 움직이고 다 올라간 뒤에야 스크롤이 시작됩니다. 스크롤이 시트를 올리지 않게 하려면
/// `BottomSheetBehavior.scrollingExpandsSheet`를 `false`로 둡니다.
///
/// 콘텐츠에 `UITableView`나 스크롤뷰가 여러 개라 스크롤할 때 시트가 끌리면 안 되면
/// `behavior.dragArea`를 `.handleAndBackground`로 둡니다. 손잡이 줄과 콘텐츠의 빈 배경으로만 시트가 움직이고
/// 콘텐츠는 스크롤만 합니다. 탭 제스처가 달린 제목줄처럼 그 자체가 터치를 받는 View도 끌리게 하려면 그 View의 `isBottomSheetDragHandle`을 켭니다.
///
/// ```swift
/// let sheet = BottomSheetController(contentViewController: listViewController)
/// sheet.add(to: self)
/// sheet.track(scrollView: listViewController.tableView)
/// ```
@MainActor
public final class BottomSheetController: UIViewController {

    // MARK: - Property

    /// 시트 안에 표시하는 화면입니다.
    ///
    /// `contentMode`가 `.static`이면 시트가 이 화면의 `additionalSafeAreaInsets.bottom`에, 시트 바닥이 부모 View 바닥
    /// 아래로 나간 길이를 더해 안전 영역 바닥을 탭바·홈 인디케이터 윗선에 맞춥니다. 처음 더하기 전의 값은 앱의 값으로 두고
    /// 그 위에 더하며 `remove()`하면 되돌립니다. 붙어 있는 동안 앱이 이 값을 바꾸면 시트가 다음에 맞출 때 덮어씁니다.
    /// `.fitToBounds`에서는 이 값을 바꾸지 않습니다.
    public let contentViewController: UIViewController

    /// 시트가 멈출 단계의 목록입니다. 바꾸면 같은 이름의 단계로 자리를 다시 잡습니다.
    public var layout: BottomSheetLayout {
        didSet { self.applyLayoutChange() }
    }

    /// 시트의 표시 속성입니다.
    public let appearance: BottomSheetAppearance

    /// 시트가 손을 따라오고 단계 사이를 옮기는 방식입니다.
    ///
    /// 값을 바꾸면 다음 끌기부터 적용됩니다. 진행 중인 끌기는 시작할 때의 값으로 시트와 스크롤 사이를 판단합니다.
    /// 끌지 않을 때 스크롤을 붙잡을지는 다음 스크롤 위치 변화부터 새 값을 따릅니다. 멈춰 있을 때 바꾸면 `static`
    /// 콘텐츠의 아래쪽 안전 영역도 새 값에 맞춥니다.
    public var behavior: BottomSheetBehavior {
        didSet { self.refreshContentBottomInsetIfResting() }
    }

    /// 시트가 움직일 때 콘텐츠 높이를 다루는 방식입니다.
    public let contentMode: BottomSheetContentMode

    /// 시트의 움직임을 받는 대리자입니다.
    public weak var delegate: BottomSheetControllerDelegate?

    /// 시트가 현재 머무는 단계입니다.
    ///
    /// 손을 뗀 뒤 도착 단계가 정해지는 순간 바뀝니다. 애니메이션이 끝날 때가 아닙니다.
    public private(set) var currentDetent: BottomSheetDetent

    /// 지금 멈출 수 있는 단계의 이름입니다. `nil`이면 레이아웃의 모든 단계입니다.
    ///
    /// 내용이 많아 낮은 단계에 넣을 수 없을 때 그 단계를 빼 둡니다. 현재 단계가
    /// 목록에서 빠지면 가장 가까운 허용 단계로 옮겨 갑니다. 멈춰 있을 때 바꾸면 `static`
    /// 콘텐츠의 아래쪽 안전 영역도 새 값에 맞춥니다.
    public var allowedDetents: Set<BottomSheetDetent.Identifier>? {
        didSet { self.applyAllowedDetents() }
    }

    /// 사용자가 시트를 끌고 있는지 나타냅니다.
    public private(set) var isDragging = false

    /// 시트가 따라가는 스크롤뷰입니다. `track(scrollView:)`로 정합니다.
    public private(set) weak var trackedScrollView: UIScrollView?

    /// 부모 안전 영역 위쪽 끝에서 시트 위쪽 끝까지의 현재 거리입니다.
    ///
    /// 손을 뗀 뒤 애니메이션이 도는 동안에는 이미 도착점 값입니다. 대리자의
    /// `didChangeDetent`는 애니메이션이 시작되기 직전에 오므로 그 안에서는 출발 위치입니다.
    /// 도착 위치가 필요하면 `offset(for:)`를 씁니다.
    public var currentOffset: CGFloat {
        return self.topConstraint?.constant ?? 0
    }

    /// 시트가 쓸 수 있는 안전 영역의 높이입니다.
    ///
    /// 부모의 안전 영역을 기준으로 합니다. 탭바 높이가 여기에 반영되어 있어
    /// 가장 낮은 단계에서도 손잡이가 탭바에 가리지 않습니다.
    ///
    /// `add(to:)` 전에는 0입니다. 붙인 뒤에도 부모가 창에 놓여 배치를 마치기 전에는
    /// 안전 영역이 반영되지 않은 값일 수 있습니다. 시트는 그 값으로 자리를 잡지 않고
    /// 배치가 끝난 뒤에 잡으므로, 이 값은 `didChangeDetent` 같은 콜백 안에서 읽는 것이 안전합니다.
    public var availableHeight: CGFloat {
        return self.hostView?.safeAreaLayoutGuide.layoutFrame.height ?? 0
    }

    private let surfaceView: BottomSheetSurfaceView
    private var backdropView: UIView?

    /// 부모 안전 영역에 붙어 있는 보이지 않는 View입니다. 부모 크기나 안전 영역이 바뀌어 이 View가
    /// 다시 배치되면 시트도 자리와 높이를 다시 계산합니다. `static` 모드에서는 시트 자신의 프레임이
    /// 바뀌지 않아 `viewDidLayoutSubviews`가 오지 않으므로 이 경로가 필요합니다.
    private var hostLayoutObserver: BottomSheetHostLayoutObserverView?

    /// 안전 영역 위쪽 끝에서 시트 위쪽 끝까지의 거리이며 이 값 하나로 위치를 정합니다.
    private var topConstraint: NSLayoutConstraint?

    /// `static` 모드에서 시트 높이를 고정하는 제약입니다. `fitToBounds`에서는 `nil`입니다.
    private var heightConstraint: NSLayoutConstraint?

    private lazy var panGesture = UIPanGestureRecognizer(
        target: self,
        action: #selector(self.handlePan(_:))
    )

    /// 끌기를 시작한 순간의 위치이며 이동 거리를 더할 기준입니다.
    private var dragStartOffset: CGFloat = 0

    /// 지금 손가락이 시트를 움직이는지, 콘텐츠를 스크롤하는지 나타냅니다.
    private var dragMode: DragMode = .sheet

    /// 끌기가 처음 닿은 자리입니다. 손가락이 닿는 순간 `gestureRecognizer(_:shouldReceive:)`에서 정하고
    /// 끌기가 끝날 때까지 씁니다.
    private var dragOrigin: BottomSheetDragOrigin = .content

    /// `dragOrigin`을 마지막으로 기록한 터치의 시각입니다. 같은 순간에 닿은 손가락을 구분하는 데 씁니다.
    private var dragOriginTimestamp: TimeInterval = -1

    /// 진행 중인 끌기가 시작될 때의 움직임 값입니다.
    ///
    /// 끄는 도중에 `behavior`가 바뀌어도 시트와 스크롤 사이의 판단(넘김, 스크롤 붙잡기)은 이 값으로 끝까지 합니다.
    /// 스크롤뷰의 팬이 이미 함께 인식되고 있어, 도중에 판단이 바뀌면 시트와 목록이 함께 움직입니다.
    private var dragRouting: BottomSheetBehavior = .default

    /// 진행 중인 단계 이동 애니메이션입니다.
    private var animator: UIViewPropertyAnimator?

    /// 화면에 처음 배치되어 올라오는 동작을 마쳤는지 나타냅니다.
    private var hasEnteredScreen = false

    private var contentOffsetObservation: NSKeyValueObservation?
    private var contentSizeObservation: NSKeyValueObservation?
    private var scrollIndicatorWasVisible = true

    /// 시트가 세로 스크롤 인디케이터를 숨겨 두었는지입니다. 숨긴 적이 있을 때만 원래 값으로 되돌립니다.
    private var isScrollIndicatorHiddenBySheet = false

    /// `.content` 단계를 위해 잰 콘텐츠 높이입니다. 손잡이는 포함하지 않습니다. 아직 재지 않았으면 `nil`입니다.
    private var measuredContentHeight: CGFloat?

    /// 시트가 콘텐츠 화면의 `additionalSafeAreaInsets.bottom`에 더해 둔 몫입니다. `fitToBounds`에서는 언제나 0입니다.
    private var appliedContentBottomInset: CGFloat = 0

    /// 시트가 처음 몫을 더하기 전 콘텐츠 화면의 `additionalSafeAreaInsets.bottom`입니다. `remove()`에서 되돌립니다.
    private var contentBottomInsetBase: CGFloat?

    /// 진행 중인 단계 이동이 콘텐츠 아래 여백도 함께 옮기는 구간입니다. 도중에 멈출 때 그려진 위치의 값을 구합니다.
    private var contentInsetTransition: ContentInsetTransition?

    private enum DragMode {
        case sheet
        case scroll
    }

    /// 단계 이동 애니메이션이 콘텐츠 아래 여백을 옮기는 구간입니다.
    private struct ContentInsetTransition {
        let fromOffset: CGFloat
        let toOffset: CGFloat
        let fromInset: CGFloat
        let toInset: CGFloat

        /// 시트와 콘텐츠 배치는 같은 곡선으로 움직이므로, 시트가 지난 비율만큼 여백도 옮겨 갔습니다.
        func inset(at offset: CGFloat) -> CGFloat {
            guard self.toOffset != self.fromOffset else { return self.toInset }

            let progress = (offset - self.fromOffset) / (self.toOffset - self.fromOffset)

            return max(self.fromInset + (self.toInset - self.fromInset) * progress, 0)
        }
    }



    // MARK: - Life Cycle

    /// 시트에 표시할 화면과 규칙을 주입받습니다.
    ///
    /// - Parameters:
    ///   - contentViewController: 시트 안에 표시할 화면입니다.
    ///   - layout: 멈출 단계의 목록입니다.
    ///   - initialDetent: 처음 멈출 단계의 이름입니다. 레이아웃에 없으면 첫 단계를 씁니다.
    ///   - appearance: 표시 속성입니다.
    ///   - behavior: 움직임 값입니다.
    ///   - contentMode: 콘텐츠 높이를 다루는 방식입니다. 기본은 끌 때 부드러운 `static`입니다.
    public init(
        contentViewController: UIViewController,
        layout: BottomSheetLayout = .standard,
        initialDetent: BottomSheetDetent.Identifier = .tip,
        appearance: BottomSheetAppearance = .default,
        behavior: BottomSheetBehavior = .default,
        contentMode: BottomSheetContentMode = .static
    ) {
        self.contentViewController = contentViewController
        self.layout = layout
        self.appearance = appearance
        self.behavior = behavior
        self.contentMode = contentMode
        self.currentDetent = layout.detent(for: initialDetent) ?? layout.detents[0]
        self.surfaceView = BottomSheetSurfaceView(appearance: appearance)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        self.view = self.surfaceView
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.embedContent()
        self.setGesture()
        self.setAccessibility()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.layoutIfPossible()
    }

    public override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)

        /// 콘텐츠 화면이 `preferredContentSize`를 바꾸면 `.content` 단계의 높이를 다시 잽니다.
        self.measureContentIfNeeded()
    }

    public override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()

        /// 탭바 높이는 화면이 올라온 뒤에 안전 영역에 반영됩니다. 그때 시트 자체의 프레임은
        /// 바뀌지 않아 배치가 다시 돌지 않으므로 여기서 자리를 다시 맞춥니다.
        self.layoutIfPossible()
    }



    // MARK: - Interface

    /// 부모 화면에 자식으로 붙입니다.
    ///
    /// 부모의 View에 직접 넣으므로 부모가 탭바 컨트롤러의 자식이면 시트도 탭바 뒤에 놓입니다.
    /// 이미 붙어 있으면 아무 일도 하지 않습니다.
    ///
    /// - Parameter parent: 이 시트를 소유할 화면입니다.
    public func add(to parent: UIViewController) {
        guard self.parent == nil, let host = parent.view else { return }

        parent.addChild(self)

        if let backdrop = self.appearance.backdrop {
            self.installBackdrop(backdrop, in: host)
        }

        self.installHostLayoutObserver(in: host)

        self.view.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(self.view)

        let topConstraint = self.view.topAnchor.constraint(
            equalTo: host.safeAreaLayoutGuide.topAnchor
        )
        self.topConstraint = topConstraint

        NSLayoutConstraint.activate([
            topConstraint,
            self.view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            self.view.trailingAnchor.constraint(equalTo: host.trailingAnchor)
        ])

        switch self.contentMode {
        case .static:
            /// 높이를 고정해 끄는 동안 콘텐츠가 다시 배치되지 않게 합니다. 값은 배치가 끝나 안전 영역을
            /// 알 수 있을 때 `updateStaticHeightIfNeeded()`가 채웁니다.
            let heightConstraint = self.view.heightAnchor.constraint(equalToConstant: 0)
            heightConstraint.isActive = true
            self.heightConstraint = heightConstraint

        case .fitToBounds:
            /// 배경이 탭바와 홈 인디케이터 뒤까지 이어져야 아래가 잘린 것처럼 보이지 않습니다.
            self.view.bottomAnchor.constraint(equalTo: host.bottomAnchor).isActive = true
        }

        self.didMove(toParent: parent)
    }

    /// 부모 화면에서 떼어 냅니다. 붙어 있지 않으면 아무 일도 하지 않습니다.
    public func remove() {
        guard self.parent != nil else { return }

        self.stopAnimation()
        self.track(scrollView: nil)
        self.removeContentBottomInset()

        self.willMove(toParent: nil)
        self.backdropView?.removeFromSuperview()
        self.backdropView = nil
        self.hostLayoutObserver?.removeFromSuperview()
        self.hostLayoutObserver = nil
        self.view.removeFromSuperview()
        self.topConstraint = nil
        self.heightConstraint = nil
        self.removeFromParent()

        self.hasEnteredScreen = false
        self.view.isHidden = true
    }

    /// 지정한 단계로 옮깁니다.
    ///
    /// 레이아웃에 없는 이름이면 무시합니다. 아직 화면에 붙기 전이면 기억해 두고
    /// 처음 나타날 때 그 단계에서 시작합니다.
    ///
    /// - Parameters:
    ///   - identifier: 옮겨 갈 단계의 이름입니다.
    ///   - animated: 애니메이션 여부입니다.
    public func move(to identifier: BottomSheetDetent.Identifier, animated: Bool) {
        guard let detent = self.resolvedLayout.detent(for: identifier) else { return }

        guard self.hasEnteredScreen else {
            self.updateDetent(detent)
            return
        }

        guard animated else {
            self.stopAnimation()
            self.updateDetent(detent)
            let target = self.offset(for: detent)
            self.setOffset(target)
            let insetChanged = self.applyContentBottomInset(restingAt: target)
            self.hostView?.layoutIfNeeded()

            if insetChanged {
                self.clampTrackedScrollToEnd()
            }

            self.notifyCoveredHeight(offset: target, animated: false)
            return
        }

        self.animate(to: detent, velocity: 0)
    }

    /// 콘텐츠 높이가 바뀌었다고 알립니다. `.content` 단계가 있을 때만 의미가 있습니다.
    ///
    /// `preferredContentSize`가 바뀌거나 따라가는 스크롤뷰의 `contentSize`가 바뀌면 자동으로 다시 잽니다.
    /// 그 밖의 방법으로 콘텐츠 높이가 바뀌었을 때(예: 스택에 카드를 더했을 때) 이 메서드를 불러 주면
    /// 다시 재서 `.content` 단계에 머물고 있으면 스프링으로 자리를 옮깁니다.
    ///
    /// - Complexity: 콘텐츠의 Auto Layout 압축 크기를 한 번 계산합니다.
    public func invalidateContentHeight() {
        self.measureContentIfNeeded()
    }

    /// 시트가 따라갈 스크롤뷰를 정합니다.
    ///
    /// 시트가 가장 높은 단계에 있지 않으면 스크롤 대신 시트가 움직이고, 가장 높은 단계에서
    /// 스크롤이 맨 위에 닿은 채로 아래로 끌면 다시 시트가 움직입니다. `behavior.scrollingExpandsSheet`가
    /// `false`면 위로 끌 때는 언제나 스크롤이 움직이고, 맨 위에서 아래로 끌 때만 시트로 넘어옵니다.
    /// `behavior.dragArea`가 `.handleAndBackground`이면 스크롤뷰는 시트와 묶이지 않고 `.content` 단계의 높이를 재는 데만
    /// 쓰입니다.
    /// `nil`을 넘기면 따라가기를 멈춥니다.
    ///
    /// - Parameter scrollView: 콘텐츠 화면 안의 세로 스크롤뷰입니다.
    public func track(scrollView: UIScrollView?) {
        self.restoreScrollIndicator()
        self.contentOffsetObservation = nil
        self.contentSizeObservation = nil
        self.trackedScrollView = scrollView

        guard let scrollView else { return }

        /// 행이 늘거나 줄면 `.content` 단계의 높이를 다시 잽니다.
        self.contentSizeObservation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.measureContentIfNeeded()
            }
        }

        /// KVO 알림은 `contentOffset`을 바꾼 스레드에서 오고, UIScrollView는 메인 스레드에서만
        /// 바뀝니다. 그래도 클로저 자체는 격리를 모르므로 메인 액터임을 확인하고 들어갑니다.
        self.contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.new]) {
            [weak self] scrollView, _ in
            MainActor.assumeIsolated {
                self?.pinScrollIfNeeded(scrollView)
            }
        }
    }

    /// 단계가 멈출 offset을 지금 화면 크기 기준으로 계산합니다.
    ///
    /// 대리자의 `didChangeDetent`에서 도착 위치에 맞춰 지도 여백 같은 값을 함께 움직일 때 씁니다.
    ///
    /// 완전히 내리는 단계는 안전 영역이 아니라 **창 바닥**에 시트 위쪽 끝을 맞춥니다.
    /// 안전 영역 끝에 세우면 탭바가 없는 화면에서 손잡이가 홈 인디케이터 옆에 남고,
    /// 부모 View 바닥에 세우면 불투명 탭바가 부모 View를 탭바 위까지로 줄인 경우
    /// 탭바의 반투명한 위 가장자리로 시트가 비쳐 보입니다.
    ///
    /// - Parameter detent: 위치를 구할 단계입니다.
    /// - Returns: 부모 안전 영역 위쪽 끝에서 시트 위쪽 끝까지의 거리입니다. `availableHeight`와
    ///   같은 시점 조건을 따르므로 배치가 끝난 뒤에 읽어야 정확합니다.
    public func offset(for detent: BottomSheetDetent) -> CGFloat {
        if detent.anchor == .hidden, let host = self.hostView {
            let safeTop = host.safeAreaLayoutGuide.layoutFrame.minY
            var bottom = host.bounds.maxY

            if let window = host.window {
                let windowBottomInHost = host.convert(window.bounds, from: window).maxY
                bottom = max(bottom, windowBottomInHost)
            }

            return bottom - safeTop
        }

        return self.resolvedLayout.offset(for: detent, availableHeight: self.availableHeight)
    }



    // MARK: - Private

    private var hostView: UIView? {
        return self.view.superview
    }

    /// 단계를 고를 때 쓰는 높이입니다. 화면에 붙기 전에는 안전 영역을 모르므로 임시값을 씁니다.
    private var referenceHeight: CGFloat {
        let height = self.availableHeight

        return height > 0 ? height : 1000
    }

    private var highestOffset: CGFloat {
        let detent = self.resolvedLayout.highestDetent(
            availableHeight: self.availableHeight,
            among: self.allowedDetents
        )

        return self.offset(for: detent)
    }

    private func setOffset(_ offset: CGFloat) {
        self.topConstraint?.constant = offset
        self.updateBackdrop(for: offset)
    }

    /// 시트가 가린 높이를 대리자에게 알립니다.
    private func notifyCoveredHeight(offset: CGFloat, animated: Bool) {
        let covered = max(self.availableHeight - offset, 0)

        self.delegate?.bottomSheet(self, didChangeCoveredHeight: covered, animated: animated)
    }

    /// 안전 영역 아래쪽 여백입니다. 탭바와 홈 인디케이터 높이입니다.
    private var bottomInset: CGFloat {
        guard let host = self.hostView else { return 0 }

        return max(host.bounds.maxY - host.safeAreaLayoutGuide.layoutFrame.maxY, 0)
    }

    /// `static` 모드의 시트 높이를 다시 계산합니다.
    ///
    /// 가장 높은 단계에서 보이는 높이에, 탭바 뒤까지 이어질 여백과 한계를 넘어 끌 때 바닥이 뜨지 않을
    /// 여유(`overDragLimit`)를 더합니다. 허용 목록이 아니라 레이아웃 전체의 가장 높은 단계를 쓰므로
    /// 허용 목록이 바뀌어도 콘텐츠 높이는 그대로입니다.
    private func updateStaticHeightIfNeeded() {
        guard let heightConstraint = self.heightConstraint, self.availableHeight > 0 else { return }

        let highest = self.resolvedLayout.offset(
            for: self.resolvedLayout.highestDetent(availableHeight: self.availableHeight),
            availableHeight: self.availableHeight
        )
        let height = max(self.availableHeight - highest, 0) + self.bottomInset + self.behavior.overDragLimit

        guard heightConstraint.constant != height else { return }

        heightConstraint.constant = height
    }

    private func installHostLayoutObserver(in host: UIView) {
        let observer = BottomSheetHostLayoutObserverView()
        observer.isHidden = true
        observer.isUserInteractionEnabled = false
        observer.translatesAutoresizingMaskIntoConstraints = false
        observer.onLayout = { [weak self] in
            self?.layoutIfPossible()
        }
        host.addSubview(observer)

        let guide = host.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            observer.topAnchor.constraint(equalTo: guide.topAnchor),
            observer.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            observer.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            observer.bottomAnchor.constraint(equalTo: guide.bottomAnchor)
        ])

        self.hostLayoutObserver = observer
    }

    private func embedContent() {
        self.addChild(self.contentViewController)

        guard let contentView = self.contentViewController.view else { return }

        contentView.translatesAutoresizingMaskIntoConstraints = false
        self.surfaceView.contentContainerView.addSubview(contentView)

        let container = self.surfaceView.contentContainerView
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: container.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        self.contentViewController.didMove(toParent: self)
    }

    private func setGesture() {
        /// 시트 전체에서 끌 수 있게 합니다(`behavior.dragArea`가 `.handleAndBackground`이면 손잡이 줄·빈 배경·끌기 손잡이에서만).
        /// 따라가는 스크롤뷰와는 동시에 인식해 손가락 하나로 시트와 스크롤을 이어서 움직입니다.
        self.panGesture.delegate = self
        self.view.addGestureRecognizer(self.panGesture)
    }

    private func setAccessibility() {
        self.surfaceView.handleView.accessibilityValue = self.currentDetent.identifier.rawValue

        self.surfaceView.handleView.onIncrement = { [weak self] in
            guard let self, let above = self.resolvedLayout.detent(
                above: self.currentDetent,
                availableHeight: self.referenceHeight,
                among: self.allowedDetents
            ) else { return }

            self.move(to: above.identifier, animated: true)
        }

        self.surfaceView.handleView.onDecrement = { [weak self] in
            guard let self, let below = self.resolvedLayout.detent(
                below: self.currentDetent,
                availableHeight: self.referenceHeight,
                among: self.allowedDetents
            ) else { return }

            self.move(to: below.identifier, animated: true)
        }
    }

    /// 배치가 끝나 안전 영역을 알 수 있을 때 자리를 잡습니다.
    ///
    /// 창에 붙기 전에도 배치가 한 번 돕니다. 그때는 안전 영역이 비어 있어 쓸 수 있는
    /// 높이가 화면 전체로 잡히므로 자리를 정하면 안 됩니다.
    private func layoutIfPossible() {
        guard self.view.window != nil, self.topConstraint != nil, self.availableHeight > 0 else { return }

        self.updateStaticHeightIfNeeded()

        /// 처음 자리를 잡기 전에 아래 여백부터 넣어, `.content` 단계를 처음 잴 때도 이후와 같은 안전 영역으로 잽니다.
        if self.hasEnteredScreen == false {
            self.applyContentBottomInset(restingAt: self.offset(for: self.currentDetent))
        }

        self.measureContentIfNeeded()

        guard self.hasEnteredScreen else {
            return self.enterScreen()
        }

        self.applyCurrentDetentIfNeeded()
        self.refreshContentBottomInsetIfResting()
    }

    /// 처음 배치할 때 화면 아래에서 올라오게 합니다.
    ///
    /// 자리를 먼저 잡아 두고 `transform`으로만 내렸다가 올립니다.
    /// 위치로 내리면 시트 위쪽 끝이 내려간 만큼 시트 높이가 줄어들어,
    /// 바닥 안전 영역이 손잡이보다 얕은 순간에 손잡이가 설 자리가 사라집니다.
    private func enterScreen() {
        self.hasEnteredScreen = true
        self.stopAnimation()

        let target = self.offset(for: self.currentDetent)
        self.topConstraint?.constant = target
        self.applyContentBottomInset(restingAt: target)
        self.hostView?.layoutIfNeeded()
        self.surfaceView.setShadowVisible(self.currentDetent.anchor != .hidden)
        self.notifyCoveredHeight(offset: target, animated: false)

        let shouldAnimate = self.behavior.animatesInitialAppearance
            && UIAccessibility.isReduceMotionEnabled == false

        guard shouldAnimate else {
            self.view.isHidden = false
            self.updateBackdrop(for: target)
            return
        }

        self.view.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
        self.view.isHidden = false
        self.backdropView?.alpha = 0

        let animator = UIViewPropertyAnimator(
            duration: self.behavior.animationDuration,
            timingParameters: UISpringTimingParameters(dampingRatio: self.behavior.springDampingRatio)
        )
        animator.addAnimations {
            self.view.transform = .identity
            self.updateBackdrop(for: target)
        }
        animator.startAnimation()
    }

    /// 화면 크기가 바뀌었을 때 현재 단계의 위치를 다시 맞춥니다.
    ///
    /// 끌고 있거나 움직이는 중에는 건드리지 않습니다. 사용자의 손과 다투게 됩니다.
    private func applyCurrentDetentIfNeeded() {
        guard self.isDragging == false, self.animator == nil else { return }

        let offset = self.offset(for: self.currentDetent)

        guard self.topConstraint?.constant != offset else { return }

        self.setOffset(offset)
    }

    /// 머무는 단계가 허용 목록을 벗어났으면 가장 가까운 허용 단계로 옮깁니다.
    private func applyAllowedDetents() {
        let candidates = self.resolvedLayout.detents(among: self.allowedDetents)

        guard candidates.contains(self.currentDetent) == false else {
            /// 머무는 단계는 그대로여도 허용된 가장 높은 단계가 바뀌면 이 단계에서 콘텐츠가 스크롤하는지가 바뀝니다.
            return self.refreshContentBottomInsetIfResting()
        }

        let target = self.resolvedLayout.nearestDetent(
            to: self.resolvedLayout.offset(for: self.currentDetent, availableHeight: self.referenceHeight),
            availableHeight: self.referenceHeight,
            among: self.allowedDetents
        )

        self.move(to: target.identifier, animated: self.hasEnteredScreen)
    }

    /// 레이아웃이 바뀌면 같은 이름의 단계를 찾고, 없으면 지금 위치에 가장 가까운 단계로 옮깁니다.
    private func applyLayoutChange() {
        let target = self.resolvedLayout.detent(for: self.currentDetent.identifier)
            ?? self.resolvedLayout.nearestDetent(
                to: self.currentOffset,
                availableHeight: self.referenceHeight,
                among: self.allowedDetents
            )

        /// 같은 이름이어도 높이 기준이 바뀌었을 수 있으므로 단계 값을 갈아 끼우고 자리를 다시 잡습니다.
        self.currentDetent = target
        self.surfaceView.handleView.accessibilityValue = target.identifier.rawValue
        self.updateStaticHeightIfNeeded()

        guard self.hasEnteredScreen else { return }

        self.animate(to: target, velocity: 0)
    }

    /// 단계가 바뀌었을 때만 기록하고 알립니다.
    private func updateDetent(_ detent: BottomSheetDetent) {
        guard self.currentDetent != detent else { return }

        self.currentDetent = detent
        self.surfaceView.setShadowVisible(detent.anchor != .hidden)
        self.surfaceView.handleView.accessibilityValue = detent.identifier.rawValue
        self.delegate?.bottomSheet(self, didChangeDetent: detent)
    }
}



// MARK: - Content Bottom Inset

extension BottomSheetController {

    /// `static`에서 시트가 이 위치에 멈췄을 때 콘텐츠의 아래쪽 안전 영역에 더할 몫입니다.
    ///
    /// UIKit은 시트 View가 부모 View 바닥 아래로 나간 부분을 안전 영역으로 세지 않고 부모의 아래쪽 안전 영역만 물려줍니다.
    /// 그래서 기준 위치에서 시트 바닥이 부모 View 바닥 아래로 나간 길이를 더하면 콘텐츠의 안전 영역 바닥이 부모 안전 영역
    /// 바닥에 옵니다. 레이아웃 전체의 가장 높은 단계에서는 `overDragLimit`입니다. 기준 위치는 `UIComponentsCore`의
    /// `contentBottomReferenceOffset`이 정합니다.
    ///
    /// - Parameter offset: 시트가 멈출 위치입니다.
    /// - Returns: 더할 몫입니다. `fitToBounds`이거나 아직 자리를 잡을 수 없으면 `nil`이고, 그때는 콘텐츠 화면의 값을 건드리지 않습니다.
    private func contentBottomInset(restingAt offset: CGFloat) -> CGFloat? {
        guard self.contentMode == .static,
              let host = self.hostView,
              let heightConstraint = self.heightConstraint,
              self.availableHeight > 0 else { return nil }

        let layout = self.resolvedLayout
        let reference: CGFloat

        if self.layout.hasContentSizedDetent {
            /// `.content` 단계를 잴 때 안전 영역이 섞이면 위치와 잰 높이가 서로를 바꿔 시트가 멈추지 않을 수 있어 고정합니다.
            reference = layout.offset(
                for: layout.highestDetent(availableHeight: self.availableHeight),
                availableHeight: self.availableHeight
            )
        } else {
            reference = layout.contentBottomReferenceOffset(
                restingAt: offset,
                availableHeight: self.availableHeight,
                handleHeight: self.handleHeight,
                among: self.allowedDetents,
                behavior: self.behavior
            )
        }

        let sheetBottom = host.safeAreaLayoutGuide.layoutFrame.minY + reference + heightConstraint.constant

        return max(sheetBottom - host.bounds.maxY, 0)
    }

    /// 콘텐츠 화면에 시트 몫을 씁니다. 앱이 정한 값 위에 더합니다.
    private func setContentBottomInset(_ inset: CGFloat) {
        let content = self.contentViewController
        let base = self.contentBottomInsetBase ?? content.additionalSafeAreaInsets.bottom

        self.contentBottomInsetBase = base
        self.appliedContentBottomInset = inset
        content.additionalSafeAreaInsets.bottom = base + inset
    }

    /// 콘텐츠의 아래쪽 안전 영역을 이 위치에 맞춥니다.
    ///
    /// - Returns: 값이 바뀌었으면 `true`입니다.
    @discardableResult
    private func applyContentBottomInset(restingAt offset: CGFloat) -> Bool {
        guard let inset = self.contentBottomInset(restingAt: offset),
              abs(inset - self.appliedContentBottomInset) > 0.01 || self.contentBottomInsetBase == nil else { return false }

        self.setContentBottomInset(inset)
        return true
    }

    /// 끌거나 움직이는 중이 아니면 지금 위치에 맞춰 다시 맞춥니다.
    private func refreshContentBottomInsetIfResting() {
        guard self.hasEnteredScreen, self.isDragging == false, self.animator == nil else { return }

        self.applyContentBottomInset(restingAt: self.currentOffset)
    }

    /// 시트가 더해 둔 몫을 거두고 앱의 값으로 되돌립니다.
    private func removeContentBottomInset() {
        guard let base = self.contentBottomInsetBase else { return }

        self.contentViewController.additionalSafeAreaInsets.bottom = base
        self.contentBottomInsetBase = nil
        self.appliedContentBottomInset = 0
    }
}



// MARK: - Content Sizing

extension BottomSheetController {

    /// `.content` 단계가 있으면 잰 콘텐츠 높이를 반영한 레이아웃입니다. 위치 계산은 모두 이것으로 합니다.
    private var resolvedLayout: BottomSheetLayout {
        guard self.layout.hasContentSizedDetent else { return self.layout }

        return self.layout.resolvingContentHeight(self.handleHeight + (self.measuredContentHeight ?? 0))
    }

    private var handleHeight: CGFloat {
        return self.appearance.showsGrabber ? self.appearance.handleAreaHeight : 0
    }

    /// 콘텐츠 높이를 다시 재고, 달라졌으면 시트 높이와 `.content` 단계의 자리를 다시 잡습니다.
    ///
    /// 처음 자리를 잡기 전에는 값만 기억해 두고, 자리를 잡은 뒤 `.content` 단계에 머물고 있으면
    /// 스프링으로 새 자리에 옮깁니다. 끌고 있는 동안은 건드리지 않습니다.
    private func measureContentIfNeeded() {
        guard self.layout.hasContentSizedDetent else { return }

        let containerWidth = self.surfaceView.contentContainerView.bounds.width
        let width = containerWidth > 0 ? containerWidth : (self.hostView?.bounds.width ?? 0)

        guard width > 0, let measured = self.measureContentHeight(fittingWidth: width) else { return }
        guard abs((self.measuredContentHeight ?? -1) - measured) > 0.5 else { return }

        self.measuredContentHeight = measured
        self.updateStaticHeightIfNeeded()

        guard self.hasEnteredScreen,
              self.isDragging == false,
              self.currentDetent.anchor.isContentSized else { return }

        let target = self.offset(for: self.currentDetent)

        guard abs(self.currentOffset - target) > 0.5 else { return }

        self.animate(to: self.currentDetent, velocity: 0)
    }

    /// 콘텐츠 높이를 잽니다. 손잡이는 포함하지 않습니다.
    ///
    /// 우선순위는 `preferredContentSize` → 스크롤뷰의 `contentSize` → Auto Layout 압축 크기입니다.
    /// 압축 크기는 콘텐츠 View 안의 제약이 위에서 아래로 이어져 있을 때 정확합니다. 잴 수 없으면 `nil`입니다.
    private func measureContentHeight(fittingWidth width: CGFloat) -> CGFloat? {
        let content = self.contentViewController

        if content.preferredContentSize.height > 0 {
            return content.preferredContentSize.height
        }

        if let scrollView = self.trackedScrollView ?? (content.viewIfLoaded as? UIScrollView) {
            let height = scrollView.contentSize.height + scrollView.contentInset.top + scrollView.contentInset.bottom

            return height > 0 ? height : nil
        }

        guard let view = content.viewIfLoaded else { return nil }

        let size = view.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        return size.height > 0 ? size.height : nil
    }
}



// MARK: - Backdrop

extension BottomSheetController {

    private func installBackdrop(_ backdrop: BottomSheetBackdrop, in host: UIView) {
        let backdropView = UIView()
        backdropView.backgroundColor = backdrop.color
        backdropView.alpha = 0
        backdropView.isUserInteractionEnabled = false
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(backdropView)

        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: host.topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])

        if backdrop.collapsesOnTap {
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleBackdropTap))
            backdropView.addGestureRecognizer(tap)
        }

        self.backdropView = backdropView
    }

    /// 위치에 따른 판의 투명도입니다.
    ///
    /// 가장 높은 단계에서 `maximumAlpha`, 어둡게 하지 않을 단계에서 0이 되도록 사이를 잇습니다.
    private func backdropAlpha(for offset: CGFloat) -> CGFloat {
        guard let backdrop = self.appearance.backdrop, self.availableHeight > 0 else { return 0 }

        let progress = self.resolvedLayout.backdropProgress(
            at: offset,
            availableHeight: self.availableHeight,
            largestUndimmedDetent: backdrop.largestUndimmedDetent
        )

        return backdrop.maximumAlpha * progress
    }

    private func updateBackdrop(for offset: CGFloat) {
        guard let backdropView = self.backdropView else { return }

        let alpha = self.backdropAlpha(for: offset)
        backdropView.alpha = alpha
        backdropView.isUserInteractionEnabled = alpha > 0.01
    }

    @objc
    private func handleBackdropTap() {
        let target: BottomSheetDetent

        if let identifier = self.appearance.backdrop?.largestUndimmedDetent,
           let detent = self.resolvedLayout.detent(for: identifier),
           self.resolvedLayout.detents(among: self.allowedDetents).contains(detent) {
            target = detent
        } else {
            target = self.resolvedLayout.lowestDetent(
                availableHeight: self.availableHeight,
                among: self.allowedDetents
            )
        }

        self.move(to: target.identifier, animated: true)
    }
}



// MARK: - Gesture

extension BottomSheetController: UIGestureRecognizerDelegate {

    /// 시트를 끄는 동안 따라 움직이고 손을 떼면 가까운 단계로 보냅니다.
    ///
    /// 따라가는 스크롤뷰가 있으면 손가락 하나가 시트와 스크롤을 번갈아 움직입니다.
    /// 시트가 가장 높은 단계보다 아래에 있으면 시트가, 가장 높은 단계에 닿은 뒤에는
    /// 스크롤이 움직입니다. 스크롤이 맨 위에 닿은 채로 아래로 끌면 다시 시트로 넘어옵니다.
    /// `behavior.dragArea`가 `.handleAndBackground`이면 손잡이 줄·빈 배경·끌기 손잡이에서 시작한 끌기만 오고, 스크롤과
    /// 오가지 않습니다.
    @objc
    private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let host = self.hostView else { return }

        let translation = gesture.translation(in: host).y
        let velocity = gesture.velocity(in: host).y

        switch gesture.state {
        case .began:
            self.stopAnimation()
            self.isDragging = true
            self.dragStartOffset = self.currentOffset
            self.dragRouting = self.behavior

            /// 출발지는 손가락이 닿는 순간 정해 둔 값을 씁니다. 지금 위치는 10pt쯤 움직인 뒤라 출발지가 아닙니다.
            let target = self.dragRouting.initialDragTarget(
                from: self.dragOrigin,
                offset: self.currentOffset,
                highestOffset: self.highestOffset,
                isScrollAtTop: self.trackedScrollView.map { self.isAtTop($0) } ?? true,
                isDraggingDown: velocity > 0
            )

            /// 시트가 받지 않는 끌기는 대리자에서 걸러져 오지 않습니다. 오더라도 아무것도 넘기지 않는 스크롤 모드로 둡니다.
            assert(target != .ignored, "시트가 받지 않는 끌기가 시작됐습니다.")
            self.dragMode = target == .sheet ? .sheet : .scroll

            /// 손가락이 스크롤뷰 위에서 시트를 움직일 때만 붙잡습니다. 손잡이를 끌 때 스크롤 위치를 건드리면 목록이 맨 위로 튀어요.
            if self.dragRouting.locksTrackedScroll(whileDragging: target, from: self.dragOrigin) {
                self.hideScrollIndicator()
                self.pinTrackedScrollToTop()
            }

            self.delegate?.bottomSheetWillBeginDragging(self)

        case .changed:
            switch self.dragMode {
            case .sheet:
                let proposed = self.dragStartOffset + translation
                let highest = self.highestOffset

                /// 가장 높은 단계를 지나 더 올리려는데 스크롤할 내용이 남아 있으면 스크롤로 넘깁니다.
                if proposed < highest,
                   self.dragRouting.sharesDragWithTrackedScroll(from: self.dragOrigin),
                   self.canHandOffToScroll {
                    self.setOffset(highest)

                    /// 시트가 허용된 가장 높은 단계에 섰으니 콘텐츠 아래 여백도 그 위치에 맞춥니다. 기본 설정에서는 값이 같아
                    /// 아무 일도 없습니다.
                    self.applyContentBottomInset(restingAt: highest)
                    self.dragMode = .scroll
                    self.dragStartOffset = highest
                    gesture.setTranslation(.zero, in: host)
                    self.restoreScrollIndicator()
                    self.delegate?.bottomSheet(self, didMoveTo: highest)
                    self.notifyCoveredHeight(offset: highest, animated: false)
                    return
                }

                let resisted = self.resolvedLayout.resistedOffset(
                    proposed,
                    availableHeight: self.availableHeight,
                    among: self.allowedDetents,
                    behavior: self.behavior
                )
                self.setOffset(resisted)
                self.delegate?.bottomSheet(self, didMoveTo: resisted)
                self.notifyCoveredHeight(offset: resisted, animated: false)

            case .scroll:
                /// 스크롤이 맨 위에 닿은 채로 아래로 끌면 시트가 이어서 내려옵니다.
                guard self.dragRouting.sharesDragWithTrackedScroll(from: self.dragOrigin),
                      let scrollView = self.trackedScrollView,
                      self.isAtTop(scrollView),
                      velocity > 0 else { return }

                self.dragMode = .sheet
                self.dragStartOffset = self.currentOffset
                gesture.setTranslation(.zero, in: host)
                self.hideScrollIndicator()
                self.pinTrackedScrollToTop()
            }

        case .ended, .cancelled, .failed:
            self.isDragging = false
            self.restoreScrollIndicator()

            guard self.dragMode == .sheet else { return }

            var target = self.resolvedLayout.targetDetent(
                releasedAt: self.currentOffset,
                velocity: velocity,
                availableHeight: self.availableHeight,
                among: self.allowedDetents,
                behavior: self.behavior
            )

            var identifier = target.identifier
            self.delegate?.bottomSheet(self, willEndDraggingWithVelocity: velocity, targetDetent: &identifier)

            if identifier != target.identifier, let overridden = self.resolvedLayout.detent(for: identifier) {
                target = overridden
            }

            self.animate(to: target, velocity: velocity)

        default:
            break
        }
    }

    /// 손가락이 처음 닿은 View로 끌기의 출발지를 정합니다.
    ///
    /// UIKit이 고른 View(`UITouch.view`)를 기준으로 삼아 숨김·상호작용 끔·겹침 순서를 그대로 따릅니다. 닿은 View에서
    /// 시트까지 올라가며 처음 만나는 손잡이, 끌기 손잡이(`isBottomSheetDragHandle`), 따라가는 스크롤뷰가 출발지를 정합니다.
    /// 끌기 손잡이 안에서 터치를 받아 쓰는 View(컨트롤, 스크롤뷰, 켜진 제스처 인식기)를 지나 왔으면 콘텐츠입니다.
    /// 셋 다 없으면 그 길에 터치를 받아 쓰는 View가 있을 때 콘텐츠, 없을 때 빈 배경입니다. 콘텐츠 화면의 루트 View와 콘텐츠 자리에 붙은 제스처 인식기는 보지 않습니다. 다른 바텀시트 안의 터치와
    /// 시트 밖 View는 콘텐츠로 봅니다. View를 모르면 위치로 판단합니다.
    ///
    /// - Parameters:
    ///   - hitView: 손가락이 처음 닿은 View입니다.
    ///   - location: 시트 View 좌표계에서 손가락이 닿은 위치입니다.
    /// - Returns: 끌기의 출발지입니다.
    /// - Complexity: O(d·g)입니다. d는 닿은 View에서 시트까지의 깊이, g는 View마다 달린 제스처 인식기 수입니다.
    func classifyDragOrigin(hitView: UIView?, location: CGPoint) -> BottomSheetDragOrigin {
        guard let hitView else {
            let handleView = self.surfaceView.handleView

            if handleView.bounds.height > 0, handleView.frame.contains(location) {
                return .handle
            }

            if let scrollView = self.trackedScrollView,
               scrollView.point(inside: self.view.convert(location, to: scrollView), with: nil) {
                return .trackedScrollView
            }

            return .content
        }

        var marker: BottomSheetDragOrigin?
        var receivesTouches = false
        var current: UIView? = hitView

        while let view = current, view !== self.view {
            /// 다른 바텀시트 안의 터치는 그 시트가 판단합니다.
            if view is BottomSheetSurfaceView {
                return .content
            }

            if marker == nil {
                if view === self.surfaceView.handleView {
                    marker = .handle
                } else if view.isBottomSheetDragHandle {
                    /// 지정한 View 안의 버튼·스크롤뷰·제스처 View는 자기 터치를 지킵니다. SwiftUI 수정자와 같습니다.
                    marker = receivesTouches ? .content : .handle
                } else if let scrollView = self.trackedScrollView, view === scrollView {
                    marker = .trackedScrollView
                } else if receivesTouches == false {
                    receivesTouches = self.receivesTouches(view)
                }
            }

            current = view.superview
        }

        /// 시트 밖 View면 판단할 근거가 없어 시트가 받지 않는 콘텐츠로 봅니다.
        guard current === self.view else { return .content }

        return marker ?? (receivesTouches ? .content : .background)
    }

    /// 터치를 직접 받아 쓰는 View인지 나타냅니다.
    ///
    /// 콘텐츠 자리와 콘텐츠 화면의 루트 View는 시트 배경으로 봅니다. 키보드 내리기 탭이나 내비게이션 컨트롤러의 뒤로 가기
    /// 제스처처럼 화면 전체에 붙인 인식기 하나 때문에 빈 배경 전체가 사라지지 않게 합니다. 루트 자체가 컨트롤이나
    /// 스크롤뷰면 콘텐츠입니다.
    ///
    /// SwiftUI가 그리는 View(`UIHostingController`의 View)는 안쪽의 글자·버튼·스크롤뷰가 모두 그 View 하나로 hit-test되어
    /// UIKit이 빈 곳을 가릴 수 없습니다. 빈 배경으로 보면 SwiftUI 스크롤과 시트 끌기가 경쟁하므로 콘텐츠로 봅니다.
    private func receivesTouches(_ view: UIView) -> Bool {
        if view is UIControl || view is UIScrollView || Self.isSwiftUIHostingView(view) {
            return true
        }

        if view === self.surfaceView.contentContainerView || view === self.contentViewController.viewIfLoaded {
            return false
        }

        return view.gestureRecognizers?.contains(where: { $0.isEnabled }) ?? false
    }

    /// SwiftUI가 그리는 호스팅 View인지 나타냅니다.
    ///
    /// UIKitExtension은 SwiftUI를 import하지 않아 타입으로 가릴 수 없으므로 클래스 이름으로 봅니다. 이름이 바뀌어 찾지
    /// 못하면 빈 배경으로 보던 예전 판정으로 돌아갑니다.
    private static func isSwiftUIHostingView(_ view: UIView) -> Bool {
        return NSStringFromClass(type(of: view)).contains("UIHostingView")
    }

    /// 손가락이 닿는 순간 끌기의 출발지를 정하고, 시트가 받을 터치인지 판단합니다.
    ///
    /// `gestureRecognizerShouldBegin(_:)`은 손가락이 10pt쯤 움직인 뒤에 불려 그 위치가 출발지가 아닙니다.
    /// 출발지는 여기서 정해 두고 끌기가 끝날 때까지 씁니다. 끌기가 시작되기 전에 출발지가 다른 손가락이 더해지면
    /// `BottomSheetDragOrigin.merging(_:)`으로 합칩니다. `behavior.dragArea`가 `.handleAndBackground`이면 손잡이 줄,
    /// 끌기 손잡이, 빈 배경 밖의 터치를 받지 않아 콘텐츠의 스크롤·셀 선택·스와이프와 경쟁하지 않습니다.
    ///
    /// - Complexity: O(d·g)입니다. d는 터치를 받은 View에서 시트까지의 깊이, g는 View마다 달린 제스처 인식기 수입니다.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === self.panGesture else { return true }

        let origin = self.classifyDragOrigin(hitView: touch.view, location: touch.location(in: self.view))
        let accepts = self.behavior.acceptsDrag(from: origin)

        /// 끌기가 시작되기 전에 닿은 손가락만 출발지에 반영합니다. 시작된 뒤에 닿은 손가락은 받을지만 판단합니다.
        if accepts, self.panGesture.state == .possible {
            /// 같은 순간에 닿은 손가락들은 아직 `numberOfTouches`에 잡히지 않아 터치 시각으로 구분합니다.
            let isFirstTouch = self.panGesture.numberOfTouches == 0 && touch.timestamp != self.dragOriginTimestamp

            self.dragOrigin = isFirstTouch ? origin : self.dragOrigin.merging(origin)
            self.dragOriginTimestamp = touch.timestamp
        }

        return accepts
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === self.panGesture else { return true }

        /// 손가락이 닿은 뒤 시작하기 전에 `behavior`가 바뀌었을 수 있어 한 번 더 확인합니다.
        guard self.behavior.acceptsDrag(from: self.dragOrigin) else { return false }

        /// 가로로 끄는 동작은 콘텐츠 안의 가로 스크롤이나 스와이프에 맡깁니다.
        let velocity = self.panGesture.velocity(in: self.view)

        return abs(velocity.y) >= abs(velocity.x)
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === self.panGesture,
              self.behavior.sharesDragWithTrackedScroll(from: self.dragOrigin),
              let scrollView = self.trackedScrollView else { return false }

        return otherGestureRecognizer === scrollView.panGestureRecognizer
    }
}



// MARK: - Scroll Tracking

extension BottomSheetController {

    /// 스크롤이 움직여야 할 때가 아니면 맨 위에 붙잡아 둡니다.
    ///
    /// 손가락이 스크롤뷰 위에서 시트를 움직이는 동안, 그리고 스크롤이 시트를 올리는 모드에서 시트가 가장 높은
    /// 단계 아래에 있을 때는 스크롤이 움직이면 안 됩니다. `behavior.dragArea`가 `.handleAndBackground`이면 붙잡지 않습니다.
    /// 판단은 `UIComponentsCore`의 끌기 규칙을 따릅니다. `contentOffset`을 매번 되돌려 놓아
    /// 스크롤뷰의 제스처를 끊지 않고도 제자리에 세웁니다. `isScrollEnabled`를 끄면 진행 중인 터치가 취소됩니다.
    private func pinScrollIfNeeded(_ scrollView: UIScrollView) {
        guard self.shouldPinScroll else { return }

        let top = self.topContentOffset(of: scrollView)

        guard scrollView.contentOffset.y > top.y || scrollView.contentOffset.y < top.y else { return }

        scrollView.contentOffset = top
    }

    private var shouldPinScroll: Bool {
        guard self.trackedScrollView != nil else { return false }

        if self.isDragging {
            return self.dragRouting.locksTrackedScroll(
                whileDragging: self.dragMode == .sheet ? .sheet : .scroll,
                from: self.dragOrigin
            )
        }

        return self.behavior.locksTrackedScrollWhileIdle(
            offset: self.currentOffset,
            highestOffset: self.highestOffset
        )
    }

    private func pinTrackedScrollToTop() {
        guard let scrollView = self.trackedScrollView else { return }

        scrollView.contentOffset = self.topContentOffset(of: scrollView)
    }

    private func topContentOffset(of scrollView: UIScrollView) -> CGPoint {
        return CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top)
    }

    private func isAtTop(_ scrollView: UIScrollView) -> Bool {
        return scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + 0.5
    }

    /// 스크롤뷰가 지금 손가락을 따라가고 있고 아래로 더 보여 줄 내용이 있는지 확인합니다.
    private var canHandOffToScroll: Bool {
        guard let scrollView = self.trackedScrollView else { return false }

        let isTracking = scrollView.panGestureRecognizer.state == .began
            || scrollView.panGestureRecognizer.state == .changed

        /// 시트가 가장 높은 단계에 서면 아래 여백이 바뀔 수 있어 그 위치에서의 스크롤 끝으로 판단합니다.
        let maxY = self.maxContentOffsetY(of: scrollView, restingAt: self.highestOffset)

        return isTracking && maxY > -scrollView.adjustedContentInset.top + 0.5
    }

    /// 따라가는 스크롤의 끝(`contentOffset.y` 최댓값)입니다. 위치를 넘기면 시트가 그 위치에 멈춘 뒤의 끝을 미리 계산합니다.
    private func maxContentOffsetY(of scrollView: UIScrollView, restingAt offset: CGFloat? = nil) -> CGFloat {
        let inset = scrollView.adjustedContentInset
        var bottom = inset.bottom

        /// 아래 여백 가운데 안전 영역에서 온 몫만 시트 몫을 따라 바뀝니다. `.never`처럼 안전 영역을 반영하지 않으면 그대로입니다.
        let fromSafeArea = max(inset.bottom - scrollView.contentInset.bottom, 0)

        if let offset, fromSafeArea > 0, let target = self.contentBottomInset(restingAt: offset) {
            bottom += max(target - self.appliedContentBottomInset, -fromSafeArea)
        }

        return max(scrollView.contentSize.height + bottom - scrollView.bounds.height, -inset.top)
    }

    /// 아래 여백이 줄어 따라가는 스크롤이 끝을 넘었으면 끝으로 당깁니다.
    ///
    /// 애니메이션 블록 안에서 부르면 시트가 올라가는 만큼 목록이 함께 내려와 마지막 줄이 보이는 바닥에 붙어 있습니다.
    /// 손가락이 스크롤하거나 감속 중이면 스크롤뷰가 스스로 되튀므로 건드리지 않습니다.
    private func clampTrackedScrollToEnd() {
        guard let scrollView = self.trackedScrollView,
              scrollView.isTracking == false,
              scrollView.isDecelerating == false else { return }

        let maxY = self.maxContentOffsetY(of: scrollView)

        guard scrollView.contentOffset.y > maxY + 0.5 else { return }

        scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: maxY)
    }

    /// 시트가 스크롤을 붙잡는 동안 세로 스크롤 인디케이터를 숨깁니다. 이미 숨겼으면 원래 값을 덮어쓰지 않습니다.
    private func hideScrollIndicator() {
        guard let scrollView = self.trackedScrollView,
              self.isScrollIndicatorHiddenBySheet == false else { return }

        self.scrollIndicatorWasVisible = scrollView.showsVerticalScrollIndicator
        self.isScrollIndicatorHiddenBySheet = true
        scrollView.showsVerticalScrollIndicator = false
    }

    /// 시트가 숨긴 인디케이터만 원래 값으로 되돌립니다. 앱이 직접 끈 인디케이터는 건드리지 않습니다.
    private func restoreScrollIndicator() {
        guard self.isScrollIndicatorHiddenBySheet else { return }

        self.isScrollIndicatorHiddenBySheet = false
        self.trackedScrollView?.showsVerticalScrollIndicator = self.scrollIndicatorWasVisible
    }
}



// MARK: - Host Layout Observer

/// 부모 안전 영역을 따라 배치되는 빈 View입니다. 배치가 돌 때마다 시트에 알립니다.
@MainActor
final class BottomSheetHostLayoutObserverView: UIView {

    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()

        self.onLayout?()
    }
}



// MARK: - Animation

extension BottomSheetController {

    /// 스프링 초기 속도(이동 거리 대비 배율)의 한도입니다.
    private static let maximumInitialVelocity: CGFloat = 8

    /// 지정한 단계로 스프링 애니메이션을 실행합니다.
    ///
    /// 손을 뗀 속도를 이어받아 움직임이 끊기지 않게 합니다. 동작 줄이기가 켜져 있으면
    /// 스프링 대신 완만한 곡선으로 옮깁니다.
    private func animate(to detent: BottomSheetDetent, velocity: CGFloat) {
        guard let host = self.hostView else { return }

        self.stopAnimation()
        self.updateDetent(detent)

        let start = self.currentOffset
        let target = self.offset(for: detent)
        let distance = target - start
        let startInset = self.appliedContentBottomInset
        let targetInset = self.contentBottomInset(restingAt: target)
        let changesInset = targetInset.map { abs($0 - startInset) > 0.01 } ?? false

        /// 스프링의 초기 속도는 이동 거리로 나눈 값이어야 합니다. 속도를 그대로 넣으면 거리가 짧을 때
        /// 크게 튕깁니다. 거리가 아주 짧으면 나눈 값이 수십이 되어 되레 튀므로 한도를 둡니다.
        let normalized = distance == 0 ? 0 : velocity / distance
        let initialVelocity = min(max(normalized, -Self.maximumInitialVelocity), Self.maximumInitialVelocity)

        let timing: UITimingCurveProvider = UIAccessibility.isReduceMotionEnabled
            ? UICubicTimingParameters(animationCurve: .easeInOut)
            : UISpringTimingParameters(
                dampingRatio: self.behavior.springDampingRatio,
                initialVelocity: CGVector(dx: 0, dy: initialVelocity)
            )

        let animator = UIViewPropertyAnimator(
            duration: self.behavior.animationDuration,
            timingParameters: timing
        )

        animator.addAnimations {
            self.setOffset(target)

            /// 블록 안에서 바꿔야 콘텐츠 배치가 시트와 같은 곡선으로 움직이고, 아래에 붙인 View가 보이는 바닥으로 미끄러져 갑니다.
            if changesInset, let targetInset {
                self.setContentBottomInset(targetInset)
            }

            host.layoutIfNeeded()

            /// 여백이 줄면 끝까지 내린 목록을 새 끝으로 당겨 마지막 줄이 보이는 바닥에 붙은 채 함께 움직이게 합니다.
            if changesInset {
                self.clampTrackedScrollToEnd()
            }
        }
        animator.addCompletion { [weak self, weak animator] _ in
            /// 멈춘 애니메이션의 완료가 새 애니메이션의 상태를 지우지 않게 자기 자신일 때만 정리합니다.
            guard let self, let animator, self.animator === animator else { return }

            self.animator = nil
            self.contentInsetTransition = nil

            /// 움직이는 동안 안전 영역이 바뀌었을 수 있어 자리를 다시 맞춥니다.
            self.view.setNeedsLayout()
        }

        self.contentInsetTransition = changesInset ? targetInset.map {
            ContentInsetTransition(fromOffset: start, toOffset: target, fromInset: startInset, toInset: $0)
        } : nil
        self.animator = animator
        animator.startAnimation()

        /// 애니메이터가 시작된 뒤에 알립니다. 시작 전에 알리면 대리자가 건 애니메이션이 바로 이어지는
        /// `layoutIfNeeded()`에 끊길 수 있어요. MapKit의 `setCenter(animated:)`가 중간에 멈추는 것을 봤어요.
        self.notifyCoveredHeight(offset: target, animated: true)
    }

    /// 진행 중인 애니메이션을 멈추고 지금 보이는 위치를 그대로 이어받습니다.
    ///
    /// 제약의 값은 애니메이션이 시작될 때 이미 도착점으로 바뀝니다.
    /// 그대로 멈추면 시트가 도착점으로 튀므로 화면에 그려진 위치를 읽어 되돌려 놓습니다.
    private func stopAnimation() {
        guard let animator = self.animator else { return }

        let presentedMinY = self.view.layer.presentation()?.frame.minY
        let transition = self.contentInsetTransition

        /// 아래 여백과 함께 끝으로 당기던 목록이면 그려진 스크롤 위치도 이어받습니다.
        let presentedScrollY = transition == nil ? nil : self.trackedScrollView?.layer.presentation()?.bounds.minY

        animator.stopAnimation(true)
        self.animator = nil
        self.contentInsetTransition = nil

        guard let presentedMinY, let host = self.hostView else { return }

        let offset = presentedMinY - host.safeAreaLayoutGuide.layoutFrame.minY
        self.setOffset(offset)

        /// 제약처럼 안전 영역도 이미 도착값이라, 그대로 두면 다음 배치에서 아래에 붙인 View와 목록이 도착 자리로 튑니다.
        if let transition {
            self.setContentBottomInset(transition.inset(at: offset))
        }

        host.layoutIfNeeded()

        if let presentedScrollY, let scrollView = self.trackedScrollView {
            scrollView.contentOffset = CGPoint(
                x: scrollView.contentOffset.x,
                y: min(presentedScrollY, self.maxContentOffsetY(of: scrollView))
            )
        }
    }
}
#endif
