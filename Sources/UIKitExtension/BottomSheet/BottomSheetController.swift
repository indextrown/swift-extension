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
/// 움직이고 다 올라간 뒤에야 스크롤이 시작됩니다.
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
    public let contentViewController: UIViewController

    /// 시트가 멈출 단계의 목록입니다. 바꾸면 같은 이름의 단계로 자리를 다시 잡습니다.
    public var layout: BottomSheetLayout {
        didSet { self.applyLayoutChange() }
    }

    /// 시트의 표시 속성입니다.
    public let appearance: BottomSheetAppearance

    /// 시트가 손을 따라오고 단계 사이를 옮기는 방식입니다.
    public let behavior: BottomSheetBehavior

    /// 시트의 움직임을 받는 대리자입니다.
    public weak var delegate: BottomSheetControllerDelegate?

    /// 시트가 현재 머무는 단계입니다.
    ///
    /// 손을 뗀 뒤 도착 단계가 정해지는 순간 바뀝니다. 애니메이션이 끝날 때가 아닙니다.
    public private(set) var currentDetent: BottomSheetDetent

    /// 지금 멈출 수 있는 단계의 이름입니다. `nil`이면 레이아웃의 모든 단계입니다.
    ///
    /// 내용이 많아 낮은 단계에 넣을 수 없을 때 그 단계를 빼 둡니다. 현재 단계가
    /// 목록에서 빠지면 가장 가까운 허용 단계로 옮겨 갑니다.
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

    /// 안전 영역 위쪽 끝에서 시트 위쪽 끝까지의 거리이며 이 값 하나로 위치를 정합니다.
    private var topConstraint: NSLayoutConstraint?

    private lazy var panGesture = UIPanGestureRecognizer(
        target: self,
        action: #selector(self.handlePan(_:))
    )

    /// 끌기를 시작한 순간의 위치이며 이동 거리를 더할 기준입니다.
    private var dragStartOffset: CGFloat = 0

    /// 지금 손가락이 시트를 움직이는지, 콘텐츠를 스크롤하는지 나타냅니다.
    private var dragMode: DragMode = .sheet

    /// 진행 중인 단계 이동 애니메이션입니다.
    private var animator: UIViewPropertyAnimator?

    /// 화면에 처음 배치되어 올라오는 동작을 마쳤는지 나타냅니다.
    private var hasEnteredScreen = false

    private var contentOffsetObservation: NSKeyValueObservation?
    private var scrollIndicatorWasVisible = true

    private enum DragMode {
        case sheet
        case scroll
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
    public init(
        contentViewController: UIViewController,
        layout: BottomSheetLayout = .standard,
        initialDetent: BottomSheetDetent.Identifier = .tip,
        appearance: BottomSheetAppearance = .default,
        behavior: BottomSheetBehavior = .default
    ) {
        self.contentViewController = contentViewController
        self.layout = layout
        self.appearance = appearance
        self.behavior = behavior
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

        self.view.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(self.view)

        let topConstraint = self.view.topAnchor.constraint(
            equalTo: host.safeAreaLayoutGuide.topAnchor
        )
        self.topConstraint = topConstraint

        NSLayoutConstraint.activate([
            topConstraint,
            self.view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            self.view.trailingAnchor.constraint(equalTo: host.trailingAnchor),

            /// 배경이 탭바와 홈 인디케이터 뒤까지 이어져야 아래가 잘린 것처럼 보이지 않습니다.
            self.view.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])

        self.didMove(toParent: parent)
    }

    /// 부모 화면에서 떼어 냅니다. 붙어 있지 않으면 아무 일도 하지 않습니다.
    public func remove() {
        guard self.parent != nil else { return }

        self.stopAnimation()
        self.track(scrollView: nil)

        self.willMove(toParent: nil)
        self.backdropView?.removeFromSuperview()
        self.backdropView = nil
        self.view.removeFromSuperview()
        self.topConstraint = nil
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
        guard let detent = self.layout.detent(for: identifier) else { return }

        guard self.hasEnteredScreen else {
            self.updateDetent(detent)
            return
        }

        guard animated else {
            self.stopAnimation()
            self.updateDetent(detent)
            self.setOffset(self.offset(for: detent))
            self.hostView?.layoutIfNeeded()
            return
        }

        self.animate(to: detent, velocity: 0)
    }

    /// 시트가 따라갈 스크롤뷰를 정합니다.
    ///
    /// 시트가 가장 높은 단계에 있지 않으면 스크롤 대신 시트가 움직이고, 가장 높은 단계에서
    /// 스크롤이 맨 위에 닿은 채로 아래로 끌면 다시 시트가 움직입니다. `nil`을 넘기면
    /// 따라가기를 멈춥니다.
    ///
    /// - Parameter scrollView: 콘텐츠 화면 안의 세로 스크롤뷰입니다.
    public func track(scrollView: UIScrollView?) {
        self.restoreScrollIndicator()
        self.contentOffsetObservation = nil
        self.trackedScrollView = scrollView

        guard let scrollView else { return }

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

        return self.layout.offset(for: detent, availableHeight: self.availableHeight)
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
        let detent = self.layout.highestDetent(
            availableHeight: self.availableHeight,
            among: self.allowedDetents
        )

        return self.offset(for: detent)
    }

    private func setOffset(_ offset: CGFloat) {
        self.topConstraint?.constant = offset
        self.updateBackdrop(for: offset)
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
        /// 시트 전체에서 끌 수 있게 합니다. 따라가는 스크롤뷰와는 동시에 인식해 손가락 하나로
        /// 시트와 스크롤을 이어서 움직입니다.
        self.panGesture.delegate = self
        self.view.addGestureRecognizer(self.panGesture)
    }

    private func setAccessibility() {
        self.surfaceView.handleView.accessibilityValue = self.currentDetent.identifier.rawValue

        self.surfaceView.handleView.onIncrement = { [weak self] in
            guard let self, let above = self.layout.detent(
                above: self.currentDetent,
                availableHeight: self.referenceHeight,
                among: self.allowedDetents
            ) else { return }

            self.move(to: above.identifier, animated: true)
        }

        self.surfaceView.handleView.onDecrement = { [weak self] in
            guard let self, let below = self.layout.detent(
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

        guard self.hasEnteredScreen else {
            return self.enterScreen()
        }

        self.applyCurrentDetentIfNeeded()
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
        self.hostView?.layoutIfNeeded()
        self.surfaceView.setShadowVisible(self.currentDetent.anchor != .hidden)

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
        let candidates = self.layout.detents(among: self.allowedDetents)

        guard candidates.contains(self.currentDetent) == false else { return }

        let target = self.layout.nearestDetent(
            to: self.layout.offset(for: self.currentDetent, availableHeight: self.referenceHeight),
            availableHeight: self.referenceHeight,
            among: self.allowedDetents
        )

        self.move(to: target.identifier, animated: self.hasEnteredScreen)
    }

    /// 레이아웃이 바뀌면 같은 이름의 단계를 찾고, 없으면 지금 위치에 가장 가까운 단계로 옮깁니다.
    private func applyLayoutChange() {
        let target = self.layout.detent(for: self.currentDetent.identifier)
            ?? self.layout.nearestDetent(
                to: self.currentOffset,
                availableHeight: self.referenceHeight,
                among: self.allowedDetents
            )

        /// 같은 이름이어도 높이 기준이 바뀌었을 수 있으므로 단계 값을 갈아 끼우고 자리를 다시 잡습니다.
        self.currentDetent = target
        self.surfaceView.handleView.accessibilityValue = target.identifier.rawValue

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

        let progress = self.layout.backdropProgress(
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
           let detent = self.layout.detent(for: identifier),
           self.layout.detents(among: self.allowedDetents).contains(detent) {
            target = detent
        } else {
            target = self.layout.lowestDetent(
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
            self.dragMode = self.initialDragMode(velocity: velocity)

            if self.dragMode == .sheet {
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
                if proposed < highest, self.canHandOffToScroll {
                    self.setOffset(highest)
                    self.dragMode = .scroll
                    self.dragStartOffset = highest
                    gesture.setTranslation(.zero, in: host)
                    self.restoreScrollIndicator()
                    self.delegate?.bottomSheet(self, didMoveTo: highest)
                    return
                }

                let resisted = self.layout.resistedOffset(
                    proposed,
                    availableHeight: self.availableHeight,
                    among: self.allowedDetents,
                    behavior: self.behavior
                )
                self.setOffset(resisted)
                self.delegate?.bottomSheet(self, didMoveTo: resisted)

            case .scroll:
                /// 스크롤이 맨 위에 닿은 채로 아래로 끌면 시트가 이어서 내려옵니다.
                guard let scrollView = self.trackedScrollView,
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

            var target = self.layout.targetDetent(
                releasedAt: self.currentOffset,
                velocity: velocity,
                availableHeight: self.availableHeight,
                among: self.allowedDetents,
                behavior: self.behavior
            )

            var identifier = target.identifier
            self.delegate?.bottomSheet(self, willEndDraggingWithVelocity: velocity, targetDetent: &identifier)

            if identifier != target.identifier, let overridden = self.layout.detent(for: identifier) {
                target = overridden
            }

            self.animate(to: target, velocity: velocity)

        default:
            break
        }
    }

    /// 끌기가 시작될 때 시트와 스크롤 중 무엇이 움직일지 정합니다.
    private func initialDragMode(velocity: CGFloat) -> DragMode {
        guard let scrollView = self.trackedScrollView else { return .sheet }

        /// 가장 높은 단계 아래에 있으면 언제나 시트가 움직입니다.
        guard self.currentOffset <= self.highestOffset + 0.5 else { return .sheet }

        /// 맨 위에서 아래로 끌면 시트가, 그 밖에는 스크롤이 움직입니다.
        if self.isAtTop(scrollView) {
            return velocity > 0 ? .sheet : .scroll
        }

        return .scroll
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === self.panGesture else { return true }

        /// 가로로 끄는 동작은 콘텐츠 안의 가로 스크롤이나 스와이프에 맡깁니다.
        let velocity = self.panGesture.velocity(in: self.view)

        return abs(velocity.y) >= abs(velocity.x)
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === self.panGesture,
              let scrollView = self.trackedScrollView else { return false }

        return otherGestureRecognizer === scrollView.panGestureRecognizer
    }
}



// MARK: - Scroll Tracking

extension BottomSheetController {

    /// 스크롤이 움직여야 할 때가 아니면 맨 위에 붙잡아 둡니다.
    ///
    /// 시트가 가장 높은 단계 아래에 있거나 손가락이 시트를 움직이는 동안은 스크롤이
    /// 움직이면 안 됩니다. `contentOffset`을 매번 되돌려 놓아 스크롤뷰의 제스처를 끊지
    /// 않고도 제자리에 세웁니다. `isScrollEnabled`를 끄면 진행 중인 터치가 취소됩니다.
    private func pinScrollIfNeeded(_ scrollView: UIScrollView) {
        guard self.shouldPinScroll else { return }

        let top = self.topContentOffset(of: scrollView)

        guard scrollView.contentOffset.y > top.y || scrollView.contentOffset.y < top.y else { return }

        scrollView.contentOffset = top
    }

    private var shouldPinScroll: Bool {
        guard self.trackedScrollView != nil else { return false }

        if self.isDragging {
            return self.dragMode == .sheet
        }

        return self.currentOffset > self.highestOffset + 0.5
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

        let contentHeight = scrollView.contentSize.height
            + scrollView.adjustedContentInset.top
            + scrollView.adjustedContentInset.bottom

        return isTracking && contentHeight > scrollView.bounds.height + 0.5
    }

    private func hideScrollIndicator() {
        guard let scrollView = self.trackedScrollView else { return }

        self.scrollIndicatorWasVisible = scrollView.showsVerticalScrollIndicator
        scrollView.showsVerticalScrollIndicator = false
    }

    private func restoreScrollIndicator() {
        guard let scrollView = self.trackedScrollView,
              scrollView.showsVerticalScrollIndicator != self.scrollIndicatorWasVisible else { return }

        scrollView.showsVerticalScrollIndicator = self.scrollIndicatorWasVisible
    }
}



// MARK: - Animation

extension BottomSheetController {

    /// 지정한 단계로 스프링 애니메이션을 실행합니다.
    ///
    /// 손을 뗀 속도를 이어받아 움직임이 끊기지 않게 합니다. 동작 줄이기가 켜져 있으면
    /// 스프링 대신 완만한 곡선으로 옮깁니다.
    private func animate(to detent: BottomSheetDetent, velocity: CGFloat) {
        guard let host = self.hostView else { return }

        self.stopAnimation()
        self.updateDetent(detent)

        let target = self.offset(for: detent)
        let distance = target - self.currentOffset

        /// 스프링의 초기 속도는 이동 거리로 나눈 값이어야 합니다.
        /// 속도를 그대로 넣으면 거리가 짧을 때 크게 튕깁니다.
        let initialVelocity = distance == 0 ? 0 : velocity / distance

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
            host.layoutIfNeeded()
        }
        animator.addCompletion { [weak self] _ in
            self?.animator = nil

            /// 움직이는 동안 안전 영역이 바뀌었을 수 있어 자리를 다시 맞춥니다.
            self?.view.setNeedsLayout()
        }

        self.animator = animator
        animator.startAnimation()
    }

    /// 진행 중인 애니메이션을 멈추고 지금 보이는 위치를 그대로 이어받습니다.
    ///
    /// 제약의 값은 애니메이션이 시작될 때 이미 도착점으로 바뀝니다.
    /// 그대로 멈추면 시트가 도착점으로 튀므로 화면에 그려진 위치를 읽어 되돌려 놓습니다.
    private func stopAnimation() {
        guard let animator = self.animator else { return }

        let presentedMinY = self.view.layer.presentation()?.frame.minY

        animator.stopAnimation(true)
        self.animator = nil

        guard let presentedMinY, let host = self.hostView else { return }

        self.setOffset(presentedMinY - host.safeAreaLayoutGuide.layoutFrame.minY)
        host.layoutIfNeeded()
    }
}
#endif
