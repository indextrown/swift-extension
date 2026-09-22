//
//  SwiftUINativeSheetDemoScreen.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/23/26.
//

import MapKit
import SwiftUI

/// 애플이 제공하는 SwiftUI `.sheet`를 같은 `TabView` 구성 안에서 띄우는 비교용 화면입니다.
///
/// `bottomSheet(detent:)`와 달리 **모달**이라 탭바 위를 덮어요. 화면이 열리면 기본 탭바가 먼저 보이고,
/// `시트 열기`를 누르면 시트가 탭바를 덮어 탭을 바꿀 수 없게 돼요. 시트 위치를 프레임마다 알려 주는 방법이 없어
/// 지도가 시트를 따라가지 않아요. 단계는 커스텀 시트와 같은 96pt·medium·large로 맞췄어요.
struct SwiftUINativeSheetDemoScreen: View {

    private static let tip = PresentationDetent.height(96)

    @State private var viewModel = MapDemoViewModel()
    @State private var isPresented = false
    @State private var detent: PresentationDetent = Self.tip
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        TabView {
            self.mapTab
                .tabItem { Label("Map", systemImage: "map") }

            Text("Second tab")
                .font(.largeTitle)
                .tabItem { Label("Second", systemImage: "star") }
        }
        .navigationTitle("애플 기본 시트 (SwiftUI)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            self.viewModel.start()
        }
        /// 뒤로 가면 시트도 함께 닫습니다. 모달은 이 화면이 아니라 창에 붙어 있어요.
        .onDisappear {
            self.isPresented = false
        }
        .sheet(isPresented: self.$isPresented) {
            List(0..<40, id: \.self) { row in
                Text("Row \(row)")
            }
            .listStyle(.plain)
            .presentationDetents([Self.tip, .medium, .large], selection: self.$detent)
            .presentationDragIndicator(.visible)
            /// medium까지는 뒤(지도)를 어둡게 하지 않고 만질 수 있어요. 그래도 탭바는 시트 아래에 깔려 누를 수 없어요.
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .presentationCornerRadius(16)
        }
    }

    private var mapTab: some View {
        ZStack(alignment: .topLeading) {
            Map(position: self.$cameraPosition) {
                UserAnnotation()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(self.status)
                    .font(.system(.footnote, design: .monospaced))
                    .lineLimit(2, reservesSpace: true)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.background.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))

                /// 시트를 띄우는 버튼입니다. 탭바가 먼저 보이도록 자동으로 띄우지 않고 이 버튼으로만 띄워요.
                Button("시트 열기") {
                    self.isPresented = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(.systemBackground))
                .foregroundStyle(.blue)
            }
            .padding(16)
        }
    }

    private var status: String {
        let name: String
        if self.isPresented == false {
            name = "dismissed"
        } else if self.detent == Self.tip {
            name = "tip(96)"
        } else if self.detent == .medium {
            name = "medium"
        } else {
            name = "large"
        }

        let hint = self.isPresented ? "탭바가 시트 아래에 가려져요" : "탭바가 보여요. 시트 열기를 눌러요"

        return "sheet=\(name)  .sheet + presentationDetents\n\(hint) · \(self.viewModel.message)"
    }
}
