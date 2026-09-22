//
//  BottomSheetDetent.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import Foundation

/// 바텀시트가 멈출 수 있는 높이 단계입니다.
///
/// 시트는 레이아웃에 등록된 단계에서만 멈춥니다. 손을 뗀 위치가 어디든 가장 가까운
/// 단계로 이동합니다. 단계를 값으로 두면 지도 카메라 여백처럼 시트 높이에 맞춰야 하는
/// 값을 단계별로 정할 수 있습니다.
///
/// 단계는 `Identifier`로 구분합니다. 자주 쓰는 단계는 `tip`, `half`, `full`, `hidden`으로
/// 미리 정의해 두었고, 화면마다 필요한 단계는 문자열 리터럴로 새로 만들 수 있습니다.
///
/// ```swift
/// let compact = BottomSheetDetent("compact", anchor: .height(220))
/// ```
public struct BottomSheetDetent: Hashable, Sendable {

    /// 단계를 구분하는 이름입니다.
    public struct Identifier: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {

        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: String) {
            self.rawValue = value
        }

        /// 화면 밖으로 완전히 내려간 단계입니다.
        public static let hidden: Identifier = "hidden"

        /// 손잡이와 요약 한 줄만 보이는 가장 낮은 단계입니다.
        public static let tip: Identifier = "tip"

        /// 화면의 일부를 차지하는 중간 단계입니다.
        public static let half: Identifier = "half"

        /// 위쪽 여백만 남기고 모두 채우는 가장 높은 단계입니다.
        public static let full: Identifier = "full"
    }

    /// 단계의 이름입니다. 한 레이아웃 안에서 겹치지 않아야 합니다.
    public let identifier: Identifier

    /// 이 단계의 높이를 재는 방법입니다.
    public let anchor: BottomSheetAnchor

    /// 이름과 높이 기준으로 단계를 만듭니다.
    ///
    /// - Parameters:
    ///   - identifier: 단계의 이름입니다.
    ///   - anchor: 높이를 재는 방법입니다.
    public init(_ identifier: Identifier, anchor: BottomSheetAnchor) {
        self.identifier = identifier
        self.anchor = anchor
    }
}



// MARK: - Presets

extension BottomSheetDetent {

    /// 화면 밖으로 완전히 내려가 손잡이까지 사라지는 단계입니다.
    public static let hidden = BottomSheetDetent(.hidden, anchor: .hidden)

    /// 손잡이와 요약 한 줄만 보이는 단계입니다.
    ///
    /// - Parameter height: 바닥에서 보일 높이입니다. 기본값은 96pt입니다.
    public static func tip(height: CGFloat = 96) -> BottomSheetDetent {
        return BottomSheetDetent(.tip, anchor: .height(height))
    }

    /// 화면 일부를 차지하는 단계입니다.
    ///
    /// - Parameter fraction: 쓸 수 있는 높이에 대한 비율입니다. 기본값은 0.5입니다.
    public static func half(fraction: CGFloat = 0.5) -> BottomSheetDetent {
        return BottomSheetDetent(.half, anchor: .fraction(fraction))
    }

    /// 위쪽 여백만 남기고 모두 채우는 단계입니다.
    ///
    /// - Parameter topInset: 안전 영역 위쪽에서 남길 여백입니다. 기본값은 16pt입니다.
    public static func full(topInset: CGFloat = 16) -> BottomSheetDetent {
        return BottomSheetDetent(.full, anchor: .topInset(topInset))
    }
}
