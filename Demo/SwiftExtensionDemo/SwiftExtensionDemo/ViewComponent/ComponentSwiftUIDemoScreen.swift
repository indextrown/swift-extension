//
//  ComponentSwiftUIDemoScreen.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/1/26.
//

import SwiftUI
import UIKitComponents

/// UIKit 화면과 같은 컴포넌트를 SwiftUI에 넣는 데모 화면입니다.
///
/// 어느 컴포넌트에도 `.frame(height:)`를 붙이지 않았어요. 높이는 제안받은 너비에서 뷰가 잰 값이에요.
struct ComponentSwiftUIDemoScreen: View {

    @State private var isExpanded = false
    @State private var isAlarmOn = true

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("글 길이", selection: self.$isExpanded) {
                    Text("짧게").tag(false)
                    Text("길게").tag(true)
                }
                .pickerStyle(.segmented)

                /// `View`를 함께 채택한 컴포넌트는 그대로 넣어요.
                Notice.headline.component(isExpanded: self.isExpanded)

                /// 채택하지 않은 컴포넌트는 `ComponentView`로 감싸요. 스위치 값은 `@State`와 주고받아요.
                ComponentView(
                    ToggleRowComponent(
                        title: self.isAlarmOn ? "알림을 받고 있어요" : "알림을 껐어요",
                        isOn: self.isAlarmOn
                    ) { isOn in
                        self.isAlarmOn = isOn
                    }
                )

                LazyVStack(spacing: 12) {
                    ForEach(Notice.samples) { notice in
                        notice.component(isExpanded: self.isExpanded)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("SwiftUI에서 쓰기")
        .navigationBarTitleDisplayMode(.inline)
    }
}



// MARK: - Preview

#Preview {
    NavigationStack {
        ComponentSwiftUIDemoScreen()
    }
}
