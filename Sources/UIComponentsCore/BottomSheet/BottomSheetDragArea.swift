//
//  BottomSheetDragArea.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/13/26.
//

import Foundation

/// 손가락으로 끌어 시트를 옮길 수 있는 영역입니다.
///
/// 기본값 `entireSheet`는 시트 어디에서 시작한 끌기든 시트를 움직입니다. `handleAndBackground`는 손잡이 줄과
/// 콘텐츠가 터치를 받지 않는 시트 배경에서 시작한 끌기만 시트를 움직이고, 글자·버튼·목록처럼 콘텐츠가 받는 끌기는
/// 콘텐츠의 스크롤과 제스처에 맡깁니다. lucaszischka/BottomSheet의 기본 동작(`isContentDragEnabled == false`)과 같습니다.
///
/// 어느 값에서든 끌기 손잡이로 지정한 View(UIKit `UIView.isBottomSheetDragHandle`, SwiftUI
/// `View.bottomSheetDragHandle(_:)`)는 손잡이처럼 시트를 움직입니다. 어느 쪽이 받을지는 손가락이 처음 닿은 자리로
/// 정하고 손을 뗄 때까지 바꾸지 않습니다. 가로로 끄는 동작은 어느 값에서든 시트가 받지 않습니다.
///
/// UIKit `BottomSheetController`와 SwiftUI `bottomSheet(detent:)`는 `UIComponentsCore`의 같은 판단 규칙을 쓰지만,
/// "콘텐츠가 터치를 받지 않는 배경"을 가리는 기준은 프레임워크를 따릅니다. 두 판 모두 컨트롤·스크롤뷰·제스처가 붙은
/// View는 터치를 받고, 글자처럼 제스처가 없는 View는 빈 배경처럼 끌립니다.
///
/// 값이 늘어나도 쓰는 쪽의 `switch`가 깨지지 않도록 열거형이 아니라 정적 값을 가진 구조체로 두었습니다.
/// 정해 둔 값만 만들 수 있고, 비교는 `==`로 합니다.
///
/// ```swift
/// let behavior = BottomSheetBehavior(dragArea: .handleAndBackground)
/// ```
///
/// - Complexity: 비교와 해시는 O(1)입니다.
public struct BottomSheetDragArea: Hashable, Sendable {

    // MARK: - Value

    /// 시트 어디에서 시작한 끌기든 시트를 움직입니다. 기본값입니다.
    ///
    /// 시트가 따라가는 스크롤뷰(UIKit `track(scrollView:)`, SwiftUI `BottomSheetScrollView`) 위에서 시작한 끌기는
    /// `BottomSheetBehavior.scrollingExpandsSheet` 규칙에 따라 시트와 스크롤이 나눠 받습니다. 손잡이 줄, 빈 배경,
    /// 끌기 손잡이로 지정한 View에서 시작한 끌기는 그 규칙과 상관없이 시트만 움직입니다.
    ///
    /// SwiftUI에서 일반 `ScrollView`·`List` 위를 끌면 스크롤과 시트가 함께 움직이므로, 그런 콘텐츠에는
    /// `handleAndBackground`를 씁니다. SwiftUI는 콘텐츠 안의 위치를 몰라서, `BottomSheetScrollView`가 있으면 그 밖의
    /// 그려진 View(제목 글자 등)에서 시작한 끌기도 따라가는 스크롤 규칙을 따릅니다. 제목줄이 언제나 시트를 움직이게 하려면
    /// 제목줄에 `bottomSheetDragHandle(_:)`을 붙입니다.
    public static let entireSheet = BottomSheetDragArea(kind: .entireSheet)

    /// 손잡이 줄과, 콘텐츠가 터치를 받지 않는 시트 배경에서 시작한 끌기만 시트를 움직입니다.
    ///
    /// 콘텐츠가 받는 끌기는 시트가 받지 않으므로 안쪽 스크롤뷰는 시트가 어느 단계에 있든 스크롤만 하고, 맨 위에서
    /// 아래로 끌어도 시트로 넘어오지 않습니다. 이 값에서는 `BottomSheetBehavior.scrollingExpandsSheet`를 쓰지 않습니다.
    ///
    /// 빈 배경은 SwiftUI에서는 `padding`, 스택 간격, `Spacer`, 짧은 콘텐츠 아래, 제스처가 없는 `Text`처럼 시트 배경의
    /// 제스처를 가로막지 않는 곳입니다. UIKit에서는 손가락이 닿은 View에서 시트까지 `UIControl`·`UIScrollView`·켜진
    /// 제스처 인식기가 없는 곳(빈 View, 스택뷰 간격, `UILabel`·`UIImageView` 위)이고, 콘텐츠 화면의 루트 View에 붙은
    /// 제스처 인식기는 보지 않습니다.
    /// UIKit 시트에 넣은 SwiftUI 콘텐츠(`UIHostingController`)는 안쪽을 가릴 수 없어 전부 콘텐츠로 봅니다.
    /// SwiftUI 콘텐츠 전체에 배경색을 칠하면 빈 배경이 사라지므로 시트 색은 `BottomSheetStyle.background`에 칠합니다.
    ///
    /// 손잡이 줄은 시트 너비 × `handleAreaHeight`(기본 28pt)입니다. 콘텐츠가 시트를 가득 채우면 손으로 끌 곳이 손잡이
    /// 줄뿐이므로, `handleAreaHeight`를 36~44pt로 키우거나 제목줄을 끌기 손잡이로 지정합니다. 손잡이를 숨겨도
    /// (`showsGrabber == false`) 빈 배경과 지정한 View로는 끌 수 있습니다.
    public static let handleAndBackground = BottomSheetDragArea(kind: .handleAndBackground)



    // MARK: - Property

    /// 두 UI 타깃이 값을 구분할 때 쓰는 표현입니다. 패키지 밖에는 보이지 않습니다.
    ///
    /// 패키지 안에서는 이 값을 `switch`로 빠짐없이 나눕니다. 경우를 더하면 처리하지 않은 판단 함수가
    /// 컴파일 오류로 드러나, UIKit과 SwiftUI 양쪽에 구현했는지 컴파일러가 확인합니다.
    package enum Kind: Hashable, Sendable {

        case entireSheet

        case handleAndBackground
    }

    /// 이 값이 나타내는 영역입니다.
    package let kind: Kind



    // MARK: - Life Cycle

    private init(kind: Kind) {
        self.kind = kind
    }
}
