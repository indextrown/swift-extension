//
//  SwiftUIBottomSheetDemoScreen.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import MapKit
import SwiftUI
import SwiftUIExtension

/// 지도 위에 시트를 얹는 SwiftUI 데모 화면입니다. `TabView`의 탭 콘텐츠에 `bottomSheet`를 얹어 탭바 뒤에서 올라오게 합니다.
///
/// 화면이 나타나면 MapKit이 현재 위치를 따라가고(`.userLocation`), `Locate` 버튼을 누르면 시트에 가리지
/// 않는 영역의 가운데로 다시 맞춥니다. 권한과 좌표는 `MapDemoViewModel`이 다루고 이 화면은 지도와 시트 배치만 맡습니다.
struct SwiftUIBottomSheetDemoScreen: View {

    private static let layout = BottomSheetLayout.dismissible

    @State private var viewModel = MapDemoViewModel()
    @State private var detent: BottomSheetDetent.Identifier = .tip

    /// 시트 안의 목록을 위로 끌 때 시트가 먼저 올라갈지(Apple 지도 방식), 목록만 스크롤될지 정합니다.
    @State private var scrollingExpandsSheet = false

    /// 손잡이 줄과 빈 곳으로만 시트를 끌지 정합니다. 켜면 목록을 어떻게 끌어도 시트는 그대로예요.
    @State private var dragsWithHandleAndBackground = false

    /// 시트 위치예요. `onOffsetChange`가 시트가 움직이는 매 프레임 채워 줍니다.
    @State private var sheetOffset: CGFloat?

    /// 처음엔 MapKit이 현재 위치를 따라가게 둡니다. `.automatic`으로 두면 사용자 위치 어노테이션이
    /// 나타난 뒤 MapKit이 자동 프레이밍을 한 번 더 해서, 먼저 넣은 `.region`을 덮어씁니다.
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("스크롤이 시트를 올려요", isOn: self.$scrollingExpandsSheet)
                    Toggle("손잡이·빈 곳으로만 끌어요", isOn: self.$dragsWithHandleAndBackground)
                } label: {
                    Label("옵션", systemImage: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            self.viewModel.start()
        }
    }

    private var mapTab: some View {
        GeometryReader { proxy in
            let available = proxy.size.height

            ZStack(alignment: .topLeading) {
                Map(position: self.$cameraPosition) {
                    UserAnnotation()
                }
                /// 시트가 가린 만큼 아래 안전 영역을 줄여요. MapKit이 보이는 영역 가운데로 카메라를 다시 잡고,
                /// 끄는 동안도 스프링으로 움직이는 동안도 매 프레임 따라가요. 이전에는 `onOffsetChange`로 받은
                /// offset을 `@State`에 넣고 `safeAreaInset(edge: .bottom)` 높이를 직접 계산했어요.
                .bottomSheetInset()

                VStack(alignment: .leading, spacing: 8) {
                    Text(self.status)
                        .font(.system(.footnote, design: .monospaced))
                        .lineLimit(2, reservesSpace: true)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.background.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))

                    HStack(spacing: 8) {
                        ForEach(Self.layout.detents, id: \.identifier) { candidate in
                            Button(candidate.identifier.rawValue) {
                                self.detent = candidate.identifier
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(.systemBackground))
                            .foregroundStyle(.blue)
                        }
                    }
                }
                .padding(16)
            }
            /// 시트 위에 떠서 함께 움직이는 도크예요. 환경값 `bottomSheetCoveredHeight`를 읽어 시트를 따라가고,
            /// 시트가 `hidden`이면 탭바 위에 머물러요. 이전에는 `overlay(alignment: .bottomTrailing)`에
            /// `padding(.bottom, coveredBySheet + 12)`를 직접 계산해 넣었어요.
            .bottomSheetDock {
                /// 시트가 내려가 있을 때만 보이는 열기 버튼이에요. 누르면 시트가 올라가면서 버튼이 사라져요.
                Button {
                    self.detent = .tip
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.bottomSheetDock)
                .bottomSheetDockVisibility(.whenHidden)
                .accessibilityLabel("시트 열기")

                Button {
                    self.viewModel.locate()
                    self.centerOnUser(available: available)
                } label: {
                    Image(systemName: "location.fill")
                }
                .buttonStyle(.bottomSheetDock)
                .accessibilityLabel("현재 위치")
                .accessibilityIdentifier("locate")
            }
        }
        .bottomSheet(
            detent: self.$detent,
            layout: Self.layout,
            behavior: BottomSheetBehavior(
                scrollingExpandsSheet: self.scrollingExpandsSheet,
                dragArea: self.dragsWithHandleAndBackground ? .handleAndBackground : .entireSheet
            ),
            onOffsetChange: { self.sheetOffset = $0 }
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

    private func centerOnUser(available: CGFloat) {
        guard let coordinate = self.viewModel.coordinate else { return }

        withAnimation(.easeInOut(duration: 0.4)) {
            self.cameraPosition = .region(MKCoordinateRegion(
                center: coordinate.clCoordinate,
                latitudinalMeters: 1200,
                longitudinalMeters: 1200
            ))
        }
    }

    private var status: String {
        return "detent=\(self.detent.rawValue)  offset=\(self.sheetOffset.map { String(Int($0)) } ?? "-")\n\(self.viewModel.message)"
    }
}



// MARK: - Nested Lists

/// 시트 안에 일반 `List` 두 개를 나란히 둔 화면입니다. 지역 선택처럼 목록이 여러 개인 시트를 흉내 냅니다.
///
/// `List`는 `BottomSheetScrollView`로 감쌀 수 없어서, 시트 어디서나 끌면(`.entireSheet`) 목록을 스크롤할 때
/// 시트가 함께 끌려요. 오른쪽 위 메뉴로 `.handleAndBackground`를 켜면 손잡이 줄과 빈 곳(좌우 여백, 제목 옆 빈 곳)으로만
/// 시트가 움직이고 목록은 스크롤만 해요. `제목줄도 끌어요`는 `bottomSheetDragHandle(_:)`을 켜고 꺼요. 버튼은 켜도 자기 터치를 지켜요.
struct SwiftUINestedListSheetDemoScreen: View {

    private static let provinces = ["서울", "경기", "인천", "부산", "대구", "광주", "대전", "울산", "세종", "강원", "충북", "충남", "전북", "전남", "경북", "경남", "제주"]

    @State private var detent: BottomSheetDetent.Identifier = .half
    @State private var dragsWithHandleAndBackground = true
    @State private var isHeaderDraggable = false
    @State private var province = "서울"
    @State private var district: Int?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.secondarySystemBackground)
                .ignoresSafeArea()

            Text(self.status)
                .font(.system(.footnote, design: .monospaced))
                .padding(16)
                .accessibilityIdentifier("nested-status")
        }
        .bottomSheet(
            detent: self.$detent,
            layout: .standard,
            style: BottomSheetStyle(handleAreaHeight: 36),
            behavior: BottomSheetBehavior(dragArea: self.dragsWithHandleAndBackground ? .handleAndBackground : .entireSheet)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("지역 선택")
                        .font(.headline)

                    Spacer()

                    Button("초기화") {
                        self.province = "서울"
                        self.district = nil
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .bottomSheetDragHandle(self.isHeaderDraggable)

                HStack(spacing: 0) {
                    List(Self.provinces, id: \.self) { name in
                        Button(name) {
                            self.province = name
                            self.district = nil
                        }
                        .foregroundStyle(name == self.province ? Color.accentColor : Color.primary)
                    }
                    .listStyle(.plain)
                    .accessibilityIdentifier("province-list")

                    List(0..<30, id: \.self) { index in
                        Button("\(self.province) \(index + 1)구") {
                            self.district = index
                        }
                        .foregroundStyle(index == self.district ? Color.accentColor : Color.primary)
                    }
                    .listStyle(.plain)
                    .accessibilityIdentifier("district-list")
                }
                /// 좌우 여백은 빈 곳이라 손잡이·빈 곳으로만 끌 때도 시트가 움직여요.
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("목록 여러 개 시트 (SwiftUI)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("손잡이·빈 곳으로만 끌어요", isOn: self.$dragsWithHandleAndBackground)
                    Toggle("제목줄도 끌어요", isOn: self.$isHeaderDraggable)
                } label: {
                    Label("옵션", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private var status: String {
        let area = self.dragsWithHandleAndBackground ? "handleAndBackground" : "entireSheet"

        return "detent=\(self.detent.rawValue)  dragArea=\(area)  header=\(self.isHeaderDraggable ? "on" : "off")"
    }
}
