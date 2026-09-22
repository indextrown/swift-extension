//
//  PlaceListViewController.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import UIKit

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
