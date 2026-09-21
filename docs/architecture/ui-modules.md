# swift-extension UI 모듈 가이드

> UIKit·SwiftUI 재사용 뷰 타깃의 설계 규칙이에요. 두 타깃은 만들어 뒀고 아직 공개 선언이 없어요. 컴포넌트를 추가할 때 이 규칙을 따라요.

## 목차

- [타깃 구성 계획](#타깃-구성-계획)
- [의존성 규칙](#의존성-규칙)
- [플랫폼 분기와 가용성](#플랫폼-분기와-가용성)
- [뷰 API 설계 규칙](#뷰-api-설계-규칙)
- [UIKit 뷰 규칙](#uikit-뷰-규칙)
- [SwiftUI 뷰 규칙](#swiftui-뷰-규칙)
- [확인하는 방법](#확인하는-방법)
- [타깃을 추가할 때](#타깃을-추가할-때)

## 타깃 구성

| Product | Target | 경로 | 담을 내용 |
| --- | --- | --- | --- |
| `UIKitExtension` | `UIKitExtension` | `Sources/UIKitExtension/` | UIKit 재사용 뷰, `UIView`·`UIViewController` 확장 |
| `SwiftUIExtension` | `SwiftUIExtension` | `Sources/SwiftUIExtension/` | SwiftUI 재사용 뷰, `View` 확장, `ViewModifier` |

- product를 각각 따로 두었어요. 쓰는 쪽이 필요한 product만 의존성에 추가하면 다른 쪽은 빌드도 링크도 되지 않아요. SwiftUI만 쓰는 앱이 UIKit 심볼을 링크할 이유가 없어요.
- 같은 컴포넌트를 두 프레임워크로 제공할 때는 표시 로직을 각 타깃에 각각 두고, 계산·상태 규칙처럼 UI와 무관한 부분만 코어 모듈로 내려요.
- 최소 배포 타깃은 패키지 전체 설정(iOS 15, macOS 12, tvOS 15, watchOS 8)을 그대로 따라요. 더 높은 버전이 필요한 API에는 `platforms`를 올리지 말고 선언별로 `@available`을 붙여요.

## 의존성 규칙

- UI 타깃은 `Algorithm`, `SwiftExtension` 같은 코어 모듈에 의존할 수 있어요.
- 코어 모듈은 UI 타깃에 의존하지 않아요. UIKit·SwiftUI를 import하지도 않아요.
- `UIKitExtension`과 `SwiftUIExtension`은 서로 의존하지 않아요. 공통 코드가 생기면 코어 모듈로 내리거나, 공통 타깃을 새로 만드는 것을 먼저 논의해요.
- 외부 UI 라이브러리(SnapKit 등)를 의존성으로 추가하지 않아요. 레이아웃은 표준 API로 작성해요.

## 플랫폼 분기와 가용성

UI 프레임워크는 플랫폼마다 존재 여부가 달라요. 타깃 전체가 빌드되지 않는 일이 없도록 분기를 명시해요.

```swift
#if canImport(UIKit)
import UIKit

// UIKit에서만 쓰는 구현
#endif
```

- watchOS에는 `UIKit`의 상당 부분이 없어요. `#if canImport(UIKit) && !os(watchOS)`처럼 필요한 조건을 함께 적어요.
- macOS에서만 다른 동작이 필요하면 `#if os(macOS)`로 분기하고, 두 경로의 동작 차이를 문서 주석에 적어요.
- 특정 OS 버전 이상에서만 쓸 수 있는 API에는 `@available(iOS 16, *)`처럼 최소 버전을 적어요. 타깃 전체 배포 버전을 올리지 않아요.

## 뷰 API 설계 규칙

- 뷰의 표시 값은 **주입받아요.** 뷰 안에서 네트워크 호출이나 전역 상태 접근을 하지 않아요.
- 색·폰트·간격을 하드코딩하지 않아요. 기본값이 있는 설정 타입을 만들고, 쓰는 쪽이 바꿀 수 있게 해요.

```swift
// Preferred: 설정을 값으로 주입받아요.
public struct BadgeStyle {
    public var backgroundColor: UIColor
    public var cornerRadius: CGFloat

    public init(backgroundColor: UIColor = .systemBlue, cornerRadius: CGFloat = 8) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
    }
}
```

- 레이아웃 소유권을 정해요. 컴포넌트가 자기 내부 배치만 책임지고, 바깥 위치는 쓰는 쪽이 정하게 해요.
- 문자열은 하드코딩하지 않아요. 표시할 텍스트는 주입받아요.
- 접근성 레이블과 동적 타입 대응을 기본으로 넣어요. 접근성 처리를 쓰는 쪽에 미루지 않아요.
- 공개 API 이름, 접근 제어, 문서 주석 규칙은 [API 설계 규칙](api-design.md)을 그대로 따라요.

## UIKit 뷰 규칙

- 재사용 뷰는 `public final class`로 만들고 `@MainActor`를 명시해요.
- `init(coder:)`만 지원하는 형태로 만들지 않아요. 코드로 생성하는 초기화를 기본으로 제공해요.
- Auto Layout 제약은 뷰 내부에서 활성화하고, `translatesAutoresizingMaskIntoConstraints = false`를 잊지 않아요.
- 셀처럼 재사용되는 뷰에는 `prepareForReuse()`에서 상태를 되돌리는 코드를 넣어요.
- 스타일 설정(`setAttribute`)과 제약 설정(`setConstraint`)을 분리하고, `// MARK: - UI` 섹션에 모아요.

## SwiftUI 뷰 규칙

- 뷰는 `public struct`로 만들고, 저장 프로퍼티는 `private`로 두되 `public init`을 제공해요.
- 상태를 뷰가 소유할지(`@State`) 쓰는 쪽이 소유할지(`@Binding`) 명확히 정해요. 재사용 컴포넌트는 대개 `@Binding`이 맞아요.
- 단독 뷰보다 `ViewModifier`가 맞는 기능이면 `ViewModifier`로 만들고, `View` 확장 메서드로 감싸 제공해요.
- `#Preview`를 같은 파일에 넣어 최소 하나의 표시 예를 남겨요.
- 뷰 안에서 `DispatchQueue.main.async` 같은 우회 없이, 액터 격리 규칙에 맞게 작성해요.

## 확인하는 방법

- 두 UI 타깃도 `swift build`와 `swift test`로 컴파일을 확인해요. 시뮬레이터가 필요한 검증은 `Demo/`의 데모 앱에서 해요.
- 표시 결과는 스크린샷이나 프리뷰로 확인하고, 확인한 플랫폼과 OS 버전을 PR에 적어요.
- `확인 필요`: iOS 시뮬레이터 빌드를 CI에서 돌릴지 여부. 현재 `.github/workflows/`에는 릴리즈 워크플로만 있어요. macOS에서 `swift test`만 돌리면 `#if canImport(UIKit)`로 감싼 코드는 컴파일되지 않으니, UIKit 컴포넌트가 늘어나면 시뮬레이터 빌드를 검토해요.

## 컴포넌트를 추가할 때

1. 어느 타깃에 넣을지 정해요. UIKit 뷰는 `UIKitExtension`, SwiftUI 뷰는 `SwiftUIExtension`이에요. 둘 다 필요하면 각각 구현하고 공통 계산 로직만 코어 모듈로 내려요.
2. `Sources/<타깃>/<컴포넌트>/` 디렉터리를 만들고 타입 하나당 파일 하나로 나눠요.
3. UIKit 코드는 `#if canImport(UIKit) && !os(watchOS)`로 감싸요.
4. 코어 모듈의 타입이 필요하면 `Package.swift`의 해당 타깃 `dependencies`에 추가해요. 지금은 두 UI 타깃 모두 의존성이 없어요.
5. 대응하는 테스트 타깃에 테스트를 추가해요.

새 타깃 자체를 더 만들 일이 생기면 `Package.swift`에 product·target·testTarget 세 곳을 함께 추가하고, [패키지 구조](architecture.md)의 타깃 표와 `README.md`의 모듈 목록도 갱신해요.

## 관련 문서

- [패키지 구조](architecture.md): 타깃 구성과 의존성 방향
- [API 설계 규칙](api-design.md): 공개 API 이름과 접근 제어
- [Swift 스타일](../development/swiftstyle.md): MARK 섹션과 포맷팅
