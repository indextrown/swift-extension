//
//  ComponentUIKitDemoViewController.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/1/26.
//

import SwiftUI
import UIKit
import UIKitComponents

/// 같은 컴포넌트를 UIKit의 스택뷰와 컬렉션뷰 셀에 넣는 데모 화면입니다.
struct ComponentUIKitDemoScreen: View {

    var body: some View {
        UIViewControllerContainer {
            ComponentUIKitDemoViewController()
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("UIKit에서 쓰기")
        .navigationBarTitleDisplayMode(.inline)
    }
}



// MARK: - View Controller

/// 위쪽 스택뷰에는 `ComponentHostView`로, 아래 목록에는 `contentConfiguration()`으로 같은 컴포넌트를 넣습니다.
///
/// `짧게`·`길게`를 바꾸면 스택뷰는 `update(_:)`로, 목록은 `reconfigureItems(_:)`로 다시 그리고,
/// 둘 다 뷰를 새로 만들지 않고 글 길이에 맞춰 높이를 다시 잽니다.
final class ComponentUIKitDemoViewController: UIViewController {

    // MARK: - Property

    private let lengthControl = UISegmentedControl(items: ["짧게", "길게"])
    private let stackView = UIStackView()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: Self.makeLayout())
    private var dataSource: UICollectionViewDiffableDataSource<Int, Notice.ID>?

    private lazy var headlineView = ComponentHostView(Notice.headline.component(isExpanded: self.isExpanded))
    private lazy var alarmView = ComponentHostView(self.makeAlarmComponent())

    private let notices = Notice.samples
    private var isExpanded = false
    private var isAlarmOn = true



    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setAttribute()
        self.setConstraint()
        self.setDataSource()
    }



    // MARK: - Action

    @objc
    private func didChangeLength() {
        self.isExpanded = self.lengthControl.selectedSegmentIndex == 1

        /// 스택뷰: 같은 호스트 뷰에 새 컴포넌트를 넣어요.
        self.headlineView.update(Notice.headline.component(isExpanded: self.isExpanded))

        /// 목록: 셀을 다시 구성하면 셀 안의 뷰는 그대로 두고 갱신만 해요.
        guard let dataSource = self.dataSource else { return }
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func makeAlarmComponent() -> ToggleRowComponent {
        return ToggleRowComponent(
            title: self.isAlarmOn ? "알림을 받고 있어요" : "알림을 껐어요",
            isOn: self.isAlarmOn
        ) { [weak self] isOn in
            guard let self else { return }

            self.isAlarmOn = isOn
            self.alarmView.update(self.makeAlarmComponent())
        }
    }



    // MARK: - UI

    private func setAttribute() {
        self.view.backgroundColor = .systemBackground

        self.lengthControl.selectedSegmentIndex = 0
        self.lengthControl.addTarget(self, action: #selector(self.didChangeLength), for: .valueChanged)

        self.stackView.axis = .vertical
        self.stackView.spacing = 12
        self.stackView.addArrangedSubview(self.lengthControl)
        self.stackView.addArrangedSubview(self.headlineView)
        self.stackView.addArrangedSubview(self.alarmView)
    }

    private func setConstraint() {
        [self.stackView, self.collectionView].forEach { subview in
            subview.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            self.stackView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 12),
            self.stackView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            self.stackView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),

            self.collectionView.topAnchor.constraint(equalTo: self.stackView.bottomAnchor, constant: 12),
            self.collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
    }

    private func setDataSource() {
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Notice> { [weak self] cell, _, notice in
            let isExpanded = self?.isExpanded ?? false
            cell.backgroundConfiguration = .clear()
            cell.contentConfiguration = notice.component(isExpanded: isExpanded).contentConfiguration()
        }

        let notices = Dictionary(uniqueKeysWithValues: self.notices.map { ($0.id, $0) })
        let dataSource = UICollectionViewDiffableDataSource<Int, Notice.ID>(
            collectionView: self.collectionView
        ) { collectionView, indexPath, id in
            return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: notices[id])
        }

        var snapshot = NSDiffableDataSourceSnapshot<Int, Notice.ID>()
        snapshot.appendSections([0])
        snapshot.appendItems(self.notices.map(\.id))
        dataSource.apply(snapshot, animatingDifferences: false)
        self.dataSource = dataSource
    }

    private static func makeLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { _, environment in
            var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
            configuration.showsSeparators = false
            configuration.backgroundColor = .clear

            let section = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
            section.interGroupSpacing = 12
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 24, trailing: 16)
            return section
        }
    }
}
