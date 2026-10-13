//
//  UIView+BottomSheetDragHandle.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/13/26.
//

#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import ObjectiveC
import UIKit

extension UIView {

    /// 이 View에서 시작한 끌기로 바깥 바텀시트를 옮길지 나타냅니다. 기본값은 `false`입니다.
    ///
    /// `true`면 이 View와 하위 View에서 시작한 세로 끌기는, 이 View를 품은 가장 가까운 `BottomSheetController`의 손잡이처럼
    /// 시트를 움직입니다. `behavior.dragArea`와 상관없고 따라가는 스크롤뷰와 엮이지 않습니다. 안쪽의 버튼·스크롤뷰·제스처
    /// View는 자기 터치를 지켜, 그 위에서 시작한 끌기는 시트가 받지 않습니다. SwiftUI `bottomSheetDragHandle(_:)`과
    /// lucaszischka/BottomSheet의 헤더와 같습니다.
    ///
    /// 탭 제스처가 달린 제목줄처럼 그 자체가 터치를 받아 빈 배경으로 보지 않는 View를 끌기 영역에 더하거나, 따라가는
    /// 스크롤뷰 안의 제목줄을 스크롤과 엮지 않고 시트만 움직이게 할 때 씁니다. 라벨과 스택뷰로만 된 제목줄은 지정하지
    /// 않아도 빈 배경으로 끌립니다.
    ///
    /// 손가락에서 가까운 표시가 이깁니다. 이 View 안의 따라가는 스크롤뷰는 스크롤뷰 규칙을 따릅니다. 세로 스크롤뷰를 품은
    /// View에 지정하면 그 스크롤뷰 위는 스크롤만 합니다. `UILabel`·`UIImageView`처럼 `isUserInteractionEnabled`가
    /// `false`인 View는 터치를 받지 않아 효과가 없으니 감싸는 View에 지정합니다. 시트 밖 View에서는 아무 일도 하지 않습니다.
    /// VoiceOver 요소는 바꾸지 않습니다.
    ///
    /// ```swift
    /// headerView.isBottomSheetDragHandle = true
    /// ```
    ///
    /// - Complexity: 읽기와 쓰기는 O(1)입니다.
    public var isBottomSheetDragHandle: Bool {
        get {
            return objc_getAssociatedObject(self, &BottomSheetDragHandleKey.value) != nil
        }
        set {
            objc_setAssociatedObject(
                self,
                &BottomSheetDragHandleKey.value,
                newValue ? NSNumber(value: true) : nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

/// `isBottomSheetDragHandle`을 붙여 두는 키입니다. 주소만 씁니다.
@MainActor
private enum BottomSheetDragHandleKey {

    static var value: UInt8 = 0
}
#endif
