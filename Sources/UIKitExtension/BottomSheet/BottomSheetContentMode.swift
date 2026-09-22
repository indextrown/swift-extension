//
//  BottomSheetContentMode.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import UIKit

/// 시트가 움직일 때 콘텐츠 높이를 어떻게 다룰지 정합니다.
///
/// 손으로 끄는 동안 시트는 매 프레임 자리를 옮깁니다. 그때 콘텐츠 높이까지 함께 바뀌면
/// 그 안의 `UITableView`가 매 프레임 셀을 다시 배치해 버벅입니다. 버튼으로 옮길 때는
/// Core Animation이 레이어를 보간해 배치가 한 번만 돌아서 부드럽고, 끌 때만 딱딱해지는 이유가
/// 이것입니다.
public enum BottomSheetContentMode: Sendable {

    /// 콘텐츠 높이를 **가장 높은 단계 기준으로 고정**하고 시트만 옮깁니다. 기본값입니다.
    ///
    /// 낮은 단계에서는 콘텐츠 아랫부분이 화면 밖으로 나가 있습니다. 끄는 동안 콘텐츠가
    /// 다시 배치되지 않아 부드럽습니다. 콘텐츠가 `safeAreaLayoutGuide`를 쓰면 가장 높은 단계에서
    /// 마지막 줄까지 탭바 위에 보입니다.
    case `static`

    /// 콘텐츠 높이를 **시트 높이에 맞춰** 늘리고 줄입니다.
    ///
    /// 낮은 단계에서도 콘텐츠가 자기 크기를 다 알아야 할 때 씁니다. 예를 들어 내용을 세로로
    /// 가운데 맞추는 화면입니다. 끄는 동안 매 프레임 Auto Layout이 돌아서 무거운 콘텐츠는 버벅일 수 있습니다.
    case fitToBounds
}
#endif
