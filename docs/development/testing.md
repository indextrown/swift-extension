# swift-extension 테스트 안내

> 아래 명령은 이 저장소에서 실제로 실행해 성공한 명령이에요(Swift 6.3 툴체인, macOS). 새 명령을 적을 때도 실행해서 확인한 것만 적어요.
>
> 패키지는 `swift-tools-version: 5.9`로 빌드하지만, 테스트는 Swift Testing을 쓰므로 실행에는 Swift 6.0 이상 툴체인이 필요해요.

## 목차

- [테스트 구성](#테스트-구성)
- [실행 명령](#실행-명령)
- [테스트 작성 방법](#테스트-작성-방법)
- [자료구조 테스트 체크리스트](#자료구조-테스트-체크리스트)
- [성능과 Sanitizer 검증](#성능과-sanitizer-검증)
- [변경 후 기록](#변경-후-기록)

## 테스트 구성

| 항목 | 확인한 값 |
| --- | --- |
| 테스트 타깃 | `AlgorithmTests`, `LabsTests`, `SwiftExtensionTests` |
| 테스트 프레임워크 | Swift Testing (`import Testing`, `@Test`, `#expect`) |
| 실행 환경 | macOS에서 `swift test`로 실행해요. 시뮬레이터가 필요하지 않아요. |
| CI 검증 | `확인 필요`. `.github/workflows/`에는 릴리즈 워크플로만 있고 테스트 워크플로는 아직 없어요. |

각 테스트 타깃은 대응하는 product 하나에만 의존해요. 테스트에서 다른 모듈을 import해야 한다면 모듈 경계를 다시 확인해요.

## 실행 명령

```bash
# 전체 테스트
swift test

# 특정 테스트만 실행 (이름의 일부를 적어요)
swift test --filter packageVersionIsAvailable

# 릴리즈 구성으로 실행 (최적화된 코드의 동작 확인)
swift test -c release

# 빌드만 확인
swift build
swift build -c release
```

Xcode에서 확인하려면 `Package.swift`를 열고 `⌘U`로 실행해요. 데모 앱은 `Demo/AlgorithmDemo/README.md`의 `xcodebuild` 명령을 따라요.

## 테스트 작성 방법

Swift Testing을 사용해요. `XCTest`를 새로 추가하지 않아요.

```swift
import Testing
@testable import Algorithm

@Test func popReturnsNilWhenEmpty() {
    var stack = Stack<Int>()

    #expect(stack.pop() == nil)
}

@Test("요소를 넣은 역순으로 꺼냅니다", arguments: [[1], [1, 2], [1, 2, 3]])
func popReturnsElementsInReverseOrder(input: [Int]) {
    var stack = Stack(input)

    #expect(stack.pop() == input.last)
}
```

- 공개 API는 `import`로 테스트해요. 내부 구현을 확인해야 할 때만 `@testable import`를 써요.
- 테스트 이름은 검증하는 동작을 문장으로 적어요. `testStack1` 같은 이름을 쓰지 않아요.
- 하나의 `@Test`에서 하나의 동작을 확인해요. 여러 동작을 확인하려면 `arguments`로 입력을 나눠요.
- 실패했을 때 원인을 알 수 있도록 기대값과 실제값이 드러나는 표현식을 `#expect`에 넣어요.

## 자료구조 테스트 체크리스트

새 자료구조나 연산을 추가하면 아래를 확인해요.

- [ ] 빈 상태에서의 동작 (`isEmpty`, `count`, 제거 연산의 반환값)
- [ ] 요소가 하나일 때의 동작
- [ ] 여러 요소를 넣고 뺐을 때의 순서
- [ ] 인덱스·범위를 받는 API의 경계값 (첫 요소, 마지막 요소, 범위 밖)
- [ ] 값 의미론: 복사본을 수정해도 원본이 바뀌지 않아요.
- [ ] 제네릭 요소 타입을 바꿔도 동작해요 (값 타입과 참조 타입 모두)
- [ ] 표준 프로토콜을 채택했다면 그 프로토콜의 계약 (`Equatable`의 대칭성, `Collection` 순회 결과 등)
- [ ] 같은 동작을 하는 표준 라이브러리 타입과 결과가 같은지 비교

`precondition`으로 중단되는 조건은 테스트로 확인할 수 없어요. 대신 문서 주석에 조건을 적고, 쓰는 쪽이 피할 수 있게 해요.

## 성능과 Sanitizer 검증

성능을 주장하는 변경은 Release 구성에서 측정해요. 측정 방법과 기록 항목은 [성능 기준](../architecture/performance.md)에 있어요.

동시성이나 Unsafe 코드를 바꿨다면 Sanitizer로 확인해요. 아래 두 명령은 이 저장소에서 실행해 통과를 확인했어요.

```bash
# 데이터 경합 확인
swift test --sanitize=thread

# 메모리 오류 확인
swift test --sanitize=address
```

Sanitizer 실행은 일반 실행보다 느려요. 관련 변경이 있을 때만 돌리고, 결과를 PR에 적어요.

## 변경 후 기록

- 수정한 동작을 다루는 테스트와 실행 결과를 PR에 적어요.
- 자동 테스트로 확인하기 어려운 동작은 재현 단계와 관찰 결과를 적어요.
- 실행하지 못한 테스트는 통과했다고 적지 않아요. 이유와 남은 검증을 함께 적어요.

## 관련 문서

- [성능 기준](../architecture/performance.md): 측정 방법과 기록 항목
- [API 설계 규칙](../architecture/api-design.md): 공개 API 계약
- [Git 작업 흐름](gitflow.md): 검증 결과를 PR에 남기는 방법
