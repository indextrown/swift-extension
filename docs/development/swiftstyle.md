# swift-extension Swift 스타일 가이드

> 이 라이브러리의 코드 작성 규칙이에요. 예시는 자료구조·확장 구현을 기준으로 적었어요. UIKit·SwiftUI 타깃에만 해당하는 규칙은 [UI 모듈 가이드](../architecture/ui-modules.md)를 함께 봐요.

## 목차

- [파일 헤더](#파일-헤더)
- [코드 포맷팅](#코드-포맷팅)
- [네이밍](#네이밍)
- [코드 스타일](#코드-스타일)
- [문서 주석](#문서-주석)
- [MARK 주석](#mark-주석)

---

## 파일 헤더

모든 Swift 파일은 다음 형식의 파일 헤더로 시작해요.

```swift
//
//  Stack.swift
//  SwiftExtension
//
//  Created by 김동현 on 8/5/26.
//
```

| 항목 | 설명 | 예시 |
| --- | --- | --- |
| `FileName.swift` | 파일 이름을 그대로 적어요. | `Stack.swift` |
| `SwiftExtension` | 패키지 이름을 적어요. 타깃 이름이 아니에요. | `SwiftExtension` |
| `Created by ... on m/d/yy.` | 작성자와 생성일을 적어요. | `Created by 김동현 on 8/5/26.` |

- 날짜는 `m/d/yy` 형식으로 적어요.
- Copyright 줄은 생략해요.
- 헤더 다음에 빈 줄 하나를 두고 `import`를 시작해요. import가 없으면 선언을 바로 적어요.

---

## 코드 포맷팅

### import

표준 라이브러리만으로 되는 파일에는 `import`를 넣지 않아요. 필요한 모듈만 적고, 알파벳 순으로 정렬해요.

```swift
// Preferred: Foundation이 필요할 때만 적어요.
import Foundation

// Preferred: UI 타깃에서는 조건부로 import해요.
#if canImport(UIKit)
import UIKit
#endif

// Avoid: 쓰지 않는 모듈을 습관적으로 적지 않아요.
import Foundation
import Combine
```

### 들여쓰기

- 들여쓰기는 공백 4칸을 사용해요.
- 매개변수가 여러 개인 함수 선언과 호출은 매개변수별로 줄을 바꾸어요.

```swift
// Preferred
public mutating func replaceSubrange<C: Collection>(
    _ subrange: Range<Int>,
    with newElements: C
) where C.Element == Element {
    // ...
}

// Preferred
buffer.initialize(
    from: source,
    count: source.count
)
```

#### 클로저

- 클로저가 하나면 trailing closure를 사용해요.
- 클로저 인자가 두 개 이상이면 소괄호를 세로로 열고 닫아요.

```swift
// Preferred: 클로저 하나
let evens = numbers.filter { $0.isMultiple(of: 2) }

// Preferred: 클로저 둘 이상
storage.withUnsafeMutableBufferPointer(
    { buffer in
        buffer.update(repeating: .zero)
    },
    completion: { result in
        switch result {
        case .success:
            break

        case .failure(let error):
            print(error)
        }
    }
)
```

### 띄어쓰기

#### 콜론(`:`)

삼항 연산자를 제외하고 오른쪽에만 공백 한 칸을 두어요.

```swift
// Preferred
public struct Stack<Element>: Sendable { /* ... */ }
let counts: [String: Int] = ["a": 1]

// Avoid
public struct Stack<Element>:Sendable { /* ... */ }
```

#### 삼항 연산자

연산자 양옆에 공백 한 칸을 두어요.

```swift
// Preferred
let capacity = count > 0 ? count * 2 : 1
```

#### 쉼표(`,`)

오른쪽에만 공백 한 칸을 두어요.

```swift
// Preferred
let elements = ["A", "B", "C"]
stack.replaceSubrange(0..<2, with: elements)
```

#### 연산자

연산자 양옆에 공백 한 칸을 두어요. 범위 연산자는 붙여 써요.

```swift
// Preferred
let middle = (low + high) / 2
for index in 0..<count { /* ... */ }
```

#### 리턴 타입(`->`)

기호 양옆에 공백 한 칸을 두어요.

```swift
// Preferred
func peek() -> Element? { /* ... */ }
let transform: (Element) -> Element
```

#### 한 줄 클로저

중괄호 안쪽 앞뒤에 공백 한 칸을 두어요.

```swift
// Preferred
numbers.filter { $0 % 2 == 0 }
guard let last = storage.last else { return nil }

// Avoid
numbers.filter {$0 % 2 == 0}
```

### 줄 바꿈

#### 함수

```swift
// 매개변수 1개: 한 줄
public mutating func push(_ element: Element) {
    // ...
}

// 매개변수 2개 이상: 줄 바꿈
private mutating func moveElements(
    from source: Int,
    to destination: Int,
    count: Int
) {
    // ...
}
```

#### 제네릭 제약

제약이 길어지면 `where` 절을 다음 줄에 적어요.

```swift
// Preferred
public init<S: Sequence>(_ elements: S)
where S.Element == Element {
    self.storage = Array(elements)
}
```

#### 여는 중괄호

1TBS 스타일로 선언과 같은 줄에 열어요.

```swift
// Preferred
public func makeIterator() -> Iterator {
    // ...
}

// Avoid
public func makeIterator() -> Iterator
{
    // ...
}
```

### 소괄호

불필요한 소괄호는 생략해요.

```swift
// Preferred
if count > 0 { /* ... */ }
switch state { /* ... */ }

// Avoid
if (count > 0) { /* ... */ }
```

---

## 네이밍

### 표기법

| 표기법 | 적용 대상 |
| --- | --- |
| **UpperCamelCase** | 타입, 프로토콜, 제네릭 매개변수 |
| **lowerCamelCase** | 변수, 상수, 함수, enum case |

```swift
// UpperCamelCase
public struct RingBuffer<Element> { /* ... */ }
public protocol PriorityQueueProtocol { /* ... */ }

// lowerCamelCase
private var writeIndex = 0
public mutating func removeFirst() -> Element { /* ... */ }
case underflow
```

### 명명법

#### 표준 라이브러리 이름을 우선해요

같은 의미의 표준 라이브러리 이름이 있으면 그 이름을 써요. 자세한 기준은 [API 설계 규칙](../architecture/api-design.md)에 있어요.

```swift
// Preferred
var isEmpty: Bool
var count: Int
mutating func removeAll(keepingCapacity: Bool = false)

// Avoid
var empty: Bool
var size: Int
mutating func clear()
```

#### 동사와 명사

부수 효과가 있는 연산은 동사로, 값을 돌려주기만 하는 멤버는 명사로 적어요.

```swift
// Preferred
public mutating func push(_ element: Element)
public var top: Element?

// Avoid
public mutating func pushed(_ element: Element)
public func getTop() -> Element?
```

#### 변경형과 비변경형

표준 라이브러리의 활용형 규칙을 따라요. 변경형은 동사 원형, 비변경형은 `-ed`나 `-ing` 형태로 적어요.

```swift
// Preferred
public mutating func reverse()
public func reversed() -> Self
```

#### 약어

약어는 대문자로 적어요. 이름의 첫 글자로 시작하면 소문자를 사용해요.

```swift
// Preferred
elementID, urlString, utf8Count

// Avoid
elementId, URLString
```

#### 명확한 이름

이름이 길어지더라도 의미를 완전하게 드러내요. 다만 문맥에서 이미 드러나는 정보는 반복하지 않아요.

```swift
// Preferred
public mutating func removeFirst(_ count: Int)
private var headIndex: Int

// Avoid
public mutating func removeFirstElementsOfBuffer(_ count: Int)
private var h: Int
```

#### 제네릭 매개변수

표준 라이브러리 관례를 따라 의미가 드러나는 이름을 써요.

```swift
// Preferred
public struct Stack<Element> { /* ... */ }
public init<S: Sequence>(_ elements: S) where S.Element == Element

// Avoid
public struct Stack<T> { /* ... */ }
```

#### 프로토콜

설명형은 명사를, 기능형은 `able`, `ible`, `ing`로 끝나는 이름을 써요.

```swift
// Preferred
Queueable, BufferBacked

// Avoid
QueueProtocolType
```

---

## 코드 스타일

### 타입 추론

가능한 경우 타입 추론을 사용해요. 리터럴의 타입이 모호하면 명시해요.

```swift
// Preferred
var storage: [Element] = []
let threshold = 0.75

// Avoid
var storage = Array<Element>()
```

### 연산 프로퍼티와 함수

다음 조건을 모두 만족하면 함수 대신 연산 프로퍼티를 사용해요.

- 매개변수가 없어요.
- 부수 효과가 없어요.
- O(1) 복잡도로 계산해요.

```swift
// Preferred
public var isEmpty: Bool {
    self.storage.isEmpty
}

// Avoid: O(n) 계산은 메서드로 만들어요.
public var sum: Int {
    self.storage.reduce(0, +)
}
```

### `self` 사용

사용할 수 있는 모든 곳에서 `self`를 사용해요.

```swift
// Preferred
self.storage.append(element)

// Avoid
storage.append(element)
```

### 튜플 값 네이밍

```swift
// Preferred
func bounds() -> (lower: Int, upper: Int)

// Avoid
func bounds() -> (Int, Int)
```

### 배열과 딕셔너리

제네릭 축약 표기를 사용해요.

```swift
// Preferred
var elements: [Element]
var indices: [String: Int]

// Avoid
var elements: Array<Element>
```

### `final` 사용

상속할 필요가 없으면 `final`을 적용해요. 공개 클래스는 `public final class`를 기본으로 해요.

```swift
// Preferred
final class Storage<Element> { /* ... */ }
```

### 프로토콜 채택 분리

`extension`과 `// MARK:`로 역할별 구현을 분리해요. 조건부 준수도 각각 나눠 적어요.

```swift
// Preferred
extension Stack: Sequence { /* ... */ }
extension Stack: Equatable where Element: Equatable {}

// Avoid
public struct Stack<Element>: Sequence, Equatable, CustomStringConvertible { /* ... */ }
```

### `switch-case`

- 새 case를 추가했을 때 누락을 발견할 수 있도록 `default`를 지양해요.
- 여러 case를 한 줄에 나열하지 않아요.
- 각 case 사이에 빈 줄 하나를 두어요.

```swift
// Preferred
switch position {
case .front:
    return self.storage.first

case .back:
    return self.storage.last
}
```

### `guard` 문

```swift
// 조건 1개: 한 줄
guard !self.isEmpty else { return nil }

// 조건 2개 이상: 각 조건 줄 바꿈
guard
    let first = self.storage.first,
    let last = self.storage.last
else {
    return nil
}
```

### 접근 제어

- 기본은 `internal`이에요. `internal`은 생략해요.
- 외부에서 쓸 이유를 설명할 수 있을 때만 `public`으로 올려요.
- 내부 저장소와 도우미 메서드에는 `private`를 적극적으로 사용해요.

```swift
// Preferred
public struct Stack<Element> {
    private var storage: [Element]

    func makeUniqueIfNeeded() { /* internal은 생략해요 */ }
}

// Avoid
internal func makeUniqueIfNeeded()
```

#### `private(set)`

```swift
// Preferred
public private(set) var capacity = 0

// Avoid
private var _capacity = 0
public var capacity: Int { self._capacity }
```

#### `private extension` 금지

`private extension`을 사용하지 않고 각 함수에 `private`를 명시해요.

```swift
// Preferred
extension Stack {

    private mutating func growIfNeeded() {
        // ...
    }
}

// Avoid
private extension Stack {

    mutating func growIfNeeded() {
        // ...
    }
}
```

### 주석

코드 옆에 주석을 적을 때는 코드와 주석 사이에 공백 한 칸만 두어요.

```swift
// Preferred
let capacity = count * 2 // 재할당 횟수를 줄여요

// Avoid
let capacity = count * 2   // 재할당 횟수를 줄여요
```

`// TODO:`나 `// FIXME:`를 남길 때는 무엇을 언제 해결할지 함께 적어요.

---

## 문서 주석

공개 API에는 `///` 문서 주석을 적어요. `-합니다`체로 적고 복잡도를 함께 남겨요. 항목별 기준은 [API 설계 규칙](../architecture/api-design.md)에 있어요.

```swift
/// 스택의 맨 위 요소를 제거하고 반환합니다.
///
/// 스택이 비어 있으면 `nil`을 반환합니다.
///
/// - Returns: 제거한 요소입니다.
/// - Complexity: 평균 O(1)입니다.
public mutating func pop() -> Element? {
    self.storage.popLast()
}
```

- 첫 줄은 한 문장 요약이에요. 빈 `///` 줄을 두고 설명을 이어 적어요.
- 매개변수가 둘 이상이면 `- Parameters:` 목록으로 적어요.
- 시간 복잡도는 모든 공개 연산에 적어요. 공간을 추가로 쓰면 공간 복잡도도 적어요.
- `internal`·`private` 선언에도 의도를 적을 수 있어요. 복잡도 표기는 공개 API에서 지켜요.

---

## MARK 주석

### 외부 MARK

최상위 선언 사이에 있는 MARK는 위로 세 줄, 아래로 한 줄을 띄어요. `import` 바로 아래의 첫 MARK는 위로 한 줄만 띄어요.

```swift
public struct Stack<Element> { /* ... */ }



// MARK: - Sequence

extension Stack: Sequence { /* ... */ }



// MARK: - Equatable

extension Stack: Equatable where Element: Equatable {}
```

### 내부 MARK

타입 안의 첫 MARK는 여는 중괄호 다음에 한 줄을 띄어요. 이후 MARK는 이전 섹션과 세 줄을 띄어요.

```swift
public struct RingBuffer<Element> {

    // MARK: - Property

    private var storage: [Element?]



    // MARK: - Life Cycle

    public init(capacity: Int) {
        // ...
    }



    // MARK: - Private

    private mutating func advance() {
        // ...
    }
}
```

### 표준 MARK 섹션명

| 섹션명 | 용도 |
| --- | --- |
| `Property` | 저장 프로퍼티와 상수를 두어요. |
| `Life Cycle` | `init`, `deinit`을 두어요. |
| `Interface` | 외부에 공개하는 연산을 두어요. |
| `Private` | 내부에서만 쓰는 `private` 메서드를 두어요. |
| `Conformance` | 프로토콜 준수 구현을 두어요. 프로토콜 이름을 MARK로 적어도 돼요. |
| `UI` | UI 타깃에서 뷰의 속성·제약 설정을 두어요. |

---

## 관련 문서

- [API 설계 규칙](../architecture/api-design.md): 공개 API 이름과 접근 제어
- [패키지 구조](../architecture/architecture.md): 모듈 경계와 의존성
- [UI 모듈 가이드](../architecture/ui-modules.md): UIKit·SwiftUI 타깃 규칙
- [테스트](testing.md): 테스트 타깃과 실행 명령
