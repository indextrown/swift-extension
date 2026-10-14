#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import SwiftUI
import Testing
import UIKit
@testable import UIKitExtension

/// SwiftUI가 그리는 콘텐츠는 글자·버튼·스크롤뷰가 모두 호스팅 View 하나로 hit-test돼요.
/// UIKit이 빈 곳을 가릴 수 없어, 빈 배경으로 보면 SwiftUI 스크롤과 시트 끌기가 경쟁해요.
@Test("UIKit 시트 안의 SwiftUI 콘텐츠는 어디를 끌어도 콘텐츠예요") @MainActor
func swiftUIHostingContentIsContent() {
    let hosting = UIHostingController(rootView:
        VStack(alignment: .leading, spacing: 40) {
            Text("지역 선택").font(.title)
            Button("초기화") {}
            ScrollView { VStack { ForEach(0..<40) { Text("행 \($0)") } } }.frame(height: 200)
            Spacer()
        }
        .padding(24)
    )
    let sheet = BottomSheetController(
        contentViewController: hosting,
        initialDetent: .full,
        behavior: BottomSheetBehavior(animatesInitialAppearance: false, dragArea: .handleAndBackground)
    )
    let host = UIViewController()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = host
    window.makeKeyAndVisible()
    sheet.add(to: host)
    host.view.layoutIfNeeded()
    hosting.view.layoutIfNeeded()

    /// 제목 글자, 제목 옆 빈 곳, 버튼, 스크롤뷰, 아래 빈 곳이에요.
    let points = [CGPoint(x: 40, y: 40), CGPoint(x: 300, y: 40), CGPoint(x: 40, y: 110), CGPoint(x: 100, y: 250), CGPoint(x: 200, y: 600)]

    for local in points {
        let point = hosting.view.convert(local, to: sheet.view)
        let origin = sheet.classifyDragOrigin(hitView: sheet.view.hitTest(point, with: nil), location: point)

        #expect(origin == .content, "\(local)")
        #expect(sheet.behavior.acceptsDrag(from: origin) == false)
    }

    /// 손잡이는 그대로 손잡이예요.
    let handlePoint = CGPoint(x: 195, y: 10)
    #expect(sheet.classifyDragOrigin(hitView: sheet.view.hitTest(handlePoint, with: nil), location: handlePoint) == .handle)

    sheet.remove()
    window.isHidden = true
}
#endif
