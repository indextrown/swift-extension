//
//  SwiftUIBottomSheetDemoScreen.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import SwiftUI
import SwiftUIExtension

/// SwiftUI 바텀시트 데모입니다. `TabView`의 탭 콘텐츠에 `bottomSheet`를 얹어 탭바 뒤에서 올라오게 합니다.
struct SwiftUIBottomSheetDemoScreen: View {

    private static let layout = BottomSheetLayout.dismissible

    @State private var detent: BottomSheetDetent.Identifier = .tip
    @State private var draggedOffset: CGFloat?

    var body: some View {
        TabView {
            self.mapTab
                .tabItem { Label("Map", systemImage: "map") }

            Text("Second tab")
                .font(.largeTitle)
                .tabItem { Label("Second", systemImage: "star") }
        }
        .navigationTitle("탭바 뒤 바텀시트 (SwiftUI)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var mapTab: some View {
        ZStack(alignment: .topLeading) {
            /// 지도 대용 배경입니다.
            Color(red: 0.62, green: 0.82, blue: 0.75)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 8) {
                Text(self.status)
                    .font(.system(.footnote, design: .monospaced))
                    .lineLimit(2, reservesSpace: true)

                HStack(spacing: 8) {
                    ForEach(Self.layout.detents, id: \.identifier) { candidate in
                        Button(candidate.identifier.rawValue) {
                            self.detent = candidate.identifier
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .foregroundStyle(.blue)
                    }
                }
            }
            .padding(16)
        }
        .bottomSheet(
            detent: self.$detent,
            layout: Self.layout,
            onOffsetChange: { self.draggedOffset = $0 }
        ) {
            BottomSheetScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<40, id: \.self) { row in
                        Text("Row \(row)")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)

                        Divider()
                            .padding(.leading, 20)
                    }
                }
            }
        }
    }

    private var status: String {
        let dragged = self.draggedOffset.map { "dragged=\(Int($0))" } ?? "dragged=-"

        return "detent=\(self.detent.rawValue)\n\(dragged)"
    }
}
