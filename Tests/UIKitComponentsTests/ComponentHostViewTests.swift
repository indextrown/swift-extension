#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import Testing
import UIKit
@testable import UIKitComponents

@MainActor
@Test func hostViewMakesViewOnceAcrossUpdates() {
    let makeCounter = Counter()
    let hostView = ComponentHostView(LabelComponent("a", makeCounter: makeCounter))

    hostView.update(LabelComponent("b", makeCounter: makeCounter))
    hostView.update(LabelComponent("c", makeCounter: makeCounter))

    #expect(makeCounter.value == 1)
    #expect(hostView.hostedView.label.text == "c")
    #expect(hostView.component.text == "c")
}

@MainActor
@Test func hostViewSkipsUpdateForEqualComponent() {
    let hostView = ComponentHostView(LabelComponent("a"))

    hostView.update(LabelComponent("a"))
    #expect(hostView.updateCount == 1)

    hostView.update(LabelComponent("b"))
    #expect(hostView.updateCount == 2)
}

@MainActor
@Test func hostViewUpdatesNonEquatableComponentEveryTime() {
    var updates = 0
    let hostView = ComponentHostView(ClosureComponent(text: "a") { updates += 1 })

    hostView.update(ClosureComponent(text: "a") { updates += 1 })
    hostView.update(ClosureComponent(text: "a") { updates += 1 })

    #expect(updates == 3)
}

@MainActor
@Test func hostViewCancelsPreviousContextOnUpdate() {
    let cancellations = Counter()
    let hostView = ComponentHostView(CancellationComponent(cancellations: cancellations))

    hostView.update(CancellationComponent(cancellations: cancellations))

    #expect(cancellations.value == 1)
}

@MainActor
@Test func hostViewCancelsWhenLeavingWindowAndUpdatesWhenBack() {
    let cancellations = Counter()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 240, height: 400))
    window.makeKeyAndVisible()
    let hostView = ComponentHostView(CancellationComponent(cancellations: cancellations))

    window.addSubview(hostView)
    #expect(hostView.updateCount == 1)

    hostView.removeFromSuperview()
    #expect(cancellations.value == 1)

    window.addSubview(hostView)
    #expect(hostView.updateCount == 2)
}

@MainActor
@Test("Auto Layout으로 붙이면 너비에 맞는 높이를 가져요", arguments: [longText, shortText, ""])
func hostViewFitsContentHeightWithAutoLayout(text: String) {
    let container = UIView(frame: CGRect(x: 0, y: 0, width: 240, height: 2000))
    let hostView = ComponentHostView(LabelComponent(text))
    hostView.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(hostView)
    NSLayoutConstraint.activate([
        hostView.topAnchor.constraint(equalTo: container.topAnchor),
        hostView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        hostView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
    ])

    container.layoutIfNeeded()

    #expect(hostView.frame.width == 240)
    #expect(abs(hostView.frame.height - expectedHeight(text, width: 240)) < 1)
}

@MainActor
@Test func hostViewSizeThatFitsUsesProposedWidth() {
    let hostView = ComponentHostView(LabelComponent(longText))

    let size = hostView.sizeThatFits(CGSize(width: 240, height: 0))

    #expect(size.width == 240)
    #expect(size.height == expectedHeight(longText, width: 240))
}

@MainActor
@Test("너비가 없으면 자연 크기를 돌려줘요", arguments: [0, CGFloat.infinity])
func hostViewSizeThatFitsReturnsNaturalSizeWithoutWidth(width: CGFloat) {
    let hostView = ComponentHostView(LabelComponent(shortText))

    let size = hostView.sizeThatFits(CGSize(width: width, height: 0))

    #expect(size.width > 0)
    #expect(size.width.isFinite)
    #expect(size.height > 0)
}

@MainActor
@Test func hostViewsInFixedHeightStackViewHaveNoAmbiguousLayout() {
    let stackView = UIStackView(arrangedSubviews: [
        ComponentHostView(LabelComponent(longText)),
        ComponentHostView(LabelComponent(shortText)),
    ])
    stackView.axis = .vertical
    stackView.frame = CGRect(x: 0, y: 0, width: 240, height: 900)

    stackView.layoutIfNeeded()

    #expect(stackView.arrangedSubviews.allSatisfy { !$0.hasAmbiguousLayout })
    #expect(stackView.arrangedSubviews[0].frame.height >= expectedHeight(longText, width: 240) - 1)
}
#endif
