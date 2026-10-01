//
//  Notice.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/1/26.
//

/// 데모에 쓰는 공지 데이터입니다.
struct Notice: Hashable, Identifiable {

    let id: Int
    let systemImage: String
    let title: String
    let shortMessage: String
    let longMessage: String

    /// 글 길이를 골라 컴포넌트로 바꿉니다. 같은 컴포넌트를 UIKit과 SwiftUI 화면이 함께 씁니다.
    func component(isExpanded: Bool) -> NoticeComponent {
        return NoticeComponent(
            systemImage: self.systemImage,
            title: self.title,
            message: isExpanded ? self.longMessage : self.shortMessage
        )
    }
}



// MARK: - Sample

extension Notice {

    static let headline = Notice(
        id: 0,
        systemImage: "megaphone.fill",
        title: "오늘 밤 점검이 있어요",
        shortMessage: "00:00부터 02:00까지 접속할 수 없어요.",
        longMessage: "00:00부터 02:00까지 서버 점검으로 접속할 수 없어요. 점검 중에 보낸 요청은 저장되지 않으니, 진행 중인 작업은 점검 전에 마무리해 주세요. 점검이 끝나면 앱을 다시 열어 주세요."
    )

    static let samples: [Notice] = (1...12).map { index in
        Notice(
            id: index,
            systemImage: index.isMultiple(of: 2) ? "bell.fill" : "doc.text.fill",
            title: "공지 \(index)",
            shortMessage: "한 줄 요약이에요.",
            longMessage: String(repeating: "길게 펼친 공지 \(index)번의 본문이에요. ", count: index % 4 + 2)
        )
    }
}
