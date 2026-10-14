//
//  BottomSheetDock.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/23/26.
//

#if !os(tvOS)
import SwiftUI
import UIComponentsCore

// MARK: - Environment

private struct BottomSheetCoveredHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct BottomSheetDetentKey: EnvironmentKey {
    static let defaultValue: BottomSheetDetent.Identifier? = nil
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
extension EnvironmentValues {

    /// 바텀시트가 가린 높이입니다. 부모 안전 영역 아래쪽 끝에서 시트 윗선까지의 거리예요.
    ///
    /// `bottomSheet(detent:)`를 붙인 View **안**에서만 값이 들어오고, 그 밖이거나 시트가 `hidden`이면 0이에요.
    /// 끄는 동안과 스프링으로 움직이는 동안 매 프레임 바뀝니다. 직접 읽어 쓸 수도 있지만 보통은
    /// `bottomSheetInset()`이나 `bottomSheetDock(alignment:content:)`를 쓰면 돼요.
    public var bottomSheetCoveredHeight: CGFloat {
        get { self[BottomSheetCoveredHeightKey.self] }
        set { self[BottomSheetCoveredHeightKey.self] = newValue }
    }

    /// 바텀시트가 머무는 단계입니다. `bottomSheet(detent:)`를 붙인 View 안에서만 값이 있고 밖에서는 `nil`이에요.
    ///
    /// 손을 뗀 순간 도착 단계로 바뀌어요. `bottomSheetDockVisibility(_:)`가 이 값으로 항목을 넣고 빼요.
    public var bottomSheetDetent: BottomSheetDetent.Identifier? {
        get { self[BottomSheetDetentKey.self] }
        set { self[BottomSheetDetentKey.self] = newValue }
    }
}



// MARK: - Modifiers

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
extension View {

    /// 시트가 가린 만큼 아래 안전 영역을 줄입니다.
    ///
    /// `Map`에 붙이면 MapKit이 보이는 영역 가운데로 카메라를 다시 잡고, 컴퍼스·저작권 표시도 시트 위로
    /// 올라와요. `List`·`ScrollView`에 붙이면 마지막 줄이 시트에 가리지 않아요. 시트를 끌거나 스프링으로
    /// 움직이는 동안 매 프레임 따라가고, 애니메이션을 따로 걸지 않아요.
    ///
    /// `bottomSheet(detent:)`를 붙인 View 안에서 써요.
    ///
    /// ```swift
    /// Map(position: $camera)
    ///     .bottomSheetInset()
    ///     .bottomSheet(detent: $detent) { PlaceList() }
    /// ```
    public func bottomSheetInset() -> some View {
        return self.modifier(BottomSheetInsetModifier())
    }

    /// 시트 위에 떠서 함께 움직이는 컨트롤 묶음(도크)을 붙입니다.
    ///
    /// `content`를 세로로 쌓아 `alignment` 쪽 아래 모서리에 놓고, 시트가 가린 높이만큼 위로 띄워요.
    /// 시트가 `hidden`이면 탭바 바로 위에 머물러요. 버튼에는 `.buttonStyle(.bottomSheetDock)`을 쓰면
    /// 도크에 어울리는 44pt 원형이 돼요.
    ///
    /// `bottomSheetInset()`을 함께 쓰면 그 **바깥**(뒤)에 붙여요. 안쪽에 붙이면 줄어든 안전 영역 위에
    /// 다시 가린 높이만큼 띄워 두 배로 올라가요.
    ///
    /// ```swift
    /// Map(position: $camera)
    ///     .bottomSheetInset()
    ///     .bottomSheetDock {
    ///         Button { locate() } label: { Image(systemName: "location.fill") }
    ///             .buttonStyle(.bottomSheetDock)
    ///     }
    ///     .bottomSheet(detent: $detent) { PlaceList() }
    /// ```
    ///
    /// - Parameters:
    ///   - alignment: 가로로 붙일 쪽입니다. 기본값은 `trailing`이에요.
    ///   - spacing: 도크 안 View 사이 간격입니다.
    ///   - insets: 가리지 않은 영역 가장자리에서 띄울 거리입니다. `top`은 쓰지 않아요.
    ///   - content: 위에서 아래 순서로 쌓을 View입니다.
    public func bottomSheetDock<Dock: View>(
        alignment: BottomSheetDockAlignment = .trailing,
        spacing: CGFloat = 12,
        insets: EdgeInsets = EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16),
        @ViewBuilder content: () -> Dock
    ) -> some View {
        return self.modifier(BottomSheetDockModifier(alignment: alignment, spacing: spacing, insets: insets, dock: content()))
    }

    /// 도크 항목이 시트의 어느 단계에서 보일지 정합니다.
    ///
    /// 시트가 머무는 단계가 규칙에 맞지 않으면 항목을 스택에서 빼고, 맞으면 다시 넣어요. 넣고 뺄 때 크기·투명도
    /// 전환이 있어 시트가 움직이는 동안 함께 나타나고 사라져요. `bottomSheet(detent:)` 밖에서는 항상 보여요.
    ///
    /// ```swift
    /// .bottomSheetDock {
    ///     Button { detent = .tip } label: { Image(systemName: "chevron.up") }
    ///         .buttonStyle(.bottomSheetDock)
    ///         .bottomSheetDockVisibility(.whenHidden)   // 시트가 내려가 있을 때만
    ///     Button { locate() } label: { Image(systemName: "location.fill") }
    ///         .buttonStyle(.bottomSheetDock)
    /// }
    /// ```
    public func bottomSheetDockVisibility(_ visibility: BottomSheetDockVisibility) -> some View {
        return self.modifier(BottomSheetDockVisibilityModifier(visibility: visibility))
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct BottomSheetDockVisibilityModifier: ViewModifier {

    let visibility: BottomSheetDockVisibility

    @Environment(\.bottomSheetDetent) private var detent

    private var isVisible: Bool {
        guard let detent else { return true }

        return self.visibility.isVisible(at: detent)
    }

    func body(content: Content) -> some View {
        Group {
            if self.isVisible {
                content.transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: self.isVisible)
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct BottomSheetInsetModifier: ViewModifier {

    @Environment(\.bottomSheetCoveredHeight) private var coveredHeight

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: self.coveredHeight)
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct BottomSheetDockModifier<Dock: View>: ViewModifier {

    let alignment: BottomSheetDockAlignment
    let spacing: CGFloat
    let insets: EdgeInsets
    let dock: Dock

    @Environment(\.bottomSheetCoveredHeight) private var coveredHeight

    func body(content: Content) -> some View {
        content.overlay(alignment: self.alignment == .trailing ? .bottomTrailing : .bottomLeading) {
            VStack(spacing: self.spacing) {
                self.dock
            }
            .padding(.leading, self.insets.leading)
            .padding(.trailing, self.insets.trailing)
            .padding(.bottom, self.coveredHeight + self.insets.bottom)
        }
    }
}



// MARK: - Button Style

/// 도크에 어울리는 44pt 원형 버튼 스타일입니다. 바탕은 `background`, 아이콘은 강조색이고 옅은 그림자가 있어요.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct BottomSheetDockButtonStyle: ButtonStyle {

    /// 버튼의 한 변 길이입니다.
    public static let size: CGFloat = 44

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.tint)
            .frame(width: Self.size, height: Self.size)
            .background(.background, in: Circle())
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
extension ButtonStyle where Self == BottomSheetDockButtonStyle {

    /// 도크에 어울리는 44pt 원형 버튼 스타일이에요.
    public static var bottomSheetDock: BottomSheetDockButtonStyle { BottomSheetDockButtonStyle() }
}
#endif
