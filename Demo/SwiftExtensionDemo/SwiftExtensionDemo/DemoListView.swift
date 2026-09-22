//
//  DemoListView.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import SwiftUI

/// 데모 목록입니다. 행은 `DemoItem` 카탈로그에서 옵니다.
struct DemoListView: View {

    var body: some View {
        List {
            self.section(title: "UIKitExtension", items: DemoItem.uiKit)
            self.section(title: "SwiftUIExtension", items: DemoItem.swiftUI)
        }
        .navigationTitle("SwiftExtension")
    }

    @ViewBuilder
    private func section(title: String, items: [DemoItem]) -> some View {
        Section(title) {
            if items.isEmpty {
                Text("아직 컴포넌트가 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    NavigationLink {
                        item.destination()
                    } label: {
                        DemoRow(item: item)
                    }
                }
            }
        }
    }
}



// MARK: - Row

private struct DemoRow: View {

    let item: DemoItem

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(self.item.title)
                Text(self.item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: self.item.systemImage)
        }
    }
}



// MARK: - Preview

#Preview {
    NavigationStack {
        DemoListView()
    }
}
