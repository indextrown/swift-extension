//
//  PlaceListViewController.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import SwiftUI
import UIKit
import UIKitExtension

/// 시트 안에 넣는 콘텐츠입니다. 스크롤 핸드오프를 확인할 수 있게 행을 넉넉히 둡니다.
final class PlaceListViewController: UITableViewController {

    private static let rowCount = 40

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableView.accessibilityIdentifier = "place-list"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Self.rowCount
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = "Row \(indexPath.row)"

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}



// MARK: - Nested Lists

/// 시트 안에 따라가지 않는 `UITableView` 두 개를 나란히 둔 UIKit 화면입니다. SwiftUI 판과 같은 상황을 만듭니다.
///
/// 오른쪽 위 메뉴로 `.handleAndBackground`를 켜면 손잡이 줄과 빈 곳(제목 옆, 왼쪽 여백)으로만 시트가 움직이고 목록은
/// 스크롤만 해요. `제목줄도 끌어요`는 제목줄 View의 `isBottomSheetDragHandle`을 켜고 꺼요. 버튼은 켜도 자기 터치를 지켜요.
struct NestedListSheetDemoScreen: View {

    @State private var dragsWithHandleAndBackground = true
    @State private var isHeaderDraggable = false

    var body: some View {
        UIViewControllerContainer {
            NestedListSheetHostViewController()
        } update: { host in
            host.dragArea = self.dragsWithHandleAndBackground ? .handleAndBackground : .entireSheet
            host.isHeaderDraggable = self.isHeaderDraggable
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("목록 여러 개 시트")
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
}

/// 시트를 붙이는 부모 화면입니다. 위쪽 라벨에 지금 단계와 끌기 영역을 보여 줍니다.
final class NestedListSheetHostViewController: UIViewController, BottomSheetControllerDelegate {

    private let statusLabel = UILabel()
    private let content = NestedListsViewController()
    private lazy var sheet = BottomSheetController(
        contentViewController: self.content,
        layout: .standard,
        initialDetent: .half,
        appearance: BottomSheetAppearance(handleAreaHeight: 36)
    )

    var dragArea: BottomSheetDragArea {
        get { self.sheet.behavior.dragArea }
        set {
            self.sheet.behavior.dragArea = newValue
            self.updateStatus()
        }
    }

    var isHeaderDraggable: Bool {
        get { self.content.isHeaderDraggable }
        set {
            self.content.isHeaderDraggable = newValue
            self.updateStatus()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .secondarySystemBackground
        self.statusLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        self.statusLabel.accessibilityIdentifier = "nested-status"
        self.statusLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.statusLabel)
        NSLayoutConstraint.activate([
            self.statusLabel.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 16),
            self.statusLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
        ])

        self.sheet.delegate = self
        self.sheet.add(to: self)
        self.updateStatus()
    }

    func bottomSheet(_ controller: BottomSheetController, didChangeDetent detent: BottomSheetDetent) {
        self.updateStatus(detent: detent.identifier)
    }

    private func updateStatus(detent: BottomSheetDetent.Identifier? = nil) {
        let identifier = detent ?? self.sheet.currentDetent.identifier
        let area = self.sheet.behavior.dragArea == .handleAndBackground ? "handleAndBackground" : "entireSheet"
        let header = self.content.isHeaderDraggable ? "on" : "off"
        self.statusLabel.text = "detent=\(identifier.rawValue)  dragArea=\(area)  header=\(header)"
    }
}

/// 제목줄과, 따라가지 않는 테이블뷰 두 개를 나란히 둔 콘텐츠입니다.
///
/// 목록은 View 가장자리에 붙이고 아래 안전 영역은 `contentInsetAdjustmentBehavior`에 맡깁니다. `static`에서 단계를
/// 옮겨도 목록 프레임이 바뀌지 않는 권장 배치예요.
final class NestedListsViewController: UIViewController, UITableViewDataSource {

    /// 제목줄을 끌기 손잡이로 쓸지 정합니다.
    var isHeaderDraggable = false {
        didSet { self.header.isBottomSheetDragHandle = self.isHeaderDraggable }
    }

    private let header = UIView()
    private let provinces = UITableView(frame: .zero, style: .plain)
    private let districts = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = "지역 선택"
        titleLabel.font = .preferredFont(forTextStyle: .headline)

        let resetButton = UIButton(type: .system)
        resetButton.setTitle("초기화", for: .normal)
        resetButton.addAction(UIAction { [weak self] _ in self?.resetSelection() }, for: .touchUpInside)

        let headerRow = UIStackView(arrangedSubviews: [titleLabel, UIView(), resetButton])
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        self.header.addSubview(headerRow)
        self.header.isBottomSheetDragHandle = self.isHeaderDraggable

        [self.provinces, self.districts].forEach {
            $0.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
            $0.dataSource = self
        }
        self.provinces.accessibilityIdentifier = "province-table"
        self.districts.accessibilityIdentifier = "district-table"

        let lists = UIStackView(arrangedSubviews: [self.provinces, self.districts])
        lists.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [self.header, lists])
        stack.axis = .vertical
        stack.spacing = 8
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0)
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(stack)

        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: self.header.topAnchor),
            headerRow.leadingAnchor.constraint(equalTo: self.header.leadingAnchor),
            headerRow.trailingAnchor.constraint(equalTo: self.header.trailingAnchor, constant: -20),
            headerRow.bottomAnchor.constraint(equalTo: self.header.bottomAnchor),
            self.header.heightAnchor.constraint(equalToConstant: 44),
            stack.topAnchor.constraint(equalTo: self.view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableView === self.provinces ? 17 : 30
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = tableView === self.provinces ? "시도 \(indexPath.row + 1)" : "\(indexPath.row + 1)구"

        return cell
    }

    private func resetSelection() {
        [self.provinces, self.districts].forEach { tableView in
            tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: true)
        }
    }
}
