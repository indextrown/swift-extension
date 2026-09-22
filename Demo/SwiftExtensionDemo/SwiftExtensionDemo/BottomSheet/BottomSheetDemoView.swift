//
//  BottomSheetDemoView.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import SwiftUI
import UIKit

/// 바텀시트 데모 화면입니다. UIKit 탭바 컨트롤러를 SwiftUI 화면 안에 띄웁니다.
///
/// 시트가 탭바 뒤에서 올라오는 것을 보여 주려면 진짜 탭바가 있어야 하므로, SwiftUI의 `TabView` 대신
/// `UITabBarController`를 `UIViewControllerContainer`로 감쌉니다.
struct BottomSheetDemoScreen: View {

    /// 탭바를 불투명 벽으로 그릴지, 기본 Liquid Glass 유리창으로 둘지 정합니다.
    ///
    /// 불투명이면 탭바 컨트롤러가 자식 화면을 탭바 윗선까지로 줄이고, 시트는 그 윗선에서 끝납니다.
    /// 기본값이면 자식 화면이 화면 끝까지 내려가고 시트가 유리 너머로 비쳐 보입니다.
    @State private var isOpaqueTabBar = true

    /// 시트 안의 목록을 위로 끌 때 시트가 먼저 올라갈지(Apple 지도 방식), 목록만 스크롤될지 정합니다.
    @State private var scrollingExpandsSheet = false

    var body: some View {
        UIViewControllerContainer {
            Self.makeTabBarController()
        } update: { tabBarController in
            Self.applyTabBarStyle(to: tabBarController, isOpaque: self.isOpaqueTabBar)
            Self.host(in: tabBarController)?.scrollingExpandsSheet = self.scrollingExpandsSheet
        }
        .ignoresSafeArea()
        .navigationTitle("탭바 뒤 바텀시트")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("불투명 탭바", isOn: self.$isOpaqueTabBar)
                    Toggle("스크롤이 시트를 올려요", isOn: self.$scrollingExpandsSheet)
                } label: {
                    Label("옵션", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private static func host(in tabBarController: UITabBarController) -> BottomSheetHostViewController? {
        return tabBarController.viewControllers?.first as? BottomSheetHostViewController
    }

    private static func makeTabBarController() -> UITabBarController {
        let tabBarController = UITabBarController()

        let host = BottomSheetHostViewController()
        host.tabBarItem = UITabBarItem(title: "Map", image: UIImage(systemName: "map"), tag: 0)

        let second = SecondTabViewController()
        second.tabBarItem = UITabBarItem(title: "Second", image: UIImage(systemName: "star"), tag: 1)

        tabBarController.viewControllers = [host, second]

        return tabBarController
    }

    /// `isTranslucent = false`가 탭바를 전폭 불투명 바로 바꾸는 핵심입니다. 색은 따로 정합니다.
    private static func applyTabBarStyle(to tabBarController: UITabBarController, isOpaque: Bool) {
        let tabBar = tabBarController.tabBar

        guard tabBar.isTranslucent == isOpaque else { return }

        tabBar.isTranslucent = isOpaque == false
        tabBar.backgroundColor = isOpaque ? .systemBackground : nil
    }
}



// MARK: - Second Tab

/// 시트를 올려 둔 채로 탭을 옮길 수 있는지 확인하는 용도의 빈 탭입니다.
final class SecondTabViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .systemGroupedBackground

        let label = UILabel()
        label.text = "Second tab"
        label.font = .preferredFont(forTextStyle: .largeTitle)
        label.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        ])
    }
}
