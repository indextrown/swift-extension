//
//  BottomSheetScrollView.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

#if !os(tvOS)
import SwiftUI

/// 바텀시트 안에서 쓰는 세로 스크롤뷰입니다.
///
/// SwiftUI의 `ScrollView`는 스크롤 위치를 바깥에 알려 주지 않아서, 시트가 "지금 콘텐츠가
/// 맨 위에 있는지"를 알 수 없습니다. 이 View는 스크롤 위치를 `PreferenceKey`로 시트에
/// 올려 보내, 시트가 다 올라간 뒤 맨 위에서 아래로 끌면 스크롤 대신 시트가 움직이게 합니다.
///
/// 시트 콘텐츠에 스크롤이 필요하면 `ScrollView` 대신 이 View를 씁니다. 일반 `ScrollView`를
/// 쓰면 시트가 가장 높은 단계 아래에 있을 때는 스크롤이 잠기지만, 맨 위에서 시트로 넘어오는
/// 동작은 되지 않습니다.
///
/// ```swift
/// .bottomSheet(detent: $detent) {
///     BottomSheetScrollView {
///         LazyVStack { ForEach(places) { PlaceRow($0) } }
///     }
/// }
/// ```
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct BottomSheetScrollView<Content: View>: View {

    /// 제네릭 타입은 저장 static을 가질 수 없어 계산 프로퍼티로 둡니다.
    private static var spaceName: String { "BottomSheetScrollView" }

    private let showsIndicators: Bool
    private let content: Content

    /// - Parameters:
    ///   - showsIndicators: 스크롤 인디케이터를 보일지 정합니다.
    ///   - content: 스크롤할 내용입니다.
    public init(showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: self.showsIndicators) {
            self.content
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: BottomSheetScrollStateKey.self,
                            value: BottomSheetScrollState(
                                isAtTop: proxy.frame(in: .named(Self.spaceName)).minY >= -0.5,
                                isPresent: true,
                                contentHeight: proxy.size.height
                            )
                        )
                    }
                }
        }
        .coordinateSpace(.named(Self.spaceName))
    }
}



// MARK: - Preference

/// 시트 콘텐츠의 스크롤 상태입니다.
struct BottomSheetScrollState: Equatable {

    /// 스크롤이 맨 위에 닿아 있는지 나타냅니다.
    var isAtTop: Bool

    /// 콘텐츠 안에 `BottomSheetScrollView`가 있는지 나타냅니다.
    var isPresent: Bool

    /// 스크롤 안쪽 콘텐츠의 높이입니다. `.content` 단계가 시트 높이를 정할 때 씁니다.
    var contentHeight: CGFloat = 0
}

struct BottomSheetScrollStateKey: PreferenceKey {

    static let defaultValue = BottomSheetScrollState(isAtTop: true, isPresent: false)

    static func reduce(value: inout BottomSheetScrollState, nextValue: () -> BottomSheetScrollState) {
        let next = nextValue()

        guard next.isPresent else { return }

        value = next
    }
}
#endif
