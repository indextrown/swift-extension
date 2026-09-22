//
//  BottomSheetAnchor.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import Foundation

/// 시트가 멈출 높이를 재는 방법입니다.
///
/// 단계마다 기준이 다릅니다. 손잡이와 요약 한 줄만 보이는 단계는 글자 높이가 기준이라
/// 화면이 커져도 같은 크기여야 하고, 절반을 차지하는 단계는 화면 비중이 기준입니다.
/// 재는 방법을 값으로 두어 단계마다 하나를 고르게 합니다.
///
/// 모든 계산 결과는 `offset`입니다. 부모 화면의 안전 영역 위쪽 끝에서 시트 위쪽 끝까지의
/// 거리이며, 값이 클수록 시트가 아래에 있습니다.
public enum BottomSheetAnchor: Hashable, Sendable {

    /// 바닥에서 시트가 차지할 높이를 pt로 정합니다.
    ///
    /// 기기가 달라도 보이는 크기가 같습니다.
    case height(CGFloat)

    /// 쓸 수 있는 높이에 대한 비율로 정합니다. `0...1` 범위를 기대합니다.
    ///
    /// 기기가 달라도 화면에서 차지하는 비중이 같습니다.
    case fraction(CGFloat)

    /// 위쪽에 남길 여백을 pt로 정합니다.
    case topInset(CGFloat)

    /// 화면 밖으로 완전히 내립니다.
    ///
    /// 끌어 올릴 손잡이까지 사라지므로 시트로 돌아올 조작을 화면이 따로 마련해야 합니다.
    case hidden

    /// 콘텐츠가 실제로 차지하는 높이만큼만 올립니다. 카드 몇 장처럼 스크롤이 필요 없는 콘텐츠를
    /// 아래 여백 없이 딱 맞게 보일 때 씁니다.
    ///
    /// 콘텐츠 높이는 이 타입이 알 수 없어 UI 계층(`BottomSheetController`, `bottomSheet(detent:)`)이
    /// 재서 `BottomSheetLayout.resolvingContentHeight(_:)`로 `height`로 바꿔 넣습니다. 재기 전에는
    /// `padding`만큼만 보이는 것으로 계산합니다. 콘텐츠가 바뀌면 다시 재서 자리를 옮깁니다.
    ///
    /// - Parameter padding: 콘텐츠 아래에 더 남길 여백입니다. 손잡이 높이는 UI 계층이 알아서 더합니다.
    case content(padding: CGFloat = 0)
}



// MARK: - Offset

extension BottomSheetAnchor {

    /// 재는 방법을 실제 offset으로 바꿉니다.
    ///
    /// 결과는 `0...availableHeight` 범위로 잘라 냅니다. 화면이 좁아 요청한 높이가
    /// 쓸 수 있는 높이를 넘어도 시트가 안전 영역 위로 튀어 나가지 않습니다.
    ///
    /// - Parameter availableHeight: 시트가 쓸 수 있는 안전 영역의 높이입니다.
    /// - Returns: 안전 영역 위쪽 끝에서 시트 위쪽 끝까지의 거리입니다.
    /// - Complexity: O(1)입니다.
    public func offset(in availableHeight: CGFloat) -> CGFloat {
        let raw: CGFloat

        switch self {
        case .height(let height):
            raw = availableHeight - height

        case .fraction(let fraction):
            raw = availableHeight * (1 - fraction)

        case .topInset(let inset):
            raw = inset

        case .hidden:
            raw = availableHeight

        case .content(let padding):
            raw = availableHeight - padding
        }

        return min(max(raw, 0), max(availableHeight, 0))
    }

    /// 콘텐츠 높이를 재야 하는 anchor인지 나타냅니다.
    public var isContentSized: Bool {
        if case .content = self {
            return true
        }

        return false
    }
}
