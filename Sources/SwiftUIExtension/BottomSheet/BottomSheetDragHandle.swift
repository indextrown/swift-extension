//
//  BottomSheetDragHandle.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/13/26.
//

#if !os(tvOS)
import SwiftUI
import UIComponentsCore

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
extension View {

    /// 이 View에서 시작한 끌기로 바텀시트를 옮기게 합니다.
    ///
    /// 이 View는 시트의 손잡이처럼 동작합니다. `BottomSheetBehavior.dragArea`와 상관없이 이 View에서 시작한 세로 끌기는
    /// 시트를 움직이고, `BottomSheetScrollView`의 스크롤과 엮이지 않습니다. 안쪽의 버튼·스크롤뷰·제스처가 붙은 View는
    /// 자기 제스처를 지켜, 그 위에서 시작한 끌기는 시트가 받지 않습니다. lucaszischka/BottomSheet의 `headerContent`와
    /// 같습니다.
    ///
    /// `.handleAndBackground`에서는 제스처가 없는 글자와 빈 곳이 이미 시트 배경으로 끌리므로, 그 자체가 터치를 받는
    /// 제목줄(배경을 채운 카드, 탭 제스처가 붙은 줄)을 끌기 영역에 더할 때 씁니다. `.entireSheet`에서는
    /// `BottomSheetScrollView`가 있어도 제목줄의 끌기를 스크롤과 엮지 않고 시트만 움직이게 합니다.
    ///
    /// `bottomSheet(detent:)`의 `content` 안에서만 동작하고 밖에서는 아무 일도 하지 않습니다. 스크롤뷰·`List` 안의 View에는
    /// 붙이지 않습니다. 스크롤과 끌기가 경쟁합니다. VoiceOver 요소는 바꾸지 않고, 단계 조절은 손잡이가 맡습니다.
    ///
    /// ```swift
    /// .bottomSheet(detent: $detent, behavior: BottomSheetBehavior(dragArea: .handleAndBackground)) {
    ///     VStack(spacing: 0) {
    ///         SheetHeader().bottomSheetDragHandle()
    ///         List(places) { PlaceRow($0) }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter isEnabled: `false`면 끌기 손잡이로 쓰지 않습니다. 수정자를 `if`로 붙였다 떼면 View의 정체성이 바뀌어
    ///   `@State`와 스크롤 위치가 초기화되므로 이 값으로 끕니다. 기본값은 `true`입니다.
    /// - Returns: 시트를 끄는 제스처가 붙은 View입니다.
    /// - Complexity: O(1)입니다.
    public func bottomSheetDragHandle(_ isEnabled: Bool = true) -> some View {
        return self.modifier(BottomSheetDragHandleModifier(isEnabled: isEnabled))
    }
}



// MARK: - Drag Source

/// 시트를 끄는 제스처가 붙은 자리입니다. 한 끌기를 두 제스처가 나눠 쓰지 않게 끌기를 잡은 제스처를 가립니다.
enum BottomSheetDragSource: Hashable {

    /// 손잡이 줄입니다.
    case grabber

    /// 콘텐츠가 받지 않는 시트 배경입니다.
    case background

    /// 콘텐츠 전체에 붙인 제스처입니다.
    case content

    /// 끌기 손잡이로 지정한 View입니다. View마다 다른 값입니다.
    case designated(UUID)

    /// Core의 출발지로 바꿉니다. 콘텐츠 안의 위치는 몰라 `BottomSheetScrollView`가 있으면 그 위로 봅니다.
    ///
    /// - Parameter hasTrackedScroll: 콘텐츠에 `BottomSheetScrollView`가 있는지입니다.
    /// - Returns: 끌기의 출발지입니다.
    /// - Complexity: O(1)입니다.
    func origin(hasTrackedScroll: Bool) -> BottomSheetDragOrigin {
        switch self {
        case .grabber, .designated:
            return .handle

        case .background:
            return .background

        case .content:
            return hasTrackedScroll ? .trackedScrollView : .content
        }
    }

    /// 같은 손가락으로 함께 시작된 다른 제스처의 끌기를 넘겨받을 수 있는지입니다.
    ///
    /// 지정한 View는 콘텐츠 안에 있어 `.entireSheet`에서 콘텐츠 제스처와 함께 시작합니다. 어느 쪽이 먼저 불리든
    /// 지정한 View가 이깁니다.
    ///
    /// - Parameter owner: 지금 끌기를 잡은 제스처입니다.
    /// - Returns: 넘겨받을 수 있으면 `true`입니다.
    /// - Complexity: O(1)입니다.
    func canTakeOver(from owner: BottomSheetDragSource) -> Bool {
        guard case .designated = self else { return false }

        return owner == .content
    }
}

/// 한 끌기를 잡은 제스처와 손가락이 처음 닿은 화면 위치입니다. `DragGesture.Value`는 테스트에서 만들 수 없어 필요한 값만 담습니다.
struct BottomSheetDragClaim: Equatable {

    /// 같은 손가락으로 보는 시작 위치의 차이입니다. 모든 끌기 제스처가 `.global` 좌표의 시작 위치를 씁니다.
    static let sameTouchTolerance: CGFloat = 1

    var source: BottomSheetDragSource

    var startLocation: CGPoint

    /// 진행 중인 끌기에 비춰 이 제스처의 알림을 어떻게 다룰지 정합니다.
    ///
    /// 먼저 잡은 쪽이 이기고, 같은 손가락이면 지정한 View가 콘텐츠 제스처의 끌기를 넘겨받습니다.
    ///
    /// - Parameter owner: 진행 중인 끌기입니다. 없으면 `nil`입니다.
    /// - Returns: 이 알림을 다루는 방법입니다.
    /// - Complexity: O(1)입니다.
    func arbitrate(against owner: BottomSheetDragClaim?) -> BottomSheetDragArbitration {
        guard let owner else { return .begin }
        guard owner.source != self.source else { return .follow }

        let dx = owner.startLocation.x - self.startLocation.x
        let dy = owner.startLocation.y - self.startLocation.y
        let isSameTouch = (dx * dx + dy * dy).squareRoot() <= Self.sameTouchTolerance

        return isSameTouch && self.source.canTakeOver(from: owner.source) ? .takeOver : .ignore
    }
}

/// 제스처 알림을 다루는 방법입니다.
enum BottomSheetDragArbitration: Equatable {

    /// 진행 중인 끌기가 없어 새로 시작합니다.
    case begin

    /// 이 제스처가 잡은 끌기를 이어 갑니다.
    case follow

    /// 같은 손가락의 끌기를 이 제스처가 넘겨받습니다.
    case takeOver

    /// 다른 제스처가 잡은 끌기라 무시합니다.
    case ignore
}



// MARK: - Drag Sink

/// `bottomSheetDragHandle(_:)`이 끌기를 시트에 넘기는 통로입니다. 시트가 `content`에 environment로 넣습니다.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct BottomSheetDragSink {

    /// 시트가 손잡이 출발지를 받는지입니다. `false`면 지정한 View는 자기 제스처만 끄고 안쪽 제스처는 살립니다.
    var acceptsDrag: Bool

    var changed: @MainActor (DragGesture.Value, UUID) -> Void

    var ended: @MainActor (DragGesture.Value, UUID) -> Void

    var abandoned: @MainActor (UUID) -> Void
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
private struct BottomSheetDragSinkKey: EnvironmentKey {

    static var defaultValue: BottomSheetDragSink? { nil }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
extension EnvironmentValues {

    /// 가장 가까운 바텀시트의 끌기 통로입니다. 시트 밖에서는 `nil`입니다.
    var bottomSheetDragSink: BottomSheetDragSink? {
        get { self[BottomSheetDragSinkKey.self] }
        set { self[BottomSheetDragSinkKey.self] = newValue }
    }
}



// MARK: - Modifier

/// 지정한 View에 시트를 끄는 제스처를 붙입니다.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct BottomSheetDragHandleModifier: ViewModifier {

    let isEnabled: Bool

    @Environment(\.bottomSheetDragSink) private var sink

    /// 지정한 View마다 다른 이름입니다. 손가락 두 개가 서로 다른 지정 View를 끌 때 끝 신호를 구분합니다.
    @State private var id = UUID()

    /// 제스처가 진행 중인지 나타냅니다. `onEnded` 없이 끊긴 끌기를 알아채는 데 씁니다.
    @GestureState private var isDragging = false

    /// 켜져 있고 시트가 손잡이 출발지를 받을 때만 제스처를 켭니다. 수정자를 떼지 않고 마스크로 끕니다.
    ///
    /// - Parameters:
    ///   - isEnabled: 수정자에 넘긴 값입니다.
    ///   - sinkAcceptsDrag: 시트가 손잡이 출발지를 받는지입니다. 시트 밖이면 `nil`입니다.
    /// - Returns: 제스처 마스크입니다.
    /// - Complexity: O(1)입니다.
    static func gestureMask(isEnabled: Bool, sinkAcceptsDrag: Bool?) -> GestureMask {
        return isEnabled && sinkAcceptsDrag == true ? .all : .subviews
    }

    func body(content: Content) -> some View {
        let id = self.id
        let sink = self.sink

        content
            /// lucaszischka 헤더처럼 `.gesture`로 붙입니다. 안쪽 버튼이 탭을 먼저 받습니다.
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .updating(self.$isDragging) { _, isDragging, _ in
                        isDragging = true
                    }
                    .onChanged { value in
                        sink?.changed(value, id)
                    }
                    .onEnded { value in
                        sink?.ended(value, id)
                    },
                including: Self.gestureMask(isEnabled: self.isEnabled, sinkAcceptsDrag: sink?.acceptsDrag)
            )
            .onChange(of: self.isDragging) { _, isDragging in
                guard isDragging == false else { return }

                sink?.abandoned(id)
            }
            /// 끄는 도중 View가 사라지면 `onChange`가 오지 않을 수 있습니다.
            .onDisappear {
                sink?.abandoned(id)
            }
    }
}
#endif
