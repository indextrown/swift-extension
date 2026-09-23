//
//  BottomSheetDockVisibility.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/23/26.
//

import Foundation

/// 도크 항목이 시트의 어느 단계에서 보일지 정합니다.
///
/// "시트가 내려가 있을 때만 보이는 올리기 버튼"처럼 단계에 따라 나타나고 사라지는 컨트롤을 만들 때 써요.
/// 판단은 시트가 **머무는 단계**(도착 단계) 기준이에요. 손을 뗀 순간 도착 단계가 정해지면 시트가 움직이는
/// 동안 항목이 함께 나타나거나 사라져요.
///
/// ```swift
/// // UIKit
/// dock.setVisibility(.whenHidden, for: openButton)
///
/// // SwiftUI
/// Button { ... }.bottomSheetDockVisibility(.whenHidden)
/// ```
public enum BottomSheetDockVisibility: Hashable, Sendable {

    /// 항상 보입니다. 기본값이에요.
    case always

    /// 이 단계들에서만 보입니다.
    case only(Set<BottomSheetDetent.Identifier>)

    /// 이 단계들에서만 숨습니다.
    case except(Set<BottomSheetDetent.Identifier>)

    /// 시트가 `hidden`일 때만 보입니다. 시트를 다시 올리는 버튼에 써요.
    public static let whenHidden: BottomSheetDockVisibility = .only([.hidden])

    /// 시트가 `hidden`이 아닐 때만 보입니다.
    public static let unlessHidden: BottomSheetDockVisibility = .except([.hidden])

    /// 주어진 단계에서 보이는지 판단합니다.
    ///
    /// - Parameter detent: 시트가 머무는 단계의 이름입니다.
    /// - Complexity: O(1)입니다.
    public func isVisible(at detent: BottomSheetDetent.Identifier) -> Bool {
        switch self {
        case .always:
            return true

        case .only(let detents):
            return detents.contains(detent)

        case .except(let detents):
            return detents.contains(detent) == false
        }
    }
}
