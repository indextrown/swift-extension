//
//  SwiftExtensionDemoApp.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import SwiftUI

/// 패키지의 컴포넌트를 눌러 보는 데모 앱입니다.
///
/// 첫 화면은 데모 목록이고, 셀을 누르면 해당 컴포넌트 화면으로 들어갑니다.
@main
struct SwiftExtensionDemoApp: App {

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                DemoListView()
            }
        }
    }
}
