//
//  ComponentContext.swift
//  SwiftExtension
//
//  Created by 김동현 on 10/1/26.
//

import Foundation

/// 컴포넌트를 한 번 그리는 동안의 환경과 작업 수명입니다.
///
/// 호스트는 `updateView(_:context:)`를 부를 때마다 새 context를 만들고, 다음 갱신 직전이나
/// 화면에서 빠질 때 이전 context를 취소합니다. 이미지 요청처럼 갱신이 끝나도 이어지는 작업은
/// `task(priority:_:)`로 시작하거나 `onCancel(_:)`에 정리 동작을 등록해 이 수명에 묶습니다.
///
/// 참조 의미론이 필요해서 클래스로 만들었습니다. 비동기 작업이 끝난 뒤에도 같은 context로
/// `invalidateLayout()`을 불러야 하기 때문입니다.
@MainActor
public final class ComponentContext {

    // MARK: - Property

    private var cancellations: [() -> Void] = []
    private let layoutInvalidation: () -> Void

    /// 이 context가 취소됐는지 나타냅니다.
    private(set) var isCancelled = false



    // MARK: - Life Cycle

    /// 호스트가 레이아웃 무효화 동작을 넘겨 만듭니다.
    ///
    /// - Parameter layoutInvalidation: `invalidateLayout()`이 불렸을 때 호스트가 할 일입니다.
    init(layoutInvalidation: @escaping () -> Void = {}) {
        self.layoutInvalidation = layoutInvalidation
    }



    // MARK: - Interface

    /// 뷰의 크기가 바뀌었으니 다시 재 달라고 호스트에 요청합니다.
    ///
    /// 이미지를 받아 넣은 뒤처럼 갱신이 끝난 다음 크기가 바뀌었을 때 부릅니다.
    /// 취소된 context에서 부르면 아무 일도 하지 않습니다.
    ///
    /// - Complexity: O(1)입니다. 실제 재측정 비용은 호스트의 레이아웃 비용을 따릅니다.
    public func invalidateLayout() {
        guard !self.isCancelled else { return }

        self.layoutInvalidation()
    }

    /// 이번 수명이 끝날 때 실행할 정리 동작을 등록합니다.
    ///
    /// 등록한 동작은 등록한 순서대로 한 번만 실행됩니다. 이미 취소된 context에 등록하면 바로 실행합니다.
    ///
    /// - Parameter action: 수명이 끝날 때 실행할 동작입니다.
    /// - Complexity: 평균 O(1)입니다.
    public func onCancel(_ action: @escaping () -> Void) {
        guard !self.isCancelled else {
            action()
            return
        }

        self.cancellations.append(action)
    }

    /// 이번 수명 동안만 실행되는 비동기 작업을 시작합니다.
    ///
    /// context가 취소되면 작업도 취소됩니다. 작업 안에서 `Task.isCancelled`나
    /// `Task.checkCancellation()`으로 취소를 확인합니다.
    ///
    /// - Parameters:
    ///   - priority: 작업의 우선순위입니다. `nil`이면 현재 작업의 우선순위를 따릅니다.
    ///   - operation: 메인 액터에서 실행할 비동기 작업입니다.
    /// - Complexity: 평균 O(1)입니다.
    public func task(
        priority: TaskPriority? = nil,
        _ operation: @escaping @MainActor () async -> Void
    ) {
        let task = Task(priority: priority) { @MainActor in
            await operation()
        }
        self.onCancel { task.cancel() }
    }

    /// 등록한 정리 동작을 모두 실행하고 수명을 끝냅니다.
    ///
    /// 여러 번 불러도 정리 동작은 한 번만 실행됩니다.
    ///
    /// - Complexity: 등록한 동작의 개수를 n이라 할 때 O(n)입니다.
    func cancel() {
        guard !self.isCancelled else { return }

        self.isCancelled = true
        let pending = self.cancellations
        self.cancellations.removeAll()
        pending.forEach { $0() }
    }
}
