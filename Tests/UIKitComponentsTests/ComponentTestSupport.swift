#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import SwiftUI
import UIKit
@testable import UIKitComponents

/// 호출 횟수를 여러 컴포넌트 값이 함께 세는 참조 타입이에요.
final class Counter {
    var value = 0
}

/// 마지막 갱신의 context를 테스트 밖에서 잡아 두는 상자예요.
final class ContextBox {
    var context: ComponentContext?
}

/// 여러 줄 레이블 하나를 네 변 8pt 여백으로 담은 뷰예요. 크기를 잰 횟수를 `fittingCount`로 세요.
final class LabelView: UIView {
    let label = UILabel()
    private(set) var fittingCount = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.label.numberOfLines = 0
        self.label.font = .systemFont(ofSize: 17)
        self.label.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.label)
        NSLayoutConstraint.activate([
            self.label.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
            self.label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            self.label.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -8),
            self.label.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:)는 지원하지 않습니다.")
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        self.fittingCount += 1
        return super.systemLayoutSizeFitting(targetSize)
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        self.fittingCount += 1
        return super.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: horizontalFittingPriority,
            verticalFittingPriority: verticalFittingPriority
        )
    }
}

/// 글자만 비교하는 `Equatable` 컴포넌트예요. 뷰를 만든 횟수는 `makeCounter`로 세요.
struct LabelComponent: ViewComponent, Equatable {
    let text: String
    let makeCounter: Counter
    let contextBox: ContextBox?

    init(
        _ text: String,
        makeCounter: Counter = Counter(),
        contextBox: ContextBox? = nil
    ) {
        self.text = text
        self.makeCounter = makeCounter
        self.contextBox = contextBox
    }

    static func == (lhs: LabelComponent, rhs: LabelComponent) -> Bool {
        return lhs.text == rhs.text
    }

    func makeView() -> LabelView {
        self.makeCounter.value += 1
        return LabelView()
    }

    func updateView(_ view: LabelView, context: ComponentContext) {
        view.label.text = self.text
        self.contextBox?.context = context
    }
}

/// `View`를 함께 채택하면 SwiftUI에 바로 넣을 수 있는지 확인해요.
extension LabelComponent: View {}

/// 클로저를 담아 `Equatable`이 아닌 컴포넌트예요.
struct ClosureComponent: ViewComponent {
    let text: String
    let onUpdate: () -> Void

    func makeView() -> LabelView {
        return LabelView()
    }

    func updateView(_ view: LabelView, context: ComponentContext) {
        view.label.text = self.text
        self.onUpdate()
    }
}

/// 갱신마다 정리 동작을 등록하고, 정리된 횟수를 세는 컴포넌트예요.
struct CancellationComponent: ViewComponent {
    let cancellations: Counter

    func makeView() -> UIView {
        return UIView()
    }

    func updateView(_ view: UIView, context: ComponentContext) {
        context.onCancel { self.cancellations.value += 1 }
    }
}

let longText = String(repeating: "가나다라마바사 아자차카 ", count: 12)
let shortText = "짧은 글"

/// 같은 글을 담은 `LabelView`가 주어진 너비에서 필요로 하는 높이예요.
@MainActor
func expectedHeight(_ text: String, width: CGFloat) -> CGFloat {
    let view = LabelView()
    view.label.text = text
    let size = view.systemLayoutSizeFitting(
        CGSize(width: width, height: 0),
        withHorizontalFittingPriority: .required,
        verticalFittingPriority: .fittingSizeLevel
    )
    return ceil(size.height)
}

/// 창에 붙인 뷰가 배치를 마치도록 런루프를 몇 번 돌려요.
@MainActor
func runLayout(_ window: UIWindow) {
    for _ in 0..<5 {
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
}

/// SwiftUI 뷰를 주어진 너비의 창에 띄워요.
@MainActor
func makeWindow<Content: View>(
    width: CGFloat,
    rootView: Content
) -> (UIWindow, UIHostingController<Content>) {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 3000))
    let hostingController = UIHostingController(rootView: rootView)
    window.rootViewController = hostingController
    window.makeKeyAndVisible()
    runLayout(window)
    return (window, hostingController)
}

/// 뷰 계층에서 주어진 타입의 뷰를 모두 찾아요.
@MainActor
func descendants<View: UIView>(
    of type: View.Type,
    in root: UIView
) -> [View] {
    let current = (root as? View).map { [$0] } ?? []
    return current + root.subviews.flatMap { descendants(of: type, in: $0) }
}
#endif
