//
//  BottomSheetHostViewController.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import UIKit
import UIKitExtension

/// 지도 화면 역할을 하는 호스트입니다. 시트를 자식으로 붙이고 상태를 화면 위에 보여 줍니다.
final class BottomSheetHostViewController: UIViewController {

    // MARK: - Property

    private let listViewController = PlaceListViewController()

    private lazy var sheet = BottomSheetController(
        contentViewController: self.listViewController,
        layout: .dismissible,
        initialDetent: .tip
    )

    /// 항상 두 줄로 고정해 높이가 바뀌지 않게 합니다. 줄 수가 바뀌면 아래 버튼이 밀립니다.
    private let statusLabel = UILabel()

    private let detentButtons = UIStackView()

    /// 시트 위에 떠서 함께 올라가는 버튼입니다. 형제 View를 `sheet.view.topAnchor`에 붙일 수 있는지 보여 줍니다.
    private let locateButton = UIButton(type: .system)



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

        self.report(extra: "-")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        /// 붙인 직후에는 안전 영역이 반영되지 않은 값이 읽히므로 배치가 끝난 뒤 다시 표시합니다.
        if self.sheet.isDragging == false {
            self.report(extra: self.statusLabel.text?.hasSuffix("changed") == true ? "changed" : "-")
        }
    }



    // MARK: - UI

    private func setAttribute() {
        /// 지도 대용 배경입니다.
        self.view.backgroundColor = UIColor(red: 0.62, green: 0.82, blue: 0.75, alpha: 1)

        self.statusLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        self.statusLabel.textColor = .black
        self.statusLabel.numberOfLines = 2
        self.statusLabel.lineBreakMode = .byTruncatingTail
        self.statusLabel.accessibilityIdentifier = "status"

        self.detentButtons.axis = .horizontal
        self.detentButtons.spacing = 8

        for identifier in self.sheet.layout.detents.map(\.identifier) {
            let button = UIButton(type: .system)
            button.setTitle(identifier.rawValue, for: .normal)
            button.accessibilityIdentifier = "move-\(identifier.rawValue)"
            button.backgroundColor = .white
            button.layer.cornerRadius = 8
            button.configuration = {
                var configuration = UIButton.Configuration.plain()
                configuration.title = identifier.rawValue
                configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
                return configuration
            }()
            button.addAction(UIAction { [weak self] _ in
                self?.sheet.move(to: identifier, animated: true)
            }, for: .touchUpInside)
            self.detentButtons.addArrangedSubview(button)
        }

        self.locateButton.setTitle("Locate", for: .normal)
        self.locateButton.accessibilityIdentifier = "locate"
        self.locateButton.backgroundColor = .white
        self.locateButton.layer.cornerRadius = 22
    }

    private func setConstraint() {
        [self.statusLabel, self.detentButtons, self.locateButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            self.statusLabel.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 8),
            self.statusLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            self.statusLabel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),

            self.detentButtons.topAnchor.constraint(equalTo: self.statusLabel.bottomAnchor, constant: 8),
            self.detentButtons.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),

            self.locateButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            self.locateButton.widthAnchor.constraint(equalToConstant: 88),
            self.locateButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }



    // MARK: - Private

    private func report(extra: String) {
        let detent = self.sheet.currentDetent
        let line1 = "detent=\(detent.identifier.rawValue)  target=\(Int(self.sheet.offset(for: detent)))  now=\(Int(self.sheet.currentOffset))"
        let line2 = "avail=\(Int(self.sheet.availableHeight))  \(extra)"

        self.statusLabel.text = line1 + "\n" + line2
    }
}



// MARK: - BottomSheetControllerDelegate

extension BottomSheetHostViewController: BottomSheetControllerDelegate {

    func bottomSheet(_ controller: BottomSheetController, didChangeDetent detent: BottomSheetDetent) {
        self.report(extra: "changed")
    }

    func bottomSheet(_ controller: BottomSheetController, didMoveTo offset: CGFloat) {
        self.report(extra: "dragging")
    }
}
