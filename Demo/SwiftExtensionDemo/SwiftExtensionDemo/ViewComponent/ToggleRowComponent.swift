//
//  ToggleRowComponent.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/1/26.
//

import UIKit
import UIKitComponents

/// 제목과 스위치 한 줄을 그리는 평범한 UIKit 뷰입니다.
final class ToggleRowView: UIView {

    // MARK: - Property

    let titleLabel = UILabel()
    let toggle = UISwitch()

    /// 스위치 값이 바뀌면 부릅니다.
    var onChange: ((Bool) -> Void)?



    // MARK: - Life Cycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.setAttribute()
        self.setConstraint()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:)는 지원하지 않습니다.")
    }



    // MARK: - Action

    @objc
    private func didToggle() {
        self.onChange?(self.toggle.isOn)
    }



    // MARK: - UI

    private func setAttribute() {
        self.backgroundColor = .secondarySystemBackground
        self.layer.cornerRadius = 14
        self.layer.cornerCurve = .continuous

        self.titleLabel.font = .preferredFont(forTextStyle: .body)
        self.titleLabel.adjustsFontForContentSizeCategory = true
        self.titleLabel.numberOfLines = 0

        self.toggle.addTarget(self, action: #selector(self.didToggle), for: .valueChanged)
    }

    private func setConstraint() {
        let stackView = UIStackView(arrangedSubviews: [self.titleLabel, self.toggle])
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: self.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -12),
        ])
    }
}



// MARK: - Component

/// 스위치 한 줄 컴포넌트입니다.
///
/// 값이 바뀌면 `onChange`로 알리고, 화면은 쓰는 쪽이 새 `isOn`으로 다시 넣어 줄 때 바뀝니다.
/// 클로저를 담아서 `Equatable`이 아니므로 매번 갱신합니다.
struct ToggleRowComponent: ViewComponent {

    let title: String
    let isOn: Bool
    let onChange: (Bool) -> Void

    func makeView() -> ToggleRowView {
        return ToggleRowView()
    }

    func updateView(_ view: ToggleRowView, context: ComponentContext) {
        view.titleLabel.text = self.title
        view.toggle.accessibilityLabel = self.title
        if view.toggle.isOn != self.isOn {
            view.toggle.setOn(self.isOn, animated: false)
        }
        view.onChange = self.onChange
    }
}
