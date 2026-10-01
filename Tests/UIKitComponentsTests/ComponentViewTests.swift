#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import SwiftUI
import Testing
import UIKit
@testable import UIKitComponents

@MainActor
@Test func componentViewInScrollViewUsesProposedWidthAndContentHeight() throws {
    let (window, _) = makeWindow(width: 240, rootView: ScrollView {
        VStack(spacing: 0) {
            ComponentView(LabelComponent(longText))
            ComponentView(LabelComponent(shortText))
        }
    })

    let hostViews = descendants(of: SwiftUIComponentHostView<LabelComponent>.self, in: window)
    try #require(hostViews.count == 2)
    #expect(hostViews.allSatisfy { $0.frame.width == 240 })
    #expect(abs(hostViews[0].frame.height - expectedHeight(longText, width: 240)) < 1)
    #expect(abs(hostViews[1].frame.height - expectedHeight(shortText, width: 240)) < 1)
}

@MainActor
@Test func componentViewDoesNotStretchToFillVStack() throws {
    let (window, _) = makeWindow(width: 240, rootView: VStack(spacing: 0) {
        ComponentView(LabelComponent(longText))
        Spacer()
    })

    let hostView = try #require(descendants(of: SwiftUIComponentHostView<LabelComponent>.self, in: window).first)
    #expect(hostView.frame.width == 240)
    #expect(abs(hostView.frame.height - expectedHeight(longText, width: 240)) < 1)
}

@MainActor
@Test func componentConformingToViewCanBePlacedDirectly() throws {
    let (window, _) = makeWindow(width: 240, rootView: VStack {
        LabelComponent(longText)
    })

    let hostView = try #require(descendants(of: SwiftUIComponentHostView<LabelComponent>.self, in: window).first)
    #expect(hostView.hostedView.label.text == longText)
    #expect(abs(hostView.frame.height - expectedHeight(longText, width: 240)) < 1)
}

@MainActor
@Test func componentViewRemeasuresAfterInvalidateLayout() throws {
    let contextBox = ContextBox()
    let (window, _) = makeWindow(width: 240, rootView: ScrollView {
        ComponentView(LabelComponent(shortText, contextBox: contextBox))
    })
    let hostView = try #require(descendants(of: SwiftUIComponentHostView<LabelComponent>.self, in: window).first)

    /// 이미지를 받아 넣은 것처럼 SwiftUI 상태 변경 없이 뷰의 크기만 바꿔요.
    hostView.hostedView.label.text = longText
    contextBox.context?.invalidateLayout()
    runLayout(window)

    #expect(abs(hostView.frame.height - expectedHeight(longText, width: 240)) < 1)
}

@MainActor
@Test func componentViewUpdatesWhenSwiftUIStateChanges() throws {
    let makeCounter = Counter()
    let (window, hostingController) = makeWindow(
        width: 240,
        rootView: ComponentView(LabelComponent(shortText, makeCounter: makeCounter))
    )

    hostingController.rootView = ComponentView(LabelComponent(longText, makeCounter: makeCounter))
    runLayout(window)

    let hostView = try #require(descendants(of: SwiftUIComponentHostView<LabelComponent>.self, in: window).first)
    #expect(hostView.hostedView.label.text == longText)
    #expect(makeCounter.value == 1)
    #expect(abs(hostView.frame.height - expectedHeight(longText, width: 240)) < 1)
}

@MainActor
@Test func componentViewMeasuresEachRowOnceAndOnlyChangedRowsOnUpdate() throws {
    guard #available(iOS 16.0, *) else { return }

    func rows(expanded: Bool) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<10, id: \.self) { index in
                    ComponentView(LabelComponent(expanded && index.isMultiple(of: 2) ? longText : shortText))
                }
            }
        }
    }
    let (window, hostingController) = makeWindow(width: 240, rootView: rows(expanded: false))
    let hostViews = descendants(of: SwiftUIComponentHostView<LabelComponent>.self, in: window)
    try #require(hostViews.count == 10)

    /// 직접 작성한 `UIViewRepresentable`처럼 행마다 한 번만 재야 해요.
    #expect(hostViews.map(\.hostedView.fittingCount) == Array(repeating: 1, count: 10))

    hostingController.rootView = rows(expanded: true)
    hostingController.view.layoutIfNeeded()

    /// 글이 바뀐 짝수 행만 한 번 더 재요.
    let expected = (0..<10).map { $0.isMultiple(of: 2) ? 2 : 1 }
    #expect(hostViews.map(\.hostedView.fittingCount) == expected)
}

@MainActor
@Test func componentViewRemeasuresWhenWidthChanges() throws {
    let (window, hostingController) = makeWindow(width: 240, rootView: ScrollView {
        VStack(spacing: 0) {
            ComponentView(LabelComponent(longText))
        }
    })
    let hostView = try #require(descendants(of: SwiftUIComponentHostView<LabelComponent>.self, in: window).first)
    #expect(abs(hostView.frame.height - expectedHeight(longText, width: 240)) < 1)

    /// 회전이나 분할 화면처럼 SwiftUI가 다른 너비를 제안하는 경우예요.
    for width in [360, 200] as [CGFloat] {
        window.frame = CGRect(x: 0, y: 0, width: width, height: 3000)
        hostingController.view.frame = window.bounds
        runLayout(window)

        #expect(hostView.frame.width == width)
        #expect(abs(hostView.frame.height - expectedHeight(longText, width: width)) < 1)
    }
}

@MainActor
@Test func componentViewCancelsWhenRemovedFromHierarchy() {
    let cancellations = Counter()
    let (window, hostingController) = makeWindow(
        width: 240,
        rootView: AnyView(ComponentView(CancellationComponent(cancellations: cancellations)))
    )
    /// 첫 갱신을 `updateUIView`까지 미뤄서, 나타나는 동안에는 취소가 없어요.
    #expect(cancellations.value == 0)

    hostingController.rootView = AnyView(EmptyView())
    runLayout(window)

    #expect(cancellations.value == 1)
}

@MainActor
@Test func componentViewUpdatesNonEquatableComponentOnceOnAppear() throws {
    let updates = Counter()
    let (window, _) = makeWindow(width: 240, rootView: ScrollView {
        VStack(spacing: 0) {
            ComponentView(ClosureComponent(text: longText) { updates.value += 1 })
        }
    })

    let hostView = try #require(descendants(of: SwiftUIComponentHostView<ClosureComponent>.self, in: window).first)
    #expect(updates.value == 1)
    #expect(hostView.updateCount == 1)
    #expect(abs(hostView.frame.height - expectedHeight(longText, width: 240)) < 1)
}

@MainActor
@Test func hostMeasuredBeforeFirstUpdateUsesComponentFromMake() {
    let hostView = SwiftUIComponentHostView(LabelComponent(longText))
    #expect(hostView.updateCount == 0)

    let size = hostView.fittingSize(width: 240)

    #expect(hostView.updateCount == 1)
    #expect(size.height == expectedHeight(longText, width: 240))
}

@MainActor
@Test func componentViewUpdatesEquatableComponentOnceOnAppear() throws {
    let (window, _) = makeWindow(width: 240, rootView: ComponentView(LabelComponent(shortText)))

    let hostView = try #require(descendants(of: SwiftUIComponentHostView<LabelComponent>.self, in: window).first)
    #expect(hostView.updateCount == 1)
}

@MainActor
@Test func intrinsicSizingIsOffWhenSizeThatFitsIsAvailable() {
    guard #available(iOS 16.0, *) else { return }

    let hostView = SwiftUIComponentHostView(LabelComponent(longText))
    hostView.frame = CGRect(x: 0, y: 0, width: 240, height: 10)
    hostView.layoutIfNeeded()

    #expect(!hostView.usesIntrinsicSizing)
    #expect(hostView.intrinsicContentSize.height == UIView.noIntrinsicMetric)
}

/// iOS 15 경로예요. 이 기기의 OS와 상관없이 확인하려고 `usesIntrinsicSizing`을 켜요.
@MainActor
@Test func fallbackIntrinsicSizeUsesLaidOutWidth() {
    let hostView = SwiftUIComponentHostView(LabelComponent(longText))
    hostView.usesIntrinsicSizing = true
    #expect(hostView.intrinsicContentSize.height == UIView.noIntrinsicMetric)

    hostView.frame = CGRect(x: 0, y: 0, width: 240, height: 10)
    hostView.layoutIfNeeded()

    #expect(hostView.intrinsicContentSize.width == UIView.noIntrinsicMetric)
    #expect(hostView.intrinsicContentSize.height == expectedHeight(longText, width: 240))
}
#endif
