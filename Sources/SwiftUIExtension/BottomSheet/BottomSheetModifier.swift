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
    /// 콘텐츠에 스크롤이 필요하면 `ScrollView` 대신 `BottomSheetScrollView`를 씁니다.
    /// 시트가 다 올라가기 전에는 스크롤이 잠기고 시트가 움직이며, 다 올라간 뒤 맨 위에서
    /// 아래로 끌면 다시 시트로 넘어옵니다.
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
    ///   - onOffsetChange: 시트 위치(부모 안전 영역 위쪽 끝에서 시트 위쪽 끝까지의 거리)를 전달합니다.
    ///     사용자가 끄는 동안은 매 프레임, 손을 뗀 뒤나 `detent`를 바꿔 옮길 때는 도착 위치를 한 번
    ///     애니메이션 블록 안에서 전달합니다. 받은 값을 `@State`에 넣으면 그 값에 묶인 View가 시트와
    ///     나란히 움직입니다.
    ///   - content: 시트 안에 표시할 내용입니다.
    public func bottomSheet<Content: View>(
        detent: Binding<BottomSheetDetent.Identifier>,
        layout: BottomSheetLayout = .standard,
        allowedDetents: Set<BottomSheetDetent.Identifier>? = nil,
        style: BottomSheetStyle = .default,
        behavior: BottomSheetBehavior = .default,
        onOffsetChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        return self.overlay {
            BottomSheetOverlay(
                detent: detent,
                layout: layout,
                allowedDetents: allowedDetents,
                style: style,
                behavior: behavior,
                onOffsetChange: onOffsetChange,
                content: content()
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
    let onOffsetChange: ((CGFloat) -> Void)?
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

    /// 손가락이 시트를 움직이는 동안 스크롤을 잠근 상태인지 나타냅니다.
    @State private var isScrollLockedByDrag = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Metrics: Equatable {
        /// 시트가 쓸 수 있는 안전 영역의 높이입니다.
        var available: CGFloat = 0

        /// 안전 영역 아래쪽 여백입니다. 탭바와 홈 인디케이터 높이입니다.
        var bottomInset: CGFloat = 0
    }

    private struct DragState {
        /// 끌기를 시작한 순간의 위치이며 이동 거리를 더할 기준입니다.
        var startOffset: CGFloat

        /// 이동 거리를 재는 기준이 되는 translation입니다. 스크롤에서 넘어올 때 다시 잡습니다.
        var baseline: CGFloat

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
            .onAppear {
                self.metrics = measured
                self.enterIfPossible()
            }
            .onChange(of: measured) { _, newValue in
                self.metrics = newValue
                self.applyCurrentDetentIfNeeded()
            }
        }
        .onChange(of: self.detent) { _, newValue in
            self.moveIfNeeded(to: newValue)
        }
        .onChange(of: self.allowedDetents) { _, _ in
            self.applyAllowedDetents()
        }
        .onPreferenceChange(BottomSheetScrollStateKey.self) { newValue in
            self.scrollState = newValue
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

            VStack(spacing: 0) {
                if self.style.showsGrabber {
                    self.handle
                }

                self.content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    /// 시트 바닥은 탭바 뒤까지 이어지므로 콘텐츠는 그만큼 위에서 끝나야 가리지 않습니다.
                    .padding(.bottom, self.metrics.bottomInset)
                    .scrollDisabled(self.isScrollDisabled)
                    .simultaneousGesture(self.dragGesture(fromHandle: false))
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
            .gesture(self.dragGesture(fromHandle: true))
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
            let progress = self.layout.backdropProgress(
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
        return self.layout.detent(for: self.detent) ?? self.layout.detents[0]
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

        return self.layout.offset(for: detent, availableHeight: self.metrics.available)
    }

    private var highestOffset: CGFloat {
        let detent = self.layout.highestDetent(
            availableHeight: self.metrics.available,
            among: self.allowedDetents
        )

        return self.targetOffset(for: detent)
    }

    private var isHidden: Bool {
        return self.currentDetent.anchor == .hidden && self.drag == nil
    }

    /// 시트가 가장 높은 단계 아래에 있거나 손가락이 시트를 움직이는 동안은 콘텐츠 스크롤을 잠급니다.
    private var isScrollDisabled: Bool {
        guard self.scrollState.isPresent else { return false }

        return self.isScrollLockedByDrag || self.offset > self.highestOffset + 0.5
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
            self.onOffsetChange?(target)
            return
        }

        self.offset = self.metrics.available + self.metrics.bottomInset

        withAnimation(self.animation(velocity: 0, distance: 0)) {
            self.offset = target
            self.onOffsetChange?(target)
        }
    }

    /// 크기가 바뀌었을 때 현재 단계의 위치를 다시 맞춥니다. 끌고 있는 동안은 건드리지 않습니다.
    private func applyCurrentDetentIfNeeded() {
        guard self.hasEntered else { return self.enterIfPossible() }
        guard self.drag == nil else { return }

        let target = self.targetOffset(for: self.currentDetent)

        guard abs(self.offset - target) > 0.5 else { return }

        self.offset = target
        self.onOffsetChange?(target)
    }

    /// 바인딩이 바뀌면 그 단계로 옮깁니다. 이미 그 자리면 아무 일도 하지 않습니다.
    private func moveIfNeeded(to identifier: BottomSheetDetent.Identifier) {
        guard self.hasEntered, let detent = self.layout.detent(for: identifier) else { return }

        let target = self.targetOffset(for: detent)

        guard abs(self.offset - target) > 0.5 else { return }

        withAnimation(self.animation(velocity: 0, distance: target - self.offset)) {
            self.offset = target
            self.onOffsetChange?(target)
        }
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

        self.detent = target.identifier
    }

    private func step(up: Bool) {
        let next = up
            ? self.layout.detent(above: self.currentDetent, availableHeight: self.referenceHeight, among: self.allowedDetents)
            : self.layout.detent(below: self.currentDetent, availableHeight: self.referenceHeight, among: self.allowedDetents)

        guard let next else { return }

        self.detent = next.identifier
    }

    private func collapse(using backdrop: BottomSheetBackdropStyle) {
        if let identifier = backdrop.largestUndimmedDetent,
           let detent = self.layout.detent(for: identifier),
           self.layout.detents(among: self.allowedDetents).contains(detent) {
            self.detent = identifier
            return
        }

        self.detent = self.layout.lowestDetent(
            availableHeight: self.referenceHeight,
            among: self.allowedDetents
        ).identifier
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

    private func dragGesture(fromHandle: Bool) -> some Gesture {
        /// 좌표계는 반드시 화면(`.global`) 기준이어야 합니다. 제스처가 붙은 View 자신(`.local`)을 기준으로 재면
        /// 시트가 손가락을 따라 움직인 만큼 translation이 줄어들어 손가락의 절반만 따라옵니다.
        return DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                self.dragChanged(value, fromHandle: fromHandle)
            }
            .onEnded { value in
                self.dragEnded(value)
            }
    }

    /// 시트를 끄는 동안 따라 움직입니다.
    ///
    /// 손잡이에서 시작한 끌기는 언제나 시트를 움직입니다. 콘텐츠에서 시작한 끌기는 시트가 가장 높은
    /// 단계 아래에 있으면 시트를, 가장 높은 단계에 있으면 스크롤을 움직입니다. 스크롤이 맨 위에
    /// 닿은 채로 아래로 끌면 시트로 넘어옵니다.
    private func dragChanged(_ value: DragGesture.Value, fromHandle: Bool) {
        if self.drag == nil {
            let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
            let isSheet = fromHandle || self.startsAsSheetDrag(draggingDown: value.translation.height > 0)

            self.drag = DragState(
                startOffset: self.offset,
                baseline: value.translation.height,
                isSheet: isSheet,
                isHorizontal: isHorizontal
            )

            if isSheet, isHorizontal == false {
                self.isScrollLockedByDrag = true
            }
        }

        guard var state = self.drag, state.isHorizontal == false else { return }

        if state.isSheet {
            let proposed = state.startOffset + (value.translation.height - state.baseline)
            let resisted = self.layout.resistedOffset(
                proposed,
                availableHeight: self.metrics.available,
                among: self.allowedDetents,
                behavior: self.behavior
            )

            self.offset = resisted
            self.onOffsetChange?(resisted)
            return
        }

        /// 스크롤 중입니다. 맨 위에 닿은 채로 아래로 끌면 시트가 이어서 내려옵니다.
        if self.scrollState.isAtTop, value.translation.height > state.baseline, value.velocity.height > 0 {
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

    /// 콘텐츠에서 시작한 끌기가 시트를 움직여야 하는지 정합니다.
    private func startsAsSheetDrag(draggingDown: Bool) -> Bool {
        guard self.scrollState.isPresent else { return true }

        /// 가장 높은 단계 아래에 있으면 언제나 시트가 움직입니다.
        guard self.offset <= self.highestOffset + 0.5 else { return true }

        return self.scrollState.isAtTop && draggingDown
    }

    /// 손을 떼면 위치와 속도로 도착 단계를 골라 스프링으로 옮기고 바인딩을 갱신합니다.
    private func dragEnded(_ value: DragGesture.Value) {
        guard let state = self.drag else { return }

        self.drag = nil
        self.isScrollLockedByDrag = false

        guard state.isSheet, state.isHorizontal == false else { return }

        /// 마지막 이동이 `onChanged` 없이 `onEnded`에만 실려 오기도 합니다. 손을 뗀 위치는
        /// 마지막으로 그린 offset이 아니라 `onEnded`의 translation으로 다시 계산합니다.
        let releasedAt = self.layout.resistedOffset(
            state.startOffset + (value.translation.height - state.baseline),
            availableHeight: self.metrics.available,
            among: self.allowedDetents,
            behavior: self.behavior
        )
        self.offset = releasedAt

        let velocity = value.velocity.height
        let target = self.layout.targetDetent(
            releasedAt: releasedAt,
            velocity: velocity,
            availableHeight: self.metrics.available,
            among: self.allowedDetents,
            behavior: self.behavior
        )
        let targetOffset = self.targetOffset(for: target)

        /// 도착 위치도 같은 애니메이션 블록 안에서 알립니다. 받는 쪽이 `@State`에 넣으면 시트와 나란히 움직입니다.
        withAnimation(self.animation(velocity: velocity, distance: targetOffset - releasedAt)) {
            self.offset = targetOffset
            self.onOffsetChange?(targetOffset)
        }

        /// offset을 먼저 도착점으로 바꿔 두어야 바인딩 변화가 같은 자리로 다시 애니메이션하지 않습니다.
        if self.detent != target.identifier {
            self.detent = target.identifier
        }
    }
}
#endif
