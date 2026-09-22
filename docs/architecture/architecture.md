# swift-extension 패키지 구조

> 이 문서는 `Package.swift`와 `Sources/` 실제 구성을 기준으로 적었어요. 계획 단계인 내용은 `계획`으로 표시했어요. 문서와 코드가 다르면 코드를 기준으로 작업하고 이 문서도 함께 고쳐요.

## 목차

- [이 패키지가 맡는 일](#이-패키지가-맡는-일)
- [현재 타깃 구성](#현재-타깃-구성)
- [모듈 경계 규칙](#모듈-경계-규칙)
- [의존성 방향](#의존성-방향)
- [계획 중인 UI 타깃](#계획-중인-ui-타깃)
- [새 자료구조를 추가하는 흐름](#새-자료구조를-추가하는-흐름)
- [Labs에서 정식 모듈로 옮기는 기준](#labs에서-정식-모듈로-옮기는-기준)
- [관련 문서](#관련-문서)

## 이 패키지가 맡는 일

`swift-extension`은 앱이 아니라 **Swift Package 라이브러리**예요. 다음 두 가지를 제공해요.

- 표준 라이브러리에 없거나, 특정 사용 패턴에 맞춰 더 빠르게 다시 구현한 **저수준 자료구조와 확장**
- UIKit·SwiftUI에서 **재사용할 수 있는 뷰와 컴포넌트** (계획)

앱의 화면 흐름, 네트워크 계층, 의존성 주입 컨테이너는 이 저장소의 관심사가 아니에요. 라이브러리를 쓰는 앱이 정할 일이므로 이 패키지 안에 그런 구조를 만들지 않아요.

## 현재 타깃 구성

`Package.swift` 기준이에요.

| Product | Target | 경로 | 맡는 일 |
| --- | --- | --- | --- |
| `Algorithm` | `Algorithm` | `Sources/Algorithm/` | 자료구조와 알고리즘 구현을 담아요. 지금은 `Stack`이 있어요. |
| `Labs` | `Labs` | `Sources/Labs/` | 아직 공개 API로 확정하지 않은 실험 구현과 Playground를 담아요. |
| `SwiftExtension` | `SwiftExtension` | `Sources/SwiftExtension/` | 패키지 수준 정보(`SwiftExtension.version`)를 담는 진입 모듈이에요. |
| `UIComponentsCore` | `UIComponentsCore` | `Sources/UIComponentsCore/` | UI 타깃 둘이 함께 쓰는 프레임워크 중립 계산을 담아요. `import Foundation`만 써요. 지금은 바텀시트의 단계·레이아웃·움직임 값이 있어요. |
| `UIKitExtension` | `UIKitExtension` | `Sources/UIKitExtension/` | UIKit 재사용 뷰와 확장을 담아요. 지금은 [바텀시트](../components/bottom-sheet.md) `BottomSheetController`가 있어요. |
| `SwiftUIExtension` | `SwiftUIExtension` | `Sources/SwiftUIExtension/` | SwiftUI 재사용 뷰와 수정자를 담아요. 지금은 [바텀시트](../components/bottom-sheet.md) `bottomSheet(detent:)`가 있어요. |
| — | `AlgorithmTests` | `Tests/AlgorithmTests/` | `Algorithm` 테스트 |
| — | `LabsTests` | `Tests/LabsTests/` | `Labs` 테스트 |
| — | `SwiftExtensionTests` | `Tests/SwiftExtensionTests/` | `SwiftExtension` 테스트 |
| — | `UIComponentsCoreTests` | `Tests/UIComponentsCoreTests/` | `UIComponentsCore` 테스트. macOS CI에서 돌아요 |
| — | `UIKitExtensionTests` | `Tests/UIKitExtensionTests/` | `UIKitExtension` 테스트 |
| — | `SwiftUIExtensionTests` | `Tests/SwiftUIExtensionTests/` | `SwiftUIExtension` 테스트 |

`Labs` 타깃은 `exclude: ["Stack"]`로 Playground 디렉터리를 빌드에서 제외해요. Playground를 새로 추가하면 `Package.swift`의 `exclude`도 함께 갱신해요.

빌드 설정은 다음과 같아요.

| 항목 | 값 |
| --- | --- |
| swift-tools-version | 5.9 |
| 언어 모드 | Swift 5 (tools-version 기본값) |
| 지원 플랫폼 | iOS 15, macOS 12, tvOS 15, watchOS 8 |

`Demo/AlgorithmDemo/`는 루트 패키지를 로컬 의존성으로 참조하는 macOS SwiftUI 데모 앱이에요. 라이브러리 타깃은 데모 앱을 참조하지 않아요.

## 모듈 경계 규칙

- 각 product는 **단독으로 `import`할 수 있어야 해요.** 사용자가 `import Algorithm`만 하고도 그 모듈의 기능을 모두 쓸 수 있어야 해요.
- 코어 모듈(`Algorithm`, `SwiftExtension`)은 **UIKit·SwiftUI·AppKit을 import하지 않아요.** 플랫폼 중립을 유지해 서버·CLI에서도 쓸 수 있게 해요.
- `Foundation` 의존도 필요할 때만 추가해요. 표준 라이브러리만으로 되는 구현에는 `import Foundation`을 넣지 않아요.
- 외부 서드파티 의존성은 기본적으로 추가하지 않아요. 필요하다고 판단되면 대안과 비용을 먼저 정리해 합의한 뒤 추가하고, 그 근거를 PR 본문에 적어요.
- 한 타입은 한 파일에 담고, 자료구조별로 디렉터리를 만들어요. 예: `Sources/Algorithm/Stack/Stack.swift`.

## 의존성 방향

```text
  ┌──────────────────┐   ┌──────────────────┐
  │  UIKitExtension  │   │ SwiftUIExtension │   UI 타깃. 서로 의존하지 않아요
  └─────────┬────────┘   └────────┬─────────┘
            └───────────┬─────────┘
                        ▼  @_exported로 다시 내보내요
              ┌──────────────────┐
              │ UIComponentsCore │   UI 공용 계산. Foundation만 써요
              └──────────────────┘

  ┌─────────────┐   ┌──────────────────┐
  │  Algorithm  │   │  SwiftExtension  │   플랫폼 중립 코어
  └─────────────┘   └──────────────────┘
         ▲
         │ 승격
   ┌───────────┐
   │   Labs    │   실험 구현
   └───────────┘
```

- UI 타깃 둘은 `UIComponentsCore`에 의존하고, 그 타입을 `@_exported import`로 다시 내보내요. 쓰는 쪽은 `import UIKitExtension` 하나로 `BottomSheetLayout`까지 써요.
- `UIComponentsCore`는 UIKit·SwiftUI를 모르는 계산만 담아요. 두 UI 타깃이 같은 코드를 쓰게 되면 여기로 내려요. 그래서 macOS `swift test`와 CI에서도 검증돼요.
- UI 타깃은 `Algorithm`, `SwiftExtension`에도 의존할 수 있어요. 코어 모듈이 UI 타깃에 의존하지 않아요.
- `Labs`는 어떤 타깃도 의존하지 않아요. 실험이 끝나면 코드를 코어 모듈로 옮겨요.
- 순환 의존이 필요해 보이면 타입의 위치나 책임을 잘못 나눈 신호예요. 공통 부분을 아래 계층으로 내려요.

## UI 타깃

UIKit·SwiftUI 재사용 뷰는 `UIKitExtension`, `SwiftUIExtension` 두 타깃으로 나눠 담아요. product도 각각 분리해서, SwiftUI만 쓰는 앱이 UIKit 쪽 코드를 링크하지 않게 해요. 둘이 함께 쓰는 계산은 `UIComponentsCore`에 두고 각 타깃이 다시 내보내요. 설계 규칙은 [UI 모듈 가이드](ui-modules.md)에 있어요.

## 새 자료구조를 추가하는 흐름

1. 표준 라이브러리나 `swift-collections`로 충분한지 먼저 확인해요. 충분하다면 만들지 않아요.
2. 확정되지 않은 설계는 `Sources/Labs/`에서 시작해요. 바로 공개할 설계라면 `Sources/Algorithm/<이름>/`에 파일을 만들어요.
3. 공개 API와 복잡도를 [API 설계 규칙](api-design.md)에 맞춰 정해요.
4. 테스트를 같은 작업에서 추가해요. 빈 상태·단일 요소·경계값을 포함해요. [테스트](../development/testing.md)를 참고해요.
5. 성능을 주장하는 변경이라면 Release 빌드에서 측정해요. [성능 기준](performance.md)을 참고해요.
6. PR 템플릿의 `자료구조·알고리즘 영향` 항목에 시간·공간 복잡도와 호환성을 적어요.

## Labs에서 정식 모듈로 옮기는 기준

아래를 모두 만족하면 `Labs`에서 `Algorithm` 같은 정식 모듈로 옮겨요.

- [ ] 공개 API 이름과 시그니처가 더 바뀌지 않을 만큼 정리됐어요.
- [ ] 경계값을 포함한 테스트가 있어요.
- [ ] 문서 주석에 동작과 복잡도를 적었어요.
- [ ] 같은 기능을 하는 표준 라이브러리 타입과 비교해 존재 이유를 설명할 수 있어요.

옮길 때는 접근 제어를 `internal`에서 `public`으로 올리고, 모듈을 옮겼다는 사실을 PR 본문에 적어요.

## 관련 문서

- [API 설계 규칙](api-design.md): 공개 API 이름, 접근 제어, 동시성, 호환성
- [성능 기준](performance.md): 값 의미론, 할당, 측정 방법
- [UI 모듈 가이드](ui-modules.md): UIKit·SwiftUI 타깃 설계 규칙
- [바텀시트](../components/bottom-sheet.md): `UIKitExtension`의 첫 컴포넌트
- [Swift 스타일](../development/swiftstyle.md): 코드 작성 규칙
- [테스트](../development/testing.md): 테스트 타깃과 실행 명령
