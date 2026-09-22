//
//  BottomSheetHostViewController.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import MapKit
import UIKit
import UIKitExtension

/// 지도 위에 시트를 얹는 UIKit 데모 화면입니다.
///
/// 화면이 열리면 현재 위치로 지도를 옮기고, `Locate` 버튼을 누르면 다시 현재 위치로 갑니다.
/// 위치는 `MapHostViewModel`이 다루고 이 화면은 지도와 시트 배치만 맡습니다.
final class BottomSheetHostViewController: UIViewController {

    // MARK: - Property

    private let viewModel = MapHostViewModel()

    private let mapView = MKMapView()

    private let listViewController = PlaceListViewController()

    private lazy var sheet = BottomSheetController(
        contentViewController: self.listViewController,
        layout: .dismissible,
        initialDetent: .tip
    )

    /// 항상 두 줄로 고정해 높이가 바뀌지 않게 합니다. 줄 수가 바뀌면 아래 버튼이 밀립니다.
    private let statusLabel = UILabel()

    private let detentButtons = UIStackView()

    /// 시트 위에 떠서 함께 올라가는 버튼입니다. 형제 View를 `sheet.view.topAnchor`에 붙여 따라가게 합니다.
    private let locateButton = UIButton(type: .system)

    /// 처음 받은 위치로 지도를 한 번만 옮기기 위한 표시입니다.
    private var hasCenteredOnUser = false



    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setAttribute()
        self.setConstraint()

        self.sheet.delegate = self
        self.sheet.add(to: self)
        self.sheet.track(scrollView: self.listViewController.tableView)

        /// 시트가 붙은 뒤에 걸어야 `sheet.view`가 부모 안에 있습니다.
        self.locateButton.bottomAnchor.constraint(
            equalTo: self.sheet.view.topAnchor,
            constant: -12
        ).isActive = true

        self.bindViewModel()
        self.viewModel.start()
        self.report(extra: self.viewModel.state.message)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        /// 붙인 직후에는 안전 영역이 반영되지 않은 값이 읽히므로 배치가 끝난 뒤 다시 표시합니다.
        if self.sheet.isDragging == false {
            self.report(extra: self.viewModel.state.message)
        }
    }



    // MARK: - UI

    private func setAttribute() {
        self.mapView.showsUserLocation = true
        self.mapView.accessibilityIdentifier = "map"

        self.statusLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        self.statusLabel.textColor = .label
        self.statusLabel.numberOfLines = 2
        self.statusLabel.lineBreakMode = .byTruncatingTail
        self.statusLabel.accessibilityIdentifier = "status"
        self.statusLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        self.statusLabel.layer.cornerRadius = 8
        self.statusLabel.layer.masksToBounds = true

        self.detentButtons.axis = .horizontal
        self.detentButtons.spacing = 8

        for identifier in self.sheet.layout.detents.map(\.identifier) {
            let button = UIButton(type: .system)
            button.accessibilityIdentifier = "move-\(identifier.rawValue)"
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

        self.locateButton.accessibilityIdentifier = "locate"
        self.locateButton.configuration = {
            var configuration = UIButton.Configuration.filled()
            configuration.title = "Locate"
            configuration.image = UIImage(systemName: "location.fill")
            configuration.imagePadding = 6
            configuration.baseBackgroundColor = .systemBackground
            configuration.baseForegroundColor = .systemBlue
            configuration.cornerStyle = .capsule
            return configuration
        }()
        self.locateButton.addAction(UIAction { [weak self] _ in
            self?.viewModel.locate()
            self?.centerOnUser(animated: true)
        }, for: .touchUpInside)
    }

    private func setConstraint() {
        [self.mapView, self.statusLabel, self.detentButtons, self.locateButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            /// 지도는 내비게이션 바와 탭바 뒤까지 화면을 다 채웁니다.
            self.mapView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.mapView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.mapView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.mapView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            self.statusLabel.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 8),
            self.statusLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            self.statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor, constant: -16),

            self.detentButtons.topAnchor.constraint(equalTo: self.statusLabel.bottomAnchor, constant: 8),
            self.detentButtons.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),

            self.locateButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            self.locateButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }



    // MARK: - Private

    private func bindViewModel() {
        self.viewModel.onChange = { [weak self] state in
            guard let self else { return }

            self.report(extra: state.message)

            /// 처음 받은 위치로만 자동으로 옮깁니다. 그 뒤로는 사용자가 지도를 움직였을 수 있어요.
            if state.coordinate != nil, self.hasCenteredOnUser == false {
                self.hasCenteredOnUser = true
                self.centerOnUser(animated: true)
            }
        }
    }

    /// 현재 위치가 시트에 가리지 않는 영역의 가운데에 오도록 지도를 옮깁니다.
    ///
    /// 시트가 가린 높이를 `edgePadding`으로 넘기면 MapKit이 그만큼 위로 중심을 잡아 줍니다.
    private func centerOnUser(animated: Bool) {
        guard let coordinate = self.viewModel.state.coordinate else { return }

        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 1200, longitudinalMeters: 1200)
        let coveredBySheet = self.sheet.availableHeight - self.sheet.offset(for: self.sheet.currentDetent)
        let padding = UIEdgeInsets(top: 0, left: 0, bottom: max(coveredBySheet, 0), right: 0)

        self.mapView.setVisibleMapRect(Self.mapRect(for: region), edgePadding: padding, animated: animated)
    }

    private static func mapRect(for region: MKCoordinateRegion) -> MKMapRect {
        let topLeft = MKMapPoint(CLLocationCoordinate2D(
            latitude: region.center.latitude + region.span.latitudeDelta / 2,
            longitude: region.center.longitude - region.span.longitudeDelta / 2
        ))
        let bottomRight = MKMapPoint(CLLocationCoordinate2D(
            latitude: region.center.latitude - region.span.latitudeDelta / 2,
            longitude: region.center.longitude + region.span.longitudeDelta / 2
        ))

        return MKMapRect(
            x: min(topLeft.x, bottomRight.x),
            y: min(topLeft.y, bottomRight.y),
            width: abs(topLeft.x - bottomRight.x),
            height: abs(topLeft.y - bottomRight.y)
        )
    }

    private func report(extra: String) {
        let detent = self.sheet.currentDetent
        let line1 = "detent=\(detent.identifier.rawValue)  target=\(Int(self.sheet.offset(for: detent)))  now=\(Int(self.sheet.currentOffset))"
        let line2 = "avail=\(Int(self.sheet.availableHeight))  \(extra)"

        self.statusLabel.text = " " + line1 + " \n " + line2 + " "
    }
}



// MARK: - BottomSheetControllerDelegate

extension BottomSheetHostViewController: BottomSheetControllerDelegate {

    func bottomSheet(_ controller: BottomSheetController, didChangeDetent detent: BottomSheetDetent) {
        self.report(extra: self.viewModel.state.message)
    }

    func bottomSheet(_ controller: BottomSheetController, didMoveTo offset: CGFloat) {
        self.report(extra: "dragging")
    }
}
