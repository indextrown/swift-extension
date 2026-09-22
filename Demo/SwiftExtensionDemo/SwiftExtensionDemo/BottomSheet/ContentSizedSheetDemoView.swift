//
//  ContentSizedSheetDemoView.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/23/26.
//

import MapKit
import SwiftUI
import UIKit
import UIKitExtension

/// 콘텐츠 높이만큼만 올라오는 `.content` 단계를 보여 주는 UIKit 데모 화면입니다.
///
/// 시트 안은 스크롤이 필요 없는 상태 카드 몇 장이에요. 시트가 카드 높이를 재서 아래 여백 없이 딱 맞게
/// 올라오고, 카드를 더하면 다시 재서 스프링으로 자리를 옮겨요. 아래 여백은 `.content(padding:)`으로 정해요.
struct ContentSizedSheetDemoScreen: View {

    /// 카드를 두 장에서 세 장으로 바꿔 시트가 다시 재는 걸 봅니다.
    @State private var showsThirdCard = false

    /// 콘텐츠 아래에 더 남길 여백이에요.
    @State private var padding: CGFloat = 0

    var body: some View {
        UIViewControllerContainer {
            Self.makeTabBarController()
        } update: { tabBarController in
            guard let host = Self.host(in: tabBarController) else { return }

            host.cardCount = self.showsThirdCard ? 3 : 2
            host.padding = self.padding
        }
        .ignoresSafeArea()
        .navigationTitle("콘텐츠 높이 시트")
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

    private static func makeTabBarController() -> UITabBarController {
        let tabBarController = UITabBarController()

        let host = ContentSizedSheetHostViewController()
        host.tabBarItem = UITabBarItem(title: "Map", image: UIImage(systemName: "map"), tag: 0)

        let second = SecondTabViewController()
        second.tabBarItem = UITabBarItem(title: "Second", image: UIImage(systemName: "star"), tag: 1)

        tabBarController.viewControllers = [host, second]

        return tabBarController
    }

    private static func host(in tabBarController: UITabBarController) -> ContentSizedSheetHostViewController? {
        return tabBarController.viewControllers?.first as? ContentSizedSheetHostViewController
    }
}



// MARK: - Host

/// 지도 위에 `.content` 단계 시트를 붙이는 UIKit 화면입니다.
final class ContentSizedSheetHostViewController: UIViewController {

    // MARK: - Property

    private static let seoulCityHall = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)

    private let mapView = MKMapView()
    private let cardsViewController = StatusCardsViewController()

    private lazy var sheet = BottomSheetController(
        contentViewController: self.cardsViewController,
        layout: Self.layout(padding: 0),
        initialDetent: .content
    )

    /// 항상 두 줄로 고정해 높이가 바뀌지 않게 합니다.
    private let statusLabel = UILabel()
    private let detentButtons = UIStackView()

    /// 시트 안 카드 개수예요. 바꾸면 시트가 콘텐츠 높이를 다시 재요.
    var cardCount: Int {
        get { self.cardsViewController.cardCount }
        set {
            guard self.cardsViewController.cardCount != newValue else { return }

            self.cardsViewController.cardCount = newValue
            /// 스택에 카드를 더하는 것은 시트가 스스로 알 수 없으니 알려 줍니다.
            self.sheet.invalidateContentHeight()
            self.report()
        }
    }

    /// 콘텐츠 아래 여백이에요. `.content(padding:)`을 바꾼 새 레이아웃을 넣으면 시트가 같은 이름의 단계로 자리를 다시 잡아요.
    var padding: CGFloat = 0 {
        didSet {
            guard self.padding != oldValue else { return }

            self.sheet.layout = Self.layout(padding: self.padding)
            self.report()
        }
    }



    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setAttribute()
        self.setConstraint()

        self.sheet.delegate = self
        self.sheet.add(to: self)
        self.report()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if self.sheet.isDragging == false {
            self.report()
        }
    }



    // MARK: - UI

    private static func layout(padding: CGFloat) -> BottomSheetLayout {
        return BottomSheetLayout(detents: [.hidden, .content(padding: padding)])
    }

    private func setAttribute() {
        self.mapView.setRegion(
            MKCoordinateRegion(center: Self.seoulCityHall, latitudinalMeters: 1200, longitudinalMeters: 1200),
            animated: false
        )

        self.statusLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        self.statusLabel.textColor = .label
        self.statusLabel.numberOfLines = 2
        self.statusLabel.lineBreakMode = .byTruncatingTail
        self.statusLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        self.statusLabel.layer.cornerRadius = 8
        self.statusLabel.layer.masksToBounds = true

        self.detentButtons.axis = .horizontal
        self.detentButtons.spacing = 8

        for identifier in self.sheet.layout.detents.map(\.identifier) {
            let button = UIButton(type: .system)
            button.configuration = {
                var configuration = UIButton.Configuration.filled()
                configuration.title = identifier.rawValue
                configuration.baseBackgroundColor = .systemBackground
                configuration.baseForegroundColor = .systemBlue
                configuration.cornerStyle = .medium
                return configuration
            }()
            button.addAction(UIAction { [weak self] _ in
                self?.sheet.move(to: identifier, animated: true)
            }, for: .touchUpInside)
            self.detentButtons.addArrangedSubview(button)
        }
    }

    private func setConstraint() {
        [self.mapView, self.statusLabel, self.detentButtons].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            self.mapView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.mapView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.mapView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.mapView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            self.statusLabel.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 8),
            self.statusLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            /// 두 줄 라벨은 폭을 고정해야 첫 줄이 이전 배치의 폭에 맞춰 접히지 않아요.
            self.statusLabel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),

            self.detentButtons.topAnchor.constraint(equalTo: self.statusLabel.bottomAnchor, constant: 8),
            self.detentButtons.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16)
        ])
    }

    private func report() {
        let detent = self.sheet.currentDetent
        let visible = Int(max(self.sheet.availableHeight - self.sheet.currentOffset, 0))
        let line1 = "detent=\(detent.identifier.rawValue)  offset=\(Int(self.sheet.currentOffset))  visible=\(visible)"
        let line2 = "cards=\(self.cardCount)  padding=\(Int(self.padding))  avail=\(Int(self.sheet.availableHeight))"

        self.statusLabel.text = " " + line1 + " \n " + line2 + " "
    }
}



// MARK: - BottomSheetControllerDelegate

extension ContentSizedSheetHostViewController: BottomSheetControllerDelegate {

    func bottomSheet(_ controller: BottomSheetController, didChangeDetent detent: BottomSheetDetent) {
        self.report()
    }

    func bottomSheet(_ controller: BottomSheetController, didMoveTo offset: CGFloat) {
        self.report()
    }
}



// MARK: - Content

/// 시트 안에 넣는 상태 카드 묶음입니다. 스크롤이 없고, 카드 수만큼만 높이를 차지해요.
///
/// 제약이 위에서 아래로 이어져 있어서 시트가 `systemLayoutSizeFitting`으로 높이를 잴 수 있어요. 아래 제약은
/// `<=`예요. 시트 View는 탭바 뒤와 화면 밖까지 이어져 잰 높이보다 크기 때문에, `=`로 붙이면 마지막 카드가 늘어나요.
final class StatusCardsViewController: UIViewController {

    private struct Card {
        let symbol: String
        let title: String
        let detail: String
    }

    private static let cards = [
        Card(symbol: "wifi", title: "장비 연결됨", detail: "RTK-WiFi-39A158 · UM982 v3.0-B15d"),
        Card(symbol: "dot.radiowaves.left.and.right", title: "보정 중계 중", detail: "1064 B/s · 수신·전송 2.1 KB · 재접속 0"),
        Card(symbol: "location.north.line", title: "위성 22 · HDOP 0.70", detail: "고도 31.3 m · 수평 정확도 ±3.6 m")
    ]

    private let stack = UIStackView()

    /// 보여 줄 카드 수예요. 1...3.
    var cardCount = 2 {
        didSet { self.rebuildIfLoaded() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.stack.axis = .vertical
        self.stack.spacing = 12
        self.stack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.stack)

        NSLayoutConstraint.activate([
            self.stack.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.stack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            self.stack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            self.stack.bottomAnchor.constraint(lessThanOrEqualTo: self.view.bottomAnchor, constant: -16)
        ])

        self.rebuildIfLoaded()
    }

    private func rebuildIfLoaded() {
        guard self.isViewLoaded else { return }

        self.stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for card in Self.cards.prefix(max(min(self.cardCount, Self.cards.count), 1)) {
            self.stack.addArrangedSubview(Self.makeCardView(card))
        }
    }

    private static func makeCardView(_ card: Card) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 12

        let dot = UIView()
        dot.backgroundColor = .systemGreen
        dot.layer.cornerRadius = 4

        let icon = UIImageView(image: UIImage(systemName: card.symbol))
        icon.tintColor = .secondaryLabel
        icon.contentMode = .scaleAspectFit

        let title = UILabel()
        title.text = card.title
        title.font = .preferredFont(forTextStyle: .headline)

        let detail = UILabel()
        detail.text = card.detail
        detail.font = .preferredFont(forTextStyle: .subheadline)
        detail.textColor = .secondaryLabel
        detail.numberOfLines = 1

        let texts = UIStackView(arrangedSubviews: [title, detail])
        texts.axis = .vertical
        texts.spacing = 2

        let row = UIStackView(arrangedSubviews: [dot, icon, texts])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            icon.widthAnchor.constraint(equalToConstant: 24),

            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
        ])

        return container
    }
}
