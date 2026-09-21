//
//  Stack.swift
//  SwiftExtension
//
//  Created by 김동현 on 8/5/26.
//

import Foundation

public struct Stack<Element> {
    private var storage: [Element]
    
    init() {
        self.storage = []
    }
    
    /// 전달된 요소로 스택을 생성합니다.
    ///
    /// 전달된 `Sequence`의 마지막 요소가 스택의 top이 됩니다.
    ///
    /// 시간 복잡도: O(n)
    /// 공간 복잡도: O(n)
    init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.storage = Array(elements)
    }
}

extension Stack {
    
    /// 스택이 비어 있는지 확인합니다.
    ///
    /// 시간 복잡도: O(1)
    public var isEmpty: Bool {
        storage.isEmpty
    }

    /// 스택에 저장된 요소의 개수입니다.
    ///
    /// 시간 복잡도: O(1)
    public var count: Int {
        storage.count
    }

    /// 스택의 맨 위 요소입니다.
    ///
    /// 빈 스택이라면 `nil`을 반환합니다.
    ///
    /// 시간 복잡도: O(1)
    public var top: Element? {
        storage.last
    }
}

extension Stack {
    
    /// 스택의 맨 위에 요소 하나를 추가합니다.
    ///
    /// 배열의 저장 용량이 충분하면 O(1)입니다.
    /// 저장 용량을 늘려야 하는 경우 기존 요소를 복사하므로 O(n)입니다.
    ///
    /// 평균 시간 복잡도: O(1)
    /// 최악 시간 복잡도: O(n)
    /// 추가 공간 복잡도: 평균 O(1), 재할당 시 O(n)
    public mutating func push(_ element: Element) {
        storage.append(element)
    }
    
    /// 여러 요소를 순서대로 스택에 추가합니다.
    ///
    /// 전달된 `Sequence`의 마지막 요소가 새로운 top이 됩니다.
    ///
    /// - Parameter elements: 추가할 요소의 시퀀스
    ///
    /// 평균 시간 복잡도: O(k)
    /// 최악 시간 복잡도: O(n + k)
    /// 추가 공간 복잡도: 재할당이 없다면 O(1), 재할당 시 O(n + k)
    public mutating func push<S: Sequence>(
        contentsOf elements: S
    ) where S.Element == Element {
        storage.append(contentsOf: elements)
    }
    
    /// 스택의 맨 위 요소를 제거하고 반환합니다.
    ///
    /// 빈 스택이라면 `nil`을 반환합니다.
    ///
    /// 시간 복잡도: O(1)
    /// 추가 공간 복잡도: O(1)
    @discardableResult
    public mutating func pop() -> Element? {
        return storage.removeLast()
    }
    
    /// 맨 위에서 지정한 개수만큼 요소를 제거하고 반환합니다.
    ///
    /// 반환되는 배열은 top부터 아래 방향으로 정렬됩니다.
    ///
    /// ```swift
    /// var stack = Stack([10, 20, 30])
    /// let removed = stack.pop(2)
    ///
    /// // removed == [30, 20]
    /// ```
    ///
    /// 요청한 개수가 현재 요소 수보다 많으면 스택을 변경하지 않고
    /// `nil`을 반환합니다.
    ///
    /// - Parameter amount: 제거할 요소의 개수
    /// - Returns: top부터 정렬된 제거 요소 또는 `nil`
    ///
    /// 시간 복잡도: O(k)
    /// 추가 공간 복잡도: O(k)
    @discardableResult
    public mutating func pop(_ amount: Int) -> [Element]? {
        precondition(amount >= 0, "제거할 개수는 0 이상이어야 합니다.")
        
        guard amount <= storage.count else {
            return nil
        }
        
        guard amount > 0 else {
            return []
        }
        
        let startIndex = storage.count - amount
        
        let removedElements = Array(
            storage[startIndex...].reversed()
        )
        
        storage.removeSubrange(startIndex...)
        
        return removedElements
    }
}
