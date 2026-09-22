//
//  NativeSheetDemoView.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/23/26.
//

import MapKit
import SwiftUI
import UIKit

/// 애플이 제공하는 `UISheetPresentationController`를 같은 탭바 구성 안에서 띄우는 비교용 화면입니다.
///
/// `BottomSheetController`와 달리 **모달**이라 시트가 탭바 위를 덮어요. 시트가 떠 있는 동안 탭을 바꿀 수 없고,
/// 끝까지 내리면 닫혀요. 단계는 커스텀 시트와 같은 96pt·medium·large로 맞춰 나란히 비교할 수 있게 했어요.
struct NativeSheetDemoScreen: View {

    var body: some View {
        UIViewControllerContainer {
            Self.makeTabBarController()
        }
        .ignoresSafeArea()
        .navigationTitle("애플 기본 시트")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func makeTabBarController() -> UITabBarController {
        let tabBarController = UITabBarController()

        let host = NativeSheetHostViewController()
        host.tabBarItem = UITabBarItem(title: "Map", image: UIImage(systemName: "map"), tag: 0)

        let second = SecondTabViewController()
        second.tabBarItem = UITabBarItem(title: "Second", image: UIImage(systemName: "star"), tag: 1)

        tabBarController.viewControllers = [host, second]

        return tabBarController
    }
}



// MARK: - Host

/// 지도 위에 `UISheetPresentationController` 시트를 띄우는 UIKit 화면입니다.
///
/// 시트 위치를 프레임마다 알려 주는 대리자가 없어 지도가 시트를 따라가지 않아요. 단계가 바뀐 뒤에만
/// `sheetPresentationControllerDidChangeSelectedDetentIdentifier`가 와요.
final class NativeSheetHostViewController: UIViewController {

    // MARK: - Property

    private static let tipDetent = UISheetPresentationController.Detent.Identifier("tip")

    private let viewModel = MapHostViewModel()

    private let mapView = MKMapView()

    /// 항상 두 줄로 고정해 높이가 바뀌지 않게 합니다.
    private let statusLabel = UILabel()

    /// 시트를 끝까지 내려 닫은 뒤 다시 띄우는 버튼입니다.
    private let openButton = UIButton(type: .system)

    private var hasPresented = false
    private var hasCenteredOnUser = false



    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setAttribute()
        self.setConstraint()
        self.bindViewModel()
        self.viewModel.start()
        self.report(detent: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard self.hasPresented == false else { return }

        self.hasPresented = true
        self.presentSheet()
    }

    /// 화면을 떠날 때 시트도 함께 내립니다. 모달은 이 화면이 아니라 창에 붙어 있어서, 뒤로 가기로
    /// 이 화면이 사라져도 시트는 남아요. pageSheet는 이 화면을 가리지 않으므로 시트를 띄울 때는 오지 않습니다.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.presentedViewController?.dismiss(animated: false)
    }



    // MARK: - UI

    private func setAttribute() {
        self.mapView.showsUserLocation = true

        self.statusLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        self.statusLabel.textColor = .label
        self.statusLabel.numberOfLines = 2
        self.statusLabel.lineBreakMode = .byTruncatingTail
        self.statusLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        self.statusLabel.layer.cornerRadius = 8
        self.statusLabel.layer.masksToBounds = true

        self.openButton.configuration = {
            var configuration = UIButton.Configuration.filled()
            configuration.title = "시트 열기"
            configuration.baseBackgroundColor = .systemBackground
            configuration.baseForegroundColor = .systemBlue
            configuration.cornerStyle = .medium
            return configuration
        }()
        self.openButton.addAction(UIAction { [weak self] _ in
            self?.presentSheet()
        }, for: .touchUpInside)
    }

    private func setConstraint() {
        [self.mapView, self.statusLabel, self.openButton].forEach {
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
            self.statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor, constant: -16),

            self.openButton.topAnchor.constraint(equalTo: self.statusLabel.bottomAnchor, constant: 8),
            self.openButton.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16)
        ])
    }



    // MARK: - Private

    private func bindViewModel() {
        self.viewModel.onChange = { [weak self] state in
            guard let self else { return }

            self.report(detent: self.selectedDetent)

            if let coordinate = state.coordinate, self.hasCenteredOnUser == false {
                self.hasCenteredOnUser = true
                self.mapView.setRegion(
                    MKCoordinateRegion(center: coordinate, latitudinalMeters: 1200, longitudinalMeters: 1200),
                    animated: true
                )
            }
        }
    }

    /// 이미 떠 있으면 다시 띄우지 않습니다.
    private func presentSheet() {
        guard self.presentedViewController == nil else { return }

        let list = PlaceListViewController()
        list.modalPresentationStyle = .pageSheet

        if let sheet = list.sheetPresentationController {
            /// 커스텀 시트의 tip(96pt)·half·full과 맞춘 단계예요.
            sheet.detents = [
                .custom(identifier: Self.tipDetent) { _ in 96 },
                .medium(),
                .large()
            ]
            sheet.selectedDetentIdentifier = Self.tipDetent
            /// medium까지는 뒤(지도)를 어둡게 하지 않고 만질 수 있게 둡니다. 그래도 탭바는 시트 아래에 깔려 누를 수 없어요.
            sheet.largestUndimmedDetentIdentifier = .medium
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.preferredCornerRadius = 16
            sheet.delegate = self
        }

        self.present(list, animated: true)
        self.report(detent: Self.tipDetent)
    }

    private var selectedDetent: UISheetPresentationController.Detent.Identifier? {
        return self.presentedViewController?.sheetPresentationController?.selectedDetentIdentifier
    }

    private func report(detent: UISheetPresentationController.Detent.Identifier?) {
        let name: String
        switch detent {
        case Self.tipDetent?: name = "tip(96)"
        case .medium?: name = "medium"
        case .large?: name = "large"
        case .some(let other): name = other.rawValue
        case nil: name = "dismissed"
        }

        self.statusLabel.text = " sheet=\(name)  UISheetPresentationController \n \(self.viewModel.state.message) "
    }
}



// MARK: - UISheetPresentationControllerDelegate

extension NativeSheetHostViewController: UISheetPresentationControllerDelegate {

    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheet: UISheetPresentationController) {
        self.report(detent: sheet.selectedDetentIdentifier)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        self.report(detent: nil)
    }
}
