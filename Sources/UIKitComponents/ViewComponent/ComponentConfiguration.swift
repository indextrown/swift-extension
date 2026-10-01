//
//  ComponentConfiguration.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/1/26.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// 컴포넌트를 셀의 `contentConfiguration`에 넣는 설정입니다.
///
/// `UITableViewCell`, `UICollectionViewCell`, `UICollectionViewListCell`에 씁니다.
/// 데이터 소스와 레이아웃은 쓰던 방식을 그대로 둡니다. 셀이 재사용되면 이미 만든 뷰를 그대로 두고
/// `updateView(_:context:)`만 다시 부릅니다. 셀 높이는 뷰의 Auto Layout 제약에서 정해집니다.
///
/// ```swift
/// let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Notice> { cell, _, notice in
///     cell.contentConfiguration = NoticeComponent(title: notice.title).contentConfiguration()
/// }
/// ```
///
/// 셀은 화면 밖으로 스크롤돼도 window에서 빠지지 않습니다. 그래서 이전 갱신의 작업은 셀이 재사용되어
/// 새 설정이 들어오거나, 셀이나 content view가 해제될 때 취소됩니다.
public struct ComponentConfiguration<Component: ViewComponent>: UIContentConfiguration {

    // MARK: - Property

    /// 셀에 표시할 컴포넌트입니다.
    public var component: Component



    // MARK: - Life Cycle

    /// 컴포넌트로 설정을 만듭니다.
    ///
    /// - Parameter component: 셀에 표시할 컴포넌트입니다.
    /// - Complexity: O(1)입니다.
    public init(_ component: Component) {
        self.component = component
    }



    // MARK: - UIContentConfiguration

    /// 이 설정을 표시할 content view를 만듭니다.
    ///
    /// - Returns: 컴포넌트의 뷰를 담은 content view입니다.
    /// - Complexity: `makeView()`와 첫 `updateView(_:context:)`의 비용을 따릅니다.
    public func makeContentView() -> UIView & UIContentView {
        return ComponentContentView(configuration: self)
    }

    /// 셀 상태가 바뀌어도 같은 설정을 돌려줍니다.
    ///
    /// - Parameter state: 셀의 선택·강조 같은 상태입니다. 지금은 쓰지 않습니다.
    /// - Returns: 이 설정 그대로입니다.
    /// - Complexity: O(1)입니다.
    public func updated(for state: UIConfigurationState) -> ComponentConfiguration<Component> {
        return self
    }
}
#endif
