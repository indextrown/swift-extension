//
//  NoticeComponent.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/1/26.
//

import SwiftUI
import UIKit
import UIKitComponents

/// 공지 한 장을 그리는 평범한 UIKit 뷰입니다. 컴포넌트에 대해 아무것도 모릅니다.
final class NoticeView: UIView {

    // MARK: - Property

    let iconView = UIImageView()
    let titleLabel = UILabel()
    let messageLabel = UILabel()



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



    // MARK: - UI

    private func setAttribute() {
        self.backgroundColor = .secondarySystemBackground
        self.layer.cornerRadius = 14
        self.layer.cornerCurve = .continuous
        self.isAccessibilityElement = true

        self.iconView.tintColor = .systemOrange
        self.iconView.contentMode = .scaleAspectFit

        self.titleLabel.font = .preferredFont(forTextStyle: .headline)
        self.titleLabel.adjustsFontForContentSizeCategory = true
        self.titleLabel.numberOfLines = 0

        self.messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        self.messageLabel.adjustsFontForContentSizeCategory = true
        self.messageLabel.textColor = .secondaryLabel
        self.messageLabel.numberOfLines = 0
    }

    private func setConstraint() {
        let textStackView = UIStackView(arrangedSubviews: [self.titleLabel, self.messageLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 4

        let rowStackView = UIStackView(arrangedSubviews: [self.iconView, textStackView])
        rowStackView.spacing = 12
        rowStackView.alignment = .top
        rowStackView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(rowStackView)

        NSLayoutConstraint.activate([
            self.iconView.widthAnchor.constraint(equalToConstant: 24),
            self.iconView.heightAnchor.constraint(equalToConstant: 24),

            rowStackView.topAnchor.constraint(equalTo: self.topAnchor, constant: 16),
            rowStackView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            rowStackView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            rowStackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -16),
        ])
    }
}



// MARK: - Component

/// 공지 컴포넌트입니다. 상태만 담아서 `Equatable`이고, 같은 값이 다시 들어오면 갱신을 건너뜁니다.
///
/// `View`를 함께 채택해서 SwiftUI에는 `NoticeComponent(...)` 그대로 넣습니다.
/// `View`의 `body`와 겹치지 않도록 본문 프로퍼티 이름은 `message`로 지었습니다.
struct NoticeComponent: ViewComponent, Equatable {

    let systemImage: String
    let title: String
    let message: String

    func makeView() -> NoticeView {
        return NoticeView()
    }

    func updateView(_ view: NoticeView, context: ComponentContext) {
        view.iconView.image = UIImage(systemName: self.systemImage)
        view.titleLabel.text = self.title
        view.messageLabel.text = self.message
        view.accessibilityLabel = "\(self.title), \(self.message)"
    }
}

extension NoticeComponent: View {}
