//
//  BottomSheetDockAlignment.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/23/26.
//

import Foundation

/// 시트 위에 떠 있는 컨트롤 묶음(도크)을 가로로 어느 쪽에 붙일지 정합니다.
///
/// UIKit `BottomSheetController.attachDock(_:alignment:insets:)`와 SwiftUI `bottomSheetDock(alignment:)`가
/// 같은 값을 씁니다.
public enum BottomSheetDockAlignment: Hashable, Sendable {

    /// 읽기 방향의 앞쪽(한국어·영어에서는 왼쪽)에 붙입니다.
    case leading

    /// 읽기 방향의 뒤쪽(한국어·영어에서는 오른쪽)에 붙입니다. 지도 앱의 현재 위치 버튼이 보통 여기 있어요.
    case trailing
}
