//
//  BottomSheetModifier.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

#if !os(tvOS)
import SwiftUI
import UIComponentsCore

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
extension View {

    /// 이 View 위에 탭바 뒤에서 올라오는 바텀시트를 얹습니다.
    ///
    /// 시트는 이 View의 영역 안에 놓입니다. `TabView`의 탭 콘텐츠에 붙이면 시트가 탭바 뒤에
    /// 놓이고 탭바는 그대로 눌립니다. 시트는 `layout`에 등록된 단계에서만 멈추고, 손을 뗀
    /// 위치와 속도로 가장 가까운 단계를 골라 스프링으로 옮깁니다.
    ///
    /// 콘텐츠에 스크롤이 필요하면 두 방법이 있습니다. 시트와 스크롤을 이어 움직이려면
    /// `ScrollView` 대신 `BottomSheetScrollView`를 씁니다. 시트가 다 올라가기 전에는 스크롤이 잠기고
    /// 시트가 움직이며, 다 올라간 뒤 맨 위에서 아래로 끌면 다시 시트로 넘어옵니다. 스크롤이 시트를
    /// 올리지 않게 하려면 `behavior`의 `scrollingExpandsSheet`를 `false`로 둡니다.
    /// 일반 `ScrollView`·`List`를 그대로 쓰거나 스크롤뷰가 여러 개면 `behavior`의 `dragArea`를 `.handleAndBackground`로
    /// 둡니다. 손잡이 줄과 콘텐츠의 빈 곳으로만 시트가 움직이고 콘텐츠는 스크롤만 합니다. 그러지 않으면 스크롤할 때
    /// 시트가 함께 끌립니다. 제목줄도 끌리게 하려면 제목줄에 `bottomSheetDragHandle(_:)`을 붙입니다.
    ///
    /// ```swift
    /// @State private var detent: BottomSheetDetent.Identifier = .tip
    ///
    /// MapView()
    ///     .bottomSheet(detent: $detent, layout: .standard) {
    ///         BottomSheetScrollView { PlaceList() }
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - detent: 시트가 머무는 단계입니다. 값을 바꾸면 시트가 그 단계로 움직이고, 사용자가
    ///     끌어 옮기면 값이 바뀝니다.
    ///   - layout: 멈출 단계의 목록입니다.
    ///   - allowedDetents: 지금 멈출 수 있는 단계의 이름입니다. `nil`이면 전부입니다.
    ///   - style: 표시 속성입니다.
    ///   - behavior: 손을 따라오고 단계 사이를 옮기는 방식입니다.
    ///   - willEndDragging: 사용자가 손을 뗀 직후, 도착 단계가 계산된 뒤 불립니다. 손을 뗀 속도(pt/s, 아래가 양수)와
    ///     계산된 단계 이름을 받아 실제로 갈 단계 이름을 돌려줍니다. 받은 이름을 그대로 돌려주면 계산대로 갑니다.
    ///     레이아웃에 없는 이름을 돌려주면 무시합니다. 끌기가 `onEnded` 없이 끊겨 정리될 때도 속도 0으로 불립니다.
    ///     UIKit 대리자의 `bottomSheet(_:willEndDraggingWithVelocity:targetDetent:)`와 같습니다.
    ///   - onOffsetChange: 시트 위치(부모 안전 영역 위쪽 끝에서 시트 위쪽 끝까지의 거리)를 전달합니다.
    ///     시트가 움직이는 매 프레임 불립니다. 사용자가 끄는 동안은 손가락 위치를, 손을 뗀 뒤나 `detent`를
    ///     바꿔 옮기는 동안은 애니메이션이 지나는 중간 위치를 그대로 전달합니다. 받은 값을 `@State`에
    ///     넣기만 하면 그 값에 묶인 View가 시트와 같은 프레임에 움직여요. 애니메이션 블록으로 감싸지
    ///     않아도 되고, `Map`처럼 UIKit이 그리는 View의 안전 영역에 묶어도 튀지 않습니다.
    ///   - content: 시트 안에 표시할 내용입니다.
    ///
    /// 이 View 안에서는 환경값 `bottomSheetCoveredHeight`로 시트가 가린 높이를 읽을 수 있고,
    /// `bottomSheetInset()`과 `bottomSheetDock(alignment:content:)`가 그 값을 써서 지도 여백과 떠 있는
    /// 버튼을 시트에 맞춰 줘요.
    public func bottomSheet<Content: View>(
        detent: Binding<BottomSheetDetent.Identifier>,
        layout: BottomSheetLayout = .standard,
        allowedDetents: Set<BottomSheetDetent.Identifier>? = nil,
        style: BottomSheetStyle = .default,
        behavior: BottomSheetBehavior = .default,
        willEndDragging: ((CGFloat, BottomSheetDetent.Identifier) -> BottomSheetDetent.Identifier)? = nil,
        onOffsetChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        return BottomSheetHost(
            base: self,
            detent: detent,
            layout: layout,
            allowedDetents: allowedDetents,
            style: style,
            behavior: behavior,
            willEndDragging: willEndDragging,
            onOffsetChange: onOffsetChange,
            content: content()
        )
    }
}



// MARK: - Host

/// 기본 View 위에 시트를 얹고, 시트가 가린 높이를 기본 View의 환경으로 내려 주는 View입니다.
///
/// 시트의 위치 상태는 `BottomSheetOverlay`가 갖고, 이 View는 그중 "가린 높이" 하나만 받아
/// `bottomSheetCoveredHeight` 환경값으로 기본 View에 넣어요. 그래서 기본 View 안의 `bottomSheetInset()`과
/// `bottomSheetDock`가 시트 상태에 접근하지 않고도 시트를 따라갈 수 있습니다.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct BottomSheetHost<Base: View, Content: View>: View {

    let base: Base

    @Binding var detent: BottomSheetDetent.Identifier

    let layout: BottomSheetLayout
    let allowedDetents: Set<BottomSheetDetent.Identifier>?
    let style: BottomSheetStyle
    let behavior: BottomSheetBehavior
    let willEndDragging: ((CGFloat, BottomSheetDetent.Identifier) -> BottomSheetDetent.Identifier)?
    let onOffsetChange: ((CGFloat) -> Void)?
    let content: Content

    /// 시트가 가린 높이입니다. 오버레이가 프레임마다 채워 줘요.
    @State private var coveredHeight: CGFloat = 0

    var body: some View {
        self.base
            .environment(\.bottomSheetCoveredHeight, self.coveredHeight)
            .environment(\.bottomSheetDetent, self.detent)
            .overlay {
                BottomSheetOverlay(
                    detent: self.$detent,
                    layout: self.layout,
                    allowedDetents: self.allowedDetents,
                    style: self.style,
                    behavior: self.behavior,
                    willEndDragging: self.willEndDragging,
                    onOffsetChange: self.onOffsetChange,
                    onCoveredHeightChange: { self.coveredHeight = $0 },
                    content: self.content
                )
            }
    }
}



// MARK: - Overlay

/// 시트를 실제로 그리고 움직이는 View입니다. `bottomSheet(...)`가 부모 위에 얹습니다.
///
/// 모든 위치는 `offset`이며, 부모 안전 영역 위쪽 끝에서 시트 위쪽 끝까지의 거리입니다.
/// 값이 클수록 시트가 아래에 있습니다. UIKit의 `BottomSheetController`와 같은 규칙입니다.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct BottomSheetOverlay<Content: View>: View {

    // MARK: - Property

    @Binding var detent: BottomSheetDetent.Identifier

    let layout: BottomSheetLayout
    let allowedDetents: Set<BottomSheetDetent.Identifier>?
    let style: BottomSheetStyle
    let behavior: BottomSheetBehavior
    let willEndDragging: ((CGFloat, BottomSheetDetent.Identifier) -> BottomSheetDetent.Identifier)?
    let onOffsetChange: ((CGFloat) -> Void)?

    /// 시트가 가린 높이를 `BottomSheetHost`에 알립니다. 환경값 `bottomSheetCoveredHeight`의 원천이에요.
    let onCoveredHeightChange: (CGFloat) -> Void

    let content: Content

    /// 부모 안전 영역 위쪽 끝에서 시트 위쪽 끝까지의 거리입니다. 이 값 하나로 위치를 정합니다.
    @State private var offset: CGFloat = 0

    /// 부모의 크기와 안전 영역입니다. `GeometryReader`가 재는 값을 손잡이·제스처 코드가 쓸 수 있게 담아 둡니다.
    @State private var metrics = Metrics()

    /// 처음 나타나는 애니메이션을 마쳤는지 나타냅니다.
    @State private var hasEntered = false

    /// 진행 중인 끌기입니다. 없으면 `nil`입니다.
    @State private var drag: DragState?

    /// `BottomSheetScrollView`가 올려 보내는 스크롤 상태입니다.
    @State private var scrollState = BottomSheetScrollStateKey.defaultValue

    /// 손가락이 `BottomSheetScrollView` 위에서 시트를 움직이는 동안 스크롤을 잠근 상태인지 나타냅니다.
    @State private var isScrollLockedByDrag = false

    /// 손잡이·배경·콘텐츠 제스처가 진행 중인지 나타냅니다. `onEnded` 없이 끊긴 끌기를 알아채는 데 씁니다.
    @GestureState private var isGrabberDragActive = false

    @GestureState private var isBackgroundDragActive = false

    @GestureState private var isContentDragActive = false

    /// 콘텐츠 View가 스스로 차지하는 높이입니다. `.content` 단계에 씁니다. 손잡이는 포함하지 않습니다.
    @State private var measuredContentHeight: CGFloat?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Metrics: Equatable {
        /// 시트가 쓸 수 있는 안전 영역의 높이입니다.
        var available: CGFloat = 0

        /// 안전 영역 아래쪽 여백입니다. 탭바와 홈 인디케이터 높이입니다.
        var bottomInset: CGFloat = 0
    }

    private struct DragState {
        /// 이 끌기를 잡은 제스처와 손가락이 처음 닿은 화면 위치입니다. 이 제스처의 변화와 끝만 받습니다.
        var claim: BottomSheetDragClaim

        /// 끌기를 시작한 순간의 위치이며 이동 거리를 더할 기준입니다.
        var startOffset: CGFloat

        /// 이동 거리를 재는 기준이 되는 translation입니다. 스크롤에서 넘어올 때 다시 잡습니다.
        var baseline: CGFloat

        /// 끌기를 시작한 자리입니다. 손잡이·배경인지, 콘텐츠라면 `BottomSheetScrollView`가 있었는지 담습니다.
        var origin: BottomSheetDragOrigin

        /// 손가락이 시트를 움직이는지(`true`), 콘텐츠를 스크롤하는지(`false`) 나타냅니다.
        var isSheet: Bool

        /// 가로로 끄는 동작이라 시트가 받지 않는지 나타냅니다.
        var isHorizontal: Bool
    }



    // MARK: - Body

    var body: some View {
        /// 리더는 안전 영역을 존중하게 둡니다. 그래야 `size`가 시트가 쓸 수 있는 높이이고
        /// `safeAreaInsets.bottom`이 탭바 높이입니다. 리더에 `ignoresSafeArea`를 걸면 인셋이 0으로 보고됩니다.
        GeometryReader { proxy in
            let measured = Metrics(
                available: proxy.size.height,
                bottomInset: proxy.safeAreaInsets.bottom
            )

            ZStack(alignment: .top) {
                self.backdrop
                    .ignoresSafeArea()

                /// 겉면은 안전 영역 바닥을 지나 탭바 뒤까지 넘치게 그립니다. 부모가 잘라 내지 않으므로 그대로 보입니다.
                self.surface
                    .frame(height: max(measured.available - self.offset, 0) + measured.bottomInset, alignment: .top)
                    .offset(y: self.offset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            /// 자리를 잡기 전(offset 0)은 알리지 않습니다. 알리면 바깥이 "시트가 화면을 다 가렸다"로 한 프레임 그려요.
            .modifier(BottomSheetOffsetReporter(offset: self.offset, isActive: self.hasEntered))
            .onAppear {
                self.metrics = measured
                self.enterIfPossible()
            }
            .onChange(of: measured) { _, newValue in
                self.metrics = newValue
                self.applyCurrentDetentIfNeeded()

                /// 회전처럼 높이만 바뀌고 위치는 그대로면 위치 알림이 오지 않아, 가린 높이를 여기서 다시 알립니다.
                if self.hasEntered {
                    self.onCoveredHeightChange(max(newValue.available - self.offset, 0))
                }
            }
        }
        .onChange(of: self.detent) { _, newValue in
            self.moveIfNeeded(to: newValue)
        }
        .onChange(of: self.allowedDetents) { _, _ in
            self.applyAllowedDetents()
        }
        .onChange(of: self.layout) { _, _ in
            /// 단계 정의가 바뀌면(예: `.content(padding:)`의 여백) 같은 이름의 단계 자리로 옮겨 갑니다. UIKit의 `layout` didSet과 같아요.
            self.applyAllowedDetents()
            self.applyCurrentDetentIfNeeded(animated: true)
        }
        .onPreferenceChange(BottomSheetScrollStateKey.self) { newValue in
            self.scrollState = newValue
        }
        .onPreferenceChange(BottomSheetReportedOffsetKey.self) { newValue in
            guard let newValue else { return }

            self.onOffsetChange?(newValue)
            self.onCoveredHeightChange(max(self.metrics.available - newValue, 0))
        }
        .onPreferenceChange(BottomSheetContentHeightKey.self) { newValue in
            self.measuredContentHeight = newValue
        }
        .onChange(of: self.contentHeightForLayout) { _, _ in
            /// 콘텐츠 높이가 바뀌면 `.content` 단계에 머무는 시트가 새 높이로 옮겨 갑니다.
            self.applyCurrentDetentIfNeeded(animated: true)
        }
        .onChange(of: self.isGrabberDragActive) { _, isActive in
            guard isActive == false else { return }

            self.settleAbandonedDrag(source: .grabber)
        }
        .onChange(of: self.isBackgroundDragActive) { _, isActive in
            guard isActive == false else { return }

            self.settleAbandonedDrag(source: .background)
        }
        .onChange(of: self.isContentDragActive) { _, isActive in
            guard isActive == false else { return }

            self.settleAbandonedDrag(source: .content)
        }
        .onChange(of: self.behavior.dragArea) { _, newDragArea in
            /// 새 값이 지금 끌기의 출발지를 받지 않으면 그 제스처가 마스크로 꺼져 `onEnded` 없이 사라질 수 있어 정리합니다.
            var behavior = self.behavior
            behavior.dragArea = newDragArea

            guard let state = self.drag, behavior.acceptsDrag(from: state.origin) == false else { return }

            self.settleAbandonedDrag(source: state.claim.source)
        }
    }



    // MARK: - Subviews

    private var shape: UnevenRoundedRectangle {
        return UnevenRoundedRectangle(
            topLeadingRadius: self.style.cornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: self.style.cornerRadius,
            style: .continuous
        )
    }

    private var surface: some View {
        ZStack(alignment: .top) {
            /// 그림자는 클립 밖에 있어야 잘리지 않으므로 배경을 콘텐츠와 분리합니다.
            self.shape
                .fill(self.style.background)
                .shadow(
                    color: self.isHidden ? .clear : self.style.shadowColor,
                    radius: self.style.shadowRadius,
                    y: self.style.shadowY
                )
                /// 콘텐츠가 받지 않는 빈 곳에서 시작한 끌기를 받습니다. 배경이 투명해도 잡히도록 모양으로 판정합니다.
                .contentShape(self.shape)
                .gesture(
                    self.dragGesture(source: .background, isActive: self.$isBackgroundDragActive),
                    including: self.behavior.backgroundDragGestureMask
                )

            VStack(spacing: 0) {
                if self.style.showsGrabber {
                    self.handle
                }

                self.content
                    /// 콘텐츠 안의 `bottomSheetDragHandle(_:)`이 끌기를 넘길 통로입니다.
                    .environment(\.bottomSheetDragSink, self.dragSink)
                    /// 콘텐츠가 스스로 차지하는 높이를 잽니다. 늘리는 `frame` 안쪽에 붙여야 콘텐츠 본래 크기가 잡혀요.
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(key: BottomSheetContentHeightKey.self, value: proxy.size.height)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    /// 시트 바닥은 탭바 뒤까지 이어지므로 콘텐츠는 그만큼 위에서 끝나야 가리지 않습니다.
                    .padding(.bottom, self.metrics.bottomInset)
                    .scrollDisabled(self.isScrollDisabled)
                    /// 콘텐츠로 시트를 끌지 않으면 이 제스처만 끄고 안쪽 제스처(List 스크롤, 가로 스와이프, 버튼)는 살려 둡니다.
                    .simultaneousGesture(
                        self.dragGesture(source: .content, isActive: self.$isContentDragActive),
                        including: self.behavior.contentDragGestureMask
                    )
            }
            .clipShape(self.shape)
        }
    }

    private var handle: some View {
        Capsule()
            .fill(self.style.grabberColor)
            .frame(width: self.style.grabberSize.width, height: self.style.grabberSize.height)
            .frame(maxWidth: .infinity)
            .frame(height: self.style.handleAreaHeight)
            .contentShape(Rectangle())
            .gesture(
                self.dragGesture(source: .grabber, isActive: self.$isGrabberDragActive),
                including: self.behavior.handleDragGestureMask
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(self.style.handleAccessibilityLabel)
            .accessibilityValue(self.detent.rawValue)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    self.step(up: true)

                case .decrement:
                    self.step(up: false)

                @unknown default:
                    break
                }
            }
    }

    @ViewBuilder
    private var backdrop: some View {
        if let backdrop = self.style.backdrop, self.metrics.available > 0 {
            let progress = self.resolvedLayout.backdropProgress(
                at: self.offset,
                availableHeight: self.metrics.available,
                largestUndimmedDetent: backdrop.largestUndimmedDetent
            )

            backdrop.color
                .opacity(backdrop.maximumOpacity * progress)
                .allowsHitTesting(progress > 0.01)
                .onTapGesture {
                    guard backdrop.collapsesOnTap else { return }

                    self.collapse(using: backdrop)
                }
        }
    }



    // MARK: - Geometry

    private var currentDetent: BottomSheetDetent {
        return self.resolvedLayout.detent(for: self.detent) ?? self.resolvedLayout.detents[0]
    }

    /// `.content` 단계에 쓸 콘텐츠 높이입니다. `BottomSheetScrollView`가 있으면 그 안쪽 콘텐츠 높이를,
    /// 없으면 콘텐츠 View가 스스로 차지한 높이를 씁니다. 스크롤뷰는 늘 주어진 높이를 다 채워 직접 재면 안 돼요.
    private var contentHeightForLayout: CGFloat? {
        if self.scrollState.isPresent {
            return self.scrollState.contentHeight > 0 ? self.scrollState.contentHeight : nil
        }

        return self.measuredContentHeight
    }

    /// `.content` 단계가 있으면 잰 콘텐츠 높이를 반영한 레이아웃입니다. 위치 계산은 모두 이것으로 합니다.
    private var resolvedLayout: BottomSheetLayout {
        guard self.layout.hasContentSizedDetent else { return self.layout }

        let handle = self.style.showsGrabber ? self.style.handleAreaHeight : 0

        return self.layout.resolvingContentHeight(handle + (self.contentHeightForLayout ?? 0))
    }

    /// 단계를 고를 때 쓰는 높이입니다. 크기를 재기 전에는 임시값을 씁니다.
    private var referenceHeight: CGFloat {
        return self.metrics.available > 0 ? self.metrics.available : 1000
    }

    /// 단계의 offset입니다. 완전히 내리는 단계는 안전 영역 아래쪽 여백까지 지나 화면 밖으로 나갑니다.
    private func targetOffset(for detent: BottomSheetDetent) -> CGFloat {
        if detent.anchor == .hidden {
            return self.metrics.available + self.metrics.bottomInset
        }

        return self.resolvedLayout.offset(for: detent, availableHeight: self.metrics.available)
    }

    private var highestOffset: CGFloat {
        let detent = self.resolvedLayout.highestDetent(
            availableHeight: self.metrics.available,
            among: self.allowedDetents
        )

        return self.targetOffset(for: detent)
    }

    private var isHidden: Bool {
        return self.currentDetent.anchor == .hidden && self.drag == nil
    }

    /// 손가락이 `BottomSheetScrollView` 위에서 시트를 움직이는 동안, 그리고 끌지 않을 때 끌기 규칙이
    /// 붙잡으라고 할 때 콘텐츠 스크롤을 잠급니다. `dragArea`가 `.handleAndBackground`이면 잠그지 않습니다. 잠그면
    /// 콘텐츠로 시트를 올릴 수 없어 목록이 움직이지 않습니다.
    ///
    /// UIKit은 끄는 동안과 끌지 않을 때를 나눠 판단하지만, 여기서는 둘을 합칩니다. `scrollDisabled`는 위치를
    /// 되돌리지 않고 멈추기만 하므로 두 규칙이 겹쳐도 목록이 튀지 않습니다.
    private var isScrollDisabled: Bool {
        guard self.scrollState.isPresent else { return false }

        return self.isScrollLockedByDrag
            || self.behavior.locksTrackedScrollWhileIdle(offset: self.offset, highestOffset: self.highestOffset)
    }



    // MARK: - Movement

    /// 처음 크기를 알게 되면 자리를 잡고 아래에서 올라옵니다.
    private func enterIfPossible() {
        guard self.hasEntered == false, self.metrics.available > 0 else { return }

        self.hasEntered = true
        self.applyAllowedDetents()

        let target = self.targetOffset(for: self.currentDetent)

        guard self.behavior.animatesInitialAppearance, self.reduceMotion == false else {
            self.offset = target
            return
        }

        self.offset = self.metrics.available + self.metrics.bottomInset

        withAnimation(self.animation(velocity: 0, distance: 0)) {
            self.offset = target
        }
    }

    /// 크기나 콘텐츠 높이가 바뀌었을 때 현재 단계의 위치를 다시 맞춥니다. 끌고 있는 동안은 건드리지 않습니다.
    private func applyCurrentDetentIfNeeded(animated: Bool = false) {
        guard self.hasEntered else { return self.enterIfPossible() }
        guard self.drag == nil else { return }

        let target = self.targetOffset(for: self.currentDetent)

        guard abs(self.offset - target) > 0.5 else { return }

        guard animated else {
            self.offset = target
            return
        }

        withAnimation(self.animation(velocity: 0, distance: target - self.offset)) {
            self.offset = target
        }
    }

    /// 바인딩이 바뀌면 그 단계로 옮깁니다. 이미 그 자리면 아무 일도 하지 않습니다.
    private func moveIfNeeded(to identifier: BottomSheetDetent.Identifier) {
        guard self.hasEntered, let detent = self.resolvedLayout.detent(for: identifier) else { return }

        let target = self.targetOffset(for: detent)

        guard abs(self.offset - target) > 0.5 else { return }

        withAnimation(self.animation(velocity: 0, distance: target - self.offset)) {
            self.offset = target
        }
    }

    /// 머무는 단계가 허용 목록을 벗어났으면 가장 가까운 허용 단계로 옮깁니다.
    private func applyAllowedDetents() {
        let candidates = self.resolvedLayout.detents(among: self.allowedDetents)

        guard candidates.contains(self.currentDetent) == false else { return }

        let target = self.resolvedLayout.nearestDetent(
            to: self.resolvedLayout.offset(for: self.currentDetent, availableHeight: self.referenceHeight),
            availableHeight: self.referenceHeight,
            among: self.allowedDetents
        )

        withAnimation(self.animation(velocity: 0, distance: 0)) {
            self.detent = target.identifier
        }
    }

    private func step(up: Bool) {
        let next = up
            ? self.resolvedLayout.detent(above: self.currentDetent, availableHeight: self.referenceHeight, among: self.allowedDetents)
            : self.resolvedLayout.detent(below: self.currentDetent, availableHeight: self.referenceHeight, among: self.allowedDetents)

        guard let next else { return }

        withAnimation(self.animation(velocity: 0, distance: 0)) {
            self.detent = next.identifier
        }
    }

    private func collapse(using backdrop: BottomSheetBackdropStyle) {
        let target: BottomSheetDetent.Identifier

        if let identifier = backdrop.largestUndimmedDetent,
           let detent = self.resolvedLayout.detent(for: identifier),
           self.resolvedLayout.detents(among: self.allowedDetents).contains(detent) {
            target = identifier
        } else {
            target = self.resolvedLayout.lowestDetent(
                availableHeight: self.referenceHeight,
                among: self.allowedDetents
            ).identifier
        }

        withAnimation(self.animation(velocity: 0, distance: 0)) {
            self.detent = target
        }
    }

    /// 단계 사이를 옮기는 애니메이션입니다. 손을 뗀 속도를 이어받고, 동작 줄이기가 켜져 있으면 스프링을 생략합니다.
    private func animation(velocity: CGFloat, distance: CGFloat) -> Animation {
        if self.reduceMotion {
            return .easeInOut(duration: self.behavior.animationDuration)
        }

        /// 스프링의 초기 속도는 이동 거리로 나눈 값이어야 합니다. 속도를 그대로 넣으면 거리가 짧을 때 크게 튕깁니다.
        let initialVelocity = distance == 0 ? 0 : Double(velocity / distance)

        return .interpolatingSpring(
            duration: self.behavior.animationDuration,
            bounce: Double(min(max(1 - self.behavior.springDampingRatio, 0), 1)),
            initialVelocity: initialVelocity
        )
    }



    // MARK: - Gesture

    /// 콘텐츠 안의 `bottomSheetDragHandle(_:)`이 끌기를 넘기는 통로입니다.
    private var dragSink: BottomSheetDragSink {
        return BottomSheetDragSink(
            acceptsDrag: self.behavior.acceptsDrag(from: .handle),
            changed: { value, id in
                self.dragChanged(value, source: .designated(id))
            },
            ended: { value, id in
                self.dragEnded(value, source: .designated(id))
            },
            abandoned: { id in
                self.settleAbandonedDrag(source: .designated(id))
            }
        )
    }

    private func dragGesture(source: BottomSheetDragSource, isActive: GestureState<Bool>) -> some Gesture {
        /// 좌표계는 반드시 화면(`.global`) 기준이어야 합니다. 제스처가 붙은 View 자신(`.local`)을 기준으로 재면
        /// 시트가 손가락을 따라 움직인 만큼 translation이 줄어들어 손가락의 절반만 따라옵니다. 지정한 View의 제스처도
        /// 같은 설정을 써야 같은 손가락의 끌기를 넘겨받을 때 시트가 튀지 않습니다.
        return DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating(isActive) { _, isActive, _ in
                isActive = true
            }
            .onChanged { value in
                self.dragChanged(value, source: source)
            }
            .onEnded { value in
                self.dragEnded(value, source: source)
            }
    }

    /// 시트를 끄는 동안 따라 움직입니다.
    ///
    /// 무엇을 움직일지는 `UIComponentsCore`의 끌기 규칙을 따릅니다. 손잡이 줄, 빈 배경, 지정한 View에서 시작한 끌기는
    /// 언제나 시트를 움직입니다. 콘텐츠에서 시작한 끌기는 `dragArea`가 `.entireSheet`일 때만 시트에 닿고, 스크롤이 시트를
    /// 올리는 모드에서 시트가 가장 높은 단계 아래에 있으면 시트를, 그 밖에는 스크롤을 움직입니다. 스크롤이 맨 위에 닿은
    /// 채로 아래로 끌면 시트로 넘어옵니다. 한 끌기는 먼저 잡은 제스처가 갖고, 같은 손가락이면 지정한 View가 콘텐츠
    /// 제스처의 끌기를 넘겨받습니다.
    private func dragChanged(_ value: DragGesture.Value, source: BottomSheetDragSource) {
        let claim = BottomSheetDragClaim(source: source, startLocation: value.startLocation)

        switch claim.arbitrate(against: self.drag?.claim) {
        case .ignore:
            return

        case .begin, .takeOver:
            guard self.beginDrag(value, claim: claim) else { return }

        case .follow:
            break
        }

        guard var state = self.drag, state.isHorizontal == false else { return }

        if state.isSheet {
            let proposed = state.startOffset + (value.translation.height - state.baseline)
            let resisted = self.resolvedLayout.resistedOffset(
                proposed,
                availableHeight: self.metrics.available,
                among: self.allowedDetents,
                behavior: self.behavior
            )

            self.offset = resisted
            return
        }

        /// 스크롤 중입니다. 맨 위에 닿은 채로 아래로 끌면 시트가 이어서 내려옵니다.
        if self.behavior.sharesDragWithTrackedScroll(from: state.origin),
           self.scrollState.isAtTop,
           value.translation.height > state.baseline,
           value.velocity.height > 0 {
            state.isSheet = true
            state.startOffset = self.offset
            state.baseline = value.translation.height
            self.drag = state
            self.isScrollLockedByDrag = true
            return
        }

        state.baseline = value.translation.height
        self.drag = state
    }

    /// 끌기를 시작하거나 같은 손가락의 끌기를 넘겨받습니다.
    ///
    /// 지금 위치와 translation을 기준으로 다시 잡아 시트가 튀지 않고, 콘텐츠 제스처가 잠근 스크롤은 새 출발지 규칙으로
    /// 다시 정합니다. 시트가 받지 않는 끌기면 아무것도 바꾸지 않습니다.
    ///
    /// - Returns: 끌기를 잡았으면 `true`입니다.
    private func beginDrag(_ value: DragGesture.Value, claim: BottomSheetDragClaim) -> Bool {
        /// 콘텐츠 안에서 손가락이 스크롤뷰 위인지는 알 수 없어, `BottomSheetScrollView`가 있으면 그 위로 봅니다.
        let origin = claim.source.origin(hasTrackedScroll: self.scrollState.isPresent)
        let target = self.behavior.initialDragTarget(
            from: origin,
            offset: self.offset,
            highestOffset: self.highestOffset,
            isScrollAtTop: self.scrollState.isAtTop,
            isDraggingDown: value.translation.height > 0
        )

        /// 시트가 받지 않는 끌기입니다. 그런 제스처는 마스크로 꺼 두므로 보통 오지 않습니다.
        guard target != .ignored else { return false }

        let isHorizontal = abs(value.translation.width) > abs(value.translation.height)

        self.drag = DragState(
            claim: claim,
            startOffset: self.offset,
            baseline: value.translation.height,
            origin: origin,
            isSheet: target == .sheet,
            isHorizontal: isHorizontal
        )
        self.isScrollLockedByDrag = isHorizontal == false
            && self.behavior.locksTrackedScroll(whileDragging: target, from: origin)

        return true
    }

    /// 손을 떼면 위치와 속도로 도착 단계를 골라 스프링으로 옮기고 바인딩을 갱신합니다.
    private func dragEnded(_ value: DragGesture.Value, source: BottomSheetDragSource) {
        guard let state = self.drag, state.claim.source == source else { return }

        self.drag = nil
        self.isScrollLockedByDrag = false

        guard state.isSheet, state.isHorizontal == false else { return }

        /// 마지막 이동이 `onChanged` 없이 `onEnded`에만 실려 오기도 합니다. 손을 뗀 위치는
        /// 마지막으로 그린 offset이 아니라 `onEnded`의 translation으로 다시 계산합니다.
        let releasedAt = self.resolvedLayout.resistedOffset(
            state.startOffset + (value.translation.height - state.baseline),
            availableHeight: self.metrics.available,
            among: self.allowedDetents,
            behavior: self.behavior
        )
        self.offset = releasedAt

        let velocity = value.velocity.height
        let target = self.adjustedTarget(
            self.resolvedLayout.targetDetent(
                releasedAt: releasedAt,
                velocity: velocity,
                availableHeight: self.metrics.available,
                among: self.allowedDetents,
                behavior: self.behavior
            ),
            velocity: velocity
        )
        let targetOffset = self.targetOffset(for: target)

        /// 도착 위치와 바인딩을 같은 애니메이션 블록 안에서 바꿉니다. `detent`에 묶인 바깥 View가
        /// 시트와 나란히 움직여요. offset을 먼저 도착점으로 바꿔 두어야 바인딩 변화가 같은 자리로
        /// 다시 애니메이션하지 않습니다.
        withAnimation(self.animation(velocity: velocity, distance: targetOffset - releasedAt)) {
            self.offset = targetOffset

            if self.detent != target.identifier {
                self.detent = target.identifier
            }
        }
    }

    /// 계산된 도착 단계를 `willEndDragging`에 보여 주고, 돌려받은 이름이 레이아웃에 있으면 그 단계로 바꿉니다.
    private func adjustedTarget(_ target: BottomSheetDetent, velocity: CGFloat) -> BottomSheetDetent {
        guard let willEndDragging = self.willEndDragging else { return target }

        return self.resolvedLayout.releaseTarget(target, overriddenBy: willEndDragging(velocity, target.identifier))
    }

    /// 제스처가 `onEnded` 없이 끊겼을 때 남은 끌기를 정리합니다.
    ///
    /// 마스크가 바뀌거나 시스템이 터치를 취소하면 `onEnded`가 오지 않습니다. 상태가 남으면
    /// `applyCurrentDetentIfNeeded`가 막히고 다음 끌기가 오래된 상태를 이어 쓰므로, 지금 위치에서
    /// 가장 가까운 단계로 보냅니다. 정상적으로 끝나면 `onEnded`가 먼저 상태를 비워 할 일이 없습니다.
    /// 다른 제스처가 잡은 끌기는 건드리지 않습니다.
    private func settleAbandonedDrag(source: BottomSheetDragSource) {
        guard let state = self.drag, state.claim.source == source else { return }

        self.drag = nil
        self.isScrollLockedByDrag = false

        guard state.isSheet, state.isHorizontal == false else { return }

        let target = self.adjustedTarget(
            self.resolvedLayout.targetDetent(
                releasedAt: self.offset,
                velocity: 0,
                availableHeight: self.metrics.available,
                among: self.allowedDetents,
                behavior: self.behavior
            ),
            velocity: 0
        )
        let targetOffset = self.targetOffset(for: target)

        withAnimation(self.animation(velocity: 0, distance: targetOffset - self.offset)) {
            self.offset = targetOffset

            if self.detent != target.identifier {
                self.detent = target.identifier
            }
        }
    }
}



// MARK: - Offset Reporter

/// 시트의 실제 위치를 매 프레임 preference로 올려 보내는 모디파이어입니다.
///
/// `offset`이 애니메이션 블록 안에서 바뀌면 SwiftUI는 `Animatable`인 이 모디파이어의 `body`를
/// 중간값으로 프레임마다 다시 평가합니다. 그 값을 preference로 내보내면 시트가 스프링으로
/// 움직이는 동안에도 바깥이 실제 위치를 프레임마다 받을 수 있어요. 도착값만 애니메이션 블록 안에서
/// 한 번 알리면, `Map`처럼 UIKit이 그리는 View는 중간 위치를 보간하지 못해 도착점으로 튀어 버립니다.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
private struct BottomSheetOffsetReporter: ViewModifier, Animatable {

    var offset: CGFloat

    /// `false`면 알리지 않습니다. 자리를 잡기 전의 임시 위치를 바깥에 흘리지 않기 위해서예요.
    var isActive: Bool

    var animatableData: CGFloat {
        get { self.offset }
        set { self.offset = newValue }
    }

    func body(content: Content) -> some View {
        content.preference(key: BottomSheetReportedOffsetKey.self, value: self.isActive ? self.offset : nil)
    }
}

private struct BottomSheetReportedOffsetKey: PreferenceKey {

    static let defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

/// 콘텐츠 View가 스스로 차지하는 높이입니다.
private struct BottomSheetContentHeightKey: PreferenceKey {

    static let defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}



// MARK: - Gesture Mask

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
extension BottomSheetBehavior {

    /// 콘텐츠 전체에 붙인 끌기 제스처를 켤지 정하는 마스크입니다.
    ///
    /// `.subviews`는 하위 View의 제스처는 켜 두고 이 제스처만 끕니다. `if`로 수정자를 붙였다 떼면 콘텐츠의
    /// 구조적 정체성이 바뀌어 List의 스크롤 위치와 `@State`가 초기화되므로 마스크로 끕니다.
    ///
    /// - Complexity: O(1)입니다.
    var contentDragGestureMask: GestureMask {
        let acceptsContentDrag = self.acceptsDrag(from: .content) || self.acceptsDrag(from: .trackedScrollView)

        return acceptsContentDrag ? .all : .subviews
    }

    /// 손잡이 줄의 끌기 제스처를 켤지 정하는 마스크입니다. 판단은 Core의 `acceptsDrag`를 따릅니다.
    ///
    /// - Complexity: O(1)입니다.
    var handleDragGestureMask: GestureMask {
        return self.acceptsDrag(from: .handle) ? .all : .subviews
    }

    /// 시트 배경(콘텐츠가 받지 않는 빈 곳)의 끌기 제스처를 켤지 정하는 마스크입니다.
    ///
    /// - Complexity: O(1)입니다.
    var backgroundDragGestureMask: GestureMask {
        return self.acceptsDrag(from: .background) ? .all : .subviews
    }
}
#endif
