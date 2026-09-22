//
//  SwiftUIContentSizedSheetDemoScreen.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/23/26.
//

import MapKit
import SwiftUI
import SwiftUIExtension

/// 콘텐츠 높이만큼만 올라오는 `.content` 단계를 보여 주는 SwiftUI 데모 화면입니다.
///
/// 시트 안은 스크롤이 필요 없는 상태 카드 몇 장이에요. 시트가 카드 View의 높이를 재서 아래 여백 없이
/// 딱 맞게 올라오고, 카드를 더하면 SwiftUI가 다시 그리면서 저절로 다시 재요. 아래 여백은 `.content(padding:)`으로 정해요.
struct SwiftUIContentSizedSheetDemoScreen: View {

    private struct Card: Identifiable {
        let id: Int
        let symbol: String
        let title: String
        let detail: String
    }

    private static let cards = [
        Card(id: 0, symbol: "wifi", title: "장비 연결됨", detail: "RTK-WiFi-39A158 · UM982 v3.0-B15d"),
        Card(id: 1, symbol: "dot.radiowaves.left.and.right", title: "보정 중계 중", detail: "1064 B/s · 수신·전송 2.1 KB · 재접속 0"),
        Card(id: 2, symbol: "location.north.line", title: "위성 22 · HDOP 0.70", detail: "고도 31.3 m · 수평 정확도 ±3.6 m")
    ]

    private static let seoulCityHall = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)

    @State private var detent: BottomSheetDetent.Identifier = .content
    @State private var showsThirdCard = false
    @State private var padding: CGFloat = 0
    @State private var sheetOffset: CGFloat?

    private var layout: BottomSheetLayout {
        return BottomSheetLayout(detents: [.hidden, .content(padding: self.padding)])
    }

    var body: some View {
        TabView {
            self.mapTab
                .tabItem { Label("Map", systemImage: "map") }

            Text("Second tab")
                .font(.largeTitle)
                .tabItem { Label("Second", systemImage: "star") }
        }
        .navigationTitle("콘텐츠 높이 시트 (SwiftUI)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("카드 3장", isOn: self.$showsThirdCard)

                    Picker("아래 여백", selection: self.$padding) {
                        Text("여백 0").tag(CGFloat(0))
                        Text("여백 16").tag(CGFloat(16))
                        Text("여백 40").tag(CGFloat(40))
                    }
                } label: {
                    Label("옵션", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private var mapTab: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: Self.seoulCityHall,
                    latitudinalMeters: 1200,
                    longitudinalMeters: 1200
                )))

                VStack(alignment: .leading, spacing: 8) {
                    Text(self.status(available: proxy.size.height))
                        .font(.system(.footnote, design: .monospaced))
                        .lineLimit(2, reservesSpace: true)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.background.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))

                    HStack(spacing: 8) {
                        ForEach(self.layout.detents, id: \.identifier) { candidate in
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
        }
        .bottomSheet(
            detent: self.$detent,
            layout: self.layout,
            onOffsetChange: { self.sheetOffset = $0 }
        ) {
            /// 스크롤뷰가 아닌 보통 View라 시트가 이 VStack의 높이를 그대로 재요.
            VStack(spacing: 12) {
                ForEach(Self.cards.prefix(self.showsThirdCard ? 3 : 2)) { card in
                    self.cardView(card)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func cardView(_ card: Card) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)

            Image(systemName: card.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.headline)
                Text(card.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func status(available: CGFloat) -> String {
        let offset = self.sheetOffset.map { Int($0) }
        let visible = self.sheetOffset.map { Int(max(available - $0, 0)) }

        return "detent=\(self.detent.rawValue)  offset=\(offset.map(String.init) ?? "-")  visible=\(visible.map(String.init) ?? "-")\n"
            + "cards=\(self.showsThirdCard ? 3 : 2)  padding=\(Int(self.padding))  avail=\(Int(available))"
    }
}
