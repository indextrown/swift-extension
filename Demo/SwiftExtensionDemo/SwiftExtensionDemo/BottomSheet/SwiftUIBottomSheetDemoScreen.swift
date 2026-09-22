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

    /// 시트 위치예요. `onOffsetChange`가 끄는 동안과 도착할 때 채워 줍니다.
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
        .onAppear {
            self.viewModel.start()
        }
    }

    private var mapTab: some View {
        GeometryReader { proxy in
            let available = proxy.size.height
            let coveredBySheet = self.coveredHeight(available: available)

            ZStack(alignment: .topLeading) {
                Map(position: self.$cameraPosition) {
                    UserAnnotation()
                }
                /// 시트가 가린 만큼 안전 영역을 줄이면 MapKit이 보이는 영역 가운데로 카메라를 다시 잡습니다.
                /// `onOffsetChange`가 준 offset에 묶여 있어 끄는 동안은 매 프레임, 도착할 때는 시트와 같은
                /// 애니메이션으로 따라갑니다. UIKit 판의 `didChangeCoveredHeight`와 같은 역할이에요.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: coveredBySheet)
                }

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
            /// 시트 위에 떠서 함께 움직이는 버튼입니다. `onOffsetChange`가 준 값에 묶여 있어 끄는 동안도, 도착할 때도 따라갑니다.
            .overlay(alignment: .bottomTrailing) {
                Button {
                    self.viewModel.locate()
                    self.centerOnUser(available: available)
                } label: {
                    Label("Locate", systemImage: "location.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(.systemBackground))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
                .accessibilityIdentifier("locate")
                .padding(.trailing, 16)
                .padding(.bottom, coveredBySheet + 12)
            }
        }
        .bottomSheet(
            detent: self.$detent,
            layout: Self.layout,
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

    /// 시트가 가리고 있는 높이입니다. `onOffsetChange`가 아직 안 왔으면 단계 위치로 계산합니다.
    private func coveredHeight(available: CGFloat) -> CGFloat {
        let detentValue = Self.layout.detent(for: self.detent) ?? Self.layout.detents[0]
        let detentOffset = Self.layout.offset(for: detentValue, availableHeight: available)

        return max(available - (self.sheetOffset ?? detentOffset), 0)
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
