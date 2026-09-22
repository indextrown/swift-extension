//
//  DemoItem.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import SwiftUI

/// 데모 목록의 한 행입니다.
///
/// 목적지는 SwiftUI View든 UIKit 뷰컨트롤러든 상관없습니다. UIKit이면
/// `UIViewControllerContainer`나 `UIViewContainer`로 감싸서 넘깁니다.
struct DemoItem: Identifiable {

    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let destination: () -> AnyView

    init<Destination: View>(
        id: String,
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.destination = { AnyView(destination()) }
    }
}



// MARK: - Catalog

/// 목적지 클로저가 View를 만들므로 카탈로그는 메인 액터에 묶습니다.
@MainActor
extension DemoItem {

    /// `UIKitExtension` 컴포넌트 데모입니다.
    static let uiKit: [DemoItem] = [
        DemoItem(
            id: "bottom-sheet",
            title: "탭바 뒤 바텀시트",
            subtitle: "BottomSheetController · UIKit",
            systemImage: "rectangle.bottomthird.inset.filled"
        ) {
            BottomSheetDemoScreen()
        }
    ]

    /// `SwiftUIExtension` 컴포넌트 데모입니다.
    static let swiftUI: [DemoItem] = [
        DemoItem(
            id: "bottom-sheet-swiftui",
            title: "탭바 뒤 바텀시트",
            subtitle: "bottomSheet(detent:) · SwiftUI",
            systemImage: "rectangle.bottomthird.inset.filled"
        ) {
            SwiftUIBottomSheetDemoScreen()
        }
    ]
}
