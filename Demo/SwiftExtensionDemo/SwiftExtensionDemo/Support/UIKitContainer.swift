//
//  UIKitContainer.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import SwiftUI
import UIKit

/// UIKit 뷰컨트롤러를 SwiftUI 화면으로 쓰는 범용 포장입니다.
///
/// 데모 목록의 셀은 SwiftUI View든 UIKit 뷰컨트롤러든 넣을 수 있어야 합니다.
/// UIKit 쪽은 이 컨테이너로 감싸면 `NavigationLink`의 목적지로 바로 쓸 수 있습니다.
///
/// ```swift
/// UIViewControllerContainer { MyViewController() }
/// ```
struct UIViewControllerContainer<Controller: UIViewController>: UIViewControllerRepresentable {

    private let make: () -> Controller
    private let update: (Controller) -> Void

    /// - Parameters:
    ///   - make: 뷰컨트롤러를 처음 만들 때 한 번 호출합니다.
    ///   - update: SwiftUI 상태가 바뀔 때마다 호출합니다. 상태를 UIKit 쪽에 반영하는 데 씁니다.
    init(
        make: @escaping () -> Controller,
        update: @escaping (Controller) -> Void = { _ in }
    ) {
        self.make = make
        self.update = update
    }

    func makeUIViewController(context: Context) -> Controller {
        return self.make()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        self.update(controller)
    }
}



// MARK: - UIView

/// UIKit View 하나를 SwiftUI 화면으로 쓰는 범용 포장입니다.
///
/// 뷰컨트롤러 없이 View만 있는 컴포넌트를 목록에 올릴 때 씁니다.
struct UIViewContainer<Wrapped: UIView>: UIViewRepresentable {

    private let make: () -> Wrapped
    private let update: (Wrapped) -> Void

    init(
        make: @escaping () -> Wrapped,
        update: @escaping (Wrapped) -> Void = { _ in }
    ) {
        self.make = make
        self.update = update
    }

    func makeUIView(context: Context) -> Wrapped {
        return self.make()
    }

    func updateUIView(_ view: Wrapped, context: Context) {
        self.update(view)
    }
}
