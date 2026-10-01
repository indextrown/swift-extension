# 뷰 컴포넌트

> UIKit 뷰 하나를 `ViewComponent`로 감싸서 UIKit 뷰·스택뷰·테이블/컬렉션 셀·SwiftUI에 같은 코드로 넣는 방법과 검증 기준이에요. `UIKitComponents` 타깃에 있어요. 문서와 코드가 다르면 코드를 따르고 이 문서도 같은 작업에서 고쳐요.

## 목차

- [무엇이 다른가](#무엇이-다른가)
- [구성 요소](#구성-요소)
- [컴포넌트 만들기](#컴포넌트-만들기)
- [UIKit 뷰와 스택뷰에 넣기](#uikit-뷰와-스택뷰에-넣기)
- [셀에 넣기](#셀에-넣기)
- [SwiftUI에 넣기](#swiftui에-넣기)
- [크기를 재는 방법](#크기를-재는-방법)
- [갱신과 작업 수명](#갱신과-작업-수명)
- [성능](#성능)
- [검증 방법](#검증-방법)
- [알려진 제한과 후속 과제](#알려진-제한과-후속-과제)
- [참고한 구현](#참고한-구현)

## 무엇이 다른가

UIKit 뷰를 다른 곳에 넣는 표준 API는 이미 있어요. 다만 셋 다 넣을 곳이 하나로 정해져 있어요.

| | `UIViewRepresentable` | `UIContentConfiguration` | `ViewComponent` |
| --- | --- | --- | --- |
| 넣을 수 있는 곳 | SwiftUI만 | 셀만 | UIKit 뷰, 스택뷰, 셀, SwiftUI |
| 뷰 타입 | 구체 타입 | `UIView & UIContentView`로 지워져 다운캐스트가 필요해요 | 구체 타입(`UIViewType`) |
| 크기 계산 | `sizeThatFits`를 직접 구현해야 해요 (iOS 16+) | 셀이 Auto Layout으로 재요 | 호스트가 맡아요 |
| 비동기 작업 정리 | 직접 해요 | 직접 해요 | 갱신 수명(`ComponentContext`)에 묶여 자동으로 취소돼요 |

컴포넌트를 한 번 만들어 두면 넣을 곳마다 래퍼를 새로 쓰지 않아도 돼요.

## 구성 요소

| 파일 | 공개 | 역할 |
| --- | --- | --- |
| `ViewComponent.swift` | `public` | `makeView()`와 `updateView(_:context:)` 계약, `contentConfiguration()` |
| `ComponentContext.swift` | `public` | 한 번의 갱신 수명. `invalidateLayout()`, `onCancel(_:)`, `task(priority:_:)` |
| `ComponentHostView.swift` | `public` | UIKit 뷰·스택뷰에 넣는 호스트 뷰 |
| `ComponentConfiguration.swift` | `public` | 셀의 `contentConfiguration`에 넣는 설정 |
| `ComponentView.swift` | `public` | SwiftUI에 넣는 뷰, `View`를 함께 채택한 컴포넌트의 기본 `body` |
| `ComponentHost.swift` | 내부 | 뷰를 한 번 만들고 갱신·취소·크기 계산을 맡아요. 세 호스트가 함께 써요 |
| `ComponentContentView.swift` | 내부 | 셀 안에서 설정을 표시하는 `UIContentView` |
| `ComponentRepresentable.swift` | 내부 | `ComponentView`가 쓰는 `UIViewRepresentable` |
| `SwiftUIComponentHostView.swift` | 내부 | SwiftUI 전용 호스트. iOS 15 크기 계산을 맡아요 |

UIKit 파일은 `#if canImport(UIKit) && !os(watchOS)`로 감쌌어요. macOS와 watchOS에서는 `ComponentContext`만 컴파일돼서 macOS `swift test`와 CI에서 수명 규칙을 검증해요.

이 타깃은 UIKit과 SwiftUI를 함께 import해요. UIKit 뷰를 SwiftUI로 잇는 것이 목적이라서 [UI 모듈 가이드](../architecture/ui-modules.md#의존성-규칙)에 예외로 적어 두었어요.

## 컴포넌트 만들기

평범한 UIKit 뷰를 그대로 두고, 상태를 담는 값 하나를 만들어요.

```swift
import UIKitComponents

struct NoticeComponent: ViewComponent, Equatable {
    let title: String
    let message: String

    func makeView() -> NoticeView {
        NoticeView()
    }

    func updateView(_ view: NoticeView, context: ComponentContext) {
        view.titleLabel.text = self.title
        view.messageLabel.text = self.message
    }
}
```

- `makeView()`는 호스트마다 **한 번만** 불려요. 서브뷰, 제약, 고정 스타일처럼 상태와 무관한 구성만 해요.
- `updateView(_:context:)`는 상태가 바뀔 때마다 **같은 뷰에** 불려요. 셀이 재사용되면 다른 항목을 그리던 뷰가 넘어올 수 있으니, 이전 값을 덮어쓰도록 작성해요.
- 상태만 담은 컴포넌트는 `Equatable`을 채택해요. 이전 값과 같으면 호스트가 갱신을 건너뛰어요.
- 이벤트는 클로저로 받아요. 클로저를 담으면 `Equatable`을 채택할 수 없어서 매번 갱신해요.

```swift
struct ToggleRowComponent: ViewComponent {
    let title: String
    let isOn: Bool
    let onChange: (Bool) -> Void

    func makeView() -> ToggleRowView {
        ToggleRowView()
    }

    func updateView(_ view: ToggleRowView, context: ComponentContext) {
        view.titleLabel.text = self.title
        if view.toggle.isOn != self.isOn {
            view.toggle.setOn(self.isOn, animated: false)
        }
        view.onChange = self.onChange
    }
}
```

## UIKit 뷰와 스택뷰에 넣기

`ComponentHostView`는 평범한 `UIView`예요. `addSubview(_:)`나 `addArrangedSubview(_:)`로 넣고 Auto Layout으로 배치해요.

```swift
let notice = ComponentHostView(NoticeComponent(title: "점검 안내", message: "00:00부터 접속할 수 없어요."))
stackView.addArrangedSubview(notice)

// 상태가 바뀌면 새 컴포넌트를 넣어요. 뷰는 다시 만들지 않아요.
notice.update(NoticeComponent(title: "점검이 끝났어요", message: "다시 접속할 수 있어요."))
```

| 멤버 | 하는 일 |
| --- | --- |
| `init(_:)` | 뷰를 만들고 첫 갱신을 해요 |
| `update(_:)` | 같은 뷰에 새 상태를 반영해요. `Equatable`이고 값이 같으면 건너뛰어요 |
| `component` | 마지막으로 반영한 컴포넌트 |
| `hostedView` | 컴포넌트가 만든 뷰. 애니메이션처럼 뷰를 직접 다뤄야 할 때 써요 |
| `sizeThatFits(_:)` | 프레임으로 배치할 때 주어진 너비에서 필요한 크기를 돌려줘요. 컴포넌트가 `invalidateLayout()`을 불러도 부모가 이 메서드를 다시 불러야 크기가 바뀌어요 |

콘텐츠 허깅·압축 저항 우선순위는 기본값을 그대로 둬요. 그래서 높이가 고정된 스택뷰(`distribution = .fill`)에서도 제약이 충돌하지 않아요.

## 셀에 넣기

데이터 소스와 레이아웃은 쓰던 방식 그대로 두고, 셀의 `contentConfiguration`에 넣어요. `UITableViewCell`, `UICollectionViewCell`, `UICollectionViewListCell` 모두 돼요.

```swift
let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Notice> { cell, _, notice in
    cell.contentConfiguration = NoticeComponent(title: notice.title, message: notice.message).contentConfiguration()
}
```

```swift
override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "notice", for: indexPath)
    cell.contentConfiguration = NoticeComponent(title: notices[indexPath.row].title, message: notices[indexPath.row].message).contentConfiguration()
    return cell
}
```

- 셀이 재사용되면 UIKit이 새 설정을 넣어요. 이미 만든 뷰는 그대로 두고 `updateView(_:context:)`만 다시 불러요.
- 상태가 바뀐 셀은 `reconfigureItems(_:)`로 다시 구성해요. 셀도 뷰도 새로 만들지 않고 높이만 다시 재요.
- 셀에 넣은 설정은 새로 만들거나 `component`를 바꿨을 때만 갱신해요. 셀의 강조·선택 상태만 바뀌어 같은 설정이 다시 들어오면 갱신하지 않아요.
- `UICollectionViewListCell`의 배경을 없애려면 `cell.backgroundConfiguration = .clear()`를 같이 넣어요.

## SwiftUI에 넣기

`ComponentView`로 감싸거나, 컴포넌트가 `View`를 함께 채택하면 그대로 넣어요.

```swift
extension NoticeComponent: View {}

struct SettingsView: View {
    @State private var isAlarmOn = true

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                NoticeComponent(title: "점검 안내", message: "00:00부터 접속할 수 없어요.")

                ComponentView(
                    ToggleRowComponent(title: "알림", isOn: self.isAlarmOn) { isOn in
                        self.isAlarmOn = isOn
                    }
                )
            }
        }
    }
}
```

- `.frame(height:)`로 높이를 고정하지 않아도 돼요. SwiftUI가 제안한 너비에서 뷰가 필요한 높이를 재요.
- `View`를 채택하면 `body`라는 이름의 프로퍼티는 쓸 수 없어요. `View`의 `body`와 겹쳐요.
- `View` 채택은 선택이에요. 채택하면 UIKit 쪽 자동완성에도 SwiftUI 수정자가 함께 보여요. 그게 싫으면 `ComponentView(...)`를 써요.

## 크기를 재는 방법

| 넣을 곳 | 방법 |
| --- | --- |
| UIKit Auto Layout | 컴포넌트 뷰를 호스트의 네 변에 붙여요. 높이는 뷰의 제약에서 정해져요 |
| UIKit 프레임 배치 | `sizeThatFits(_:)`가 너비를 고정하고 높이를 Auto Layout으로 재요 |
| 셀 | 셀의 Auto Layout 자동 크기 계산을 그대로 써요 |
| SwiftUI, iOS 16+ | `UIViewRepresentable.sizeThatFits(_:uiView:context:)`에서 제안 너비로 높이를 재요. `intrinsicContentSize`는 알리지 않고, 갱신할 때 크기를 무효화하지도 않아요 |
| SwiftUI, iOS 15 | 배치된 너비를 기억해 두고, 그 너비에서 잰 높이를 `intrinsicContentSize`로 알려요. 갱신하면 무효화해요 |

iOS 16 이상에서 두 경로를 함께 쓰면 SwiftUI가 같은 행을 두 번 재요. SwiftUI는 `updateUIView`를 부른 뒤 어차피 `sizeThatFits`를 다시 부르니, 갱신할 때 따로 무효화할 필요도 없어요. 그래서 iOS 16 이상에서는 `sizeThatFits` 하나만 써요. 행마다 몇 번 재는지는 테스트(`componentViewMeasuresEachRowOnceAndOnlyChangedRowsOnUpdate`)로 확인해요.

SwiftUI 쪽은 참고 구현에서 크기가 깨지던 부분이라 측정해서 비교했어요. 너비 240pt 화면에 여러 줄 `UILabel` 하나를 넣었어요. iOS 18.3.1과 iOS 27.0 시뮬레이터에서 값이 같았어요.

| 방식 | `ScrollView`, 긴 글 | `ScrollView`, 짧은 글 | `VStack`, 긴 글 |
| --- | --- | --- | --- |
| 기대값 | 240 × 260 | 240 × 37 | 240 × 260 |
| 참고 구현 (`intrinsicContentSize`, 너비 없이 측정) | 2061 × 36 (한 줄로 화면을 넘어요) | 2061 × 36 | 2061 × 2896 (세로로 늘어나요) |
| `sizeThatFits` (iOS 16+) | 240 × 260 | 240 × 37 | — |
| 너비 기반 `intrinsicContentSize` (iOS 15용) | 240 × 260 | 240 × 37 | 240 × 260 |

컴포넌트가 갱신 뒤에 크기를 바꿨다면 `context.invalidateLayout()`을 불러요. 측정해 보니 SwiftUI는 이 호출을 보고 크기를 다시 쟀어요(37 → 260). iOS 16부터는 셀도 크기를 다시 재요(`selfSizingInvalidation`).

## 갱신과 작업 수명

호스트는 `updateView(_:context:)`를 부를 때마다 새 `ComponentContext`를 만들고, 이전 context는 취소해요. 이미지 요청처럼 갱신이 끝나도 이어지는 작업은 이 수명에 묶어요.

```swift
struct ThumbnailComponent: ViewComponent, Equatable {
    let url: URL

    func makeView() -> UIImageView {
        UIImageView()
    }

    func updateView(_ view: UIImageView, context: ComponentContext) {
        view.image = nil
        context.task {
            guard
                let data = try? await URLSession.shared.data(from: self.url).0,
                let image = UIImage(data: data)
            else {
                return
            }

            view.image = image
            context.invalidateLayout()
        }
    }
}
```

| 멤버 | 하는 일 |
| --- | --- |
| `task(priority:_:)` | 이번 수명 동안만 도는 비동기 작업을 시작해요. 수명이 끝나면 취소되고, 이미 끝난 수명에서는 시작하지 않아요 |
| `onCancel(_:)` | 수명이 끝날 때 실행할 정리 동작을 등록해요. 이미 끝났으면 바로 실행해요 |
| `invalidateLayout()` | 크기를 다시 재 달라고 호스트에 요청해요. 셀과 SwiftUI는 다시 재요. `ComponentHostView`는 Auto Layout으로 붙였으면 제약을 따라 다시 잡히고, 프레임으로 배치했으면 부모가 `sizeThatFits(_:)`를 다시 불러야 해요. 끝난 수명에서는 아무 일도 안 해요 |

수명이 끝나는 시점은 호스트마다 조금 달라요.

| 호스트 | 다음 갱신 직전 | 화면에서 빠질 때 | 다시 붙을 때 | 해제될 때 |
| --- | --- | --- | --- | --- |
| `ComponentHostView` | 취소 | window에서 빠지면 취소 | 마지막 컴포넌트로 다시 갱신 | 취소 |
| 셀 | 취소 (재사용으로 새 설정이 들어올 때) | 취소하지 않아요. 셀은 화면 밖으로 스크롤돼도 window에서 빠지지 않아요 | — | 취소 |
| `ComponentView` | 취소 | `dismantleUIView`에서 취소 | SwiftUI가 새 뷰를 만들어요 | 취소 |

- `ComponentHostView`가 window에서 빠져 있는 동안 `update(_:)`를 부르면, 이미 취소된 context로 갱신해요. 뷰의 값은 바뀌지만 `task(priority:_:)`는 작업을 시작하지 않고, `onCancel(_:)`에 등록한 동작은 바로 실행돼요. 다시 붙으면 새 수명으로 한 번 더 갱신해요.
- 창에 붙은 적 없는 호스트 뷰나 셀이 해제되면 다음 갱신이 오지 않아요. 그래서 호스트가 해제될 때 마지막 갱신의 작업을 취소해요.

- SwiftUI는 뷰를 만든 직후 `updateUIView`를 불러요. 만들 때도 갱신하면 `Equatable`이 아닌 컴포넌트가 두 번 갱신되고, 첫 갱신에서 시작한 작업이 곧바로 취소돼요. 그래서 `ComponentView`는 만들 때 갱신하지 않고 첫 `updateUIView`에서 한 번만 갱신해요. 그 전에 크기를 재거나 배치하면 그때 갱신해요.
- 셀은 강조·선택 상태가 바뀔 때도 `updated(for:)`로 만든 같은 설정이 다시 들어와요. 이때는 컴포넌트가 `Equatable`이든 아니든 갱신하지 않아요. 그래서 상태가 바뀔 때마다 작업이 취소됐다가 다시 시작되지 않아요.

## 성능

감싸서 생기는 추가 비용을 같은 일을 직접 작성한 코드와 비교했어요. 더 빨라지는 구조는 아니에요. 같은 UIView와 Auto Layout 위에 한 겹을 더 씌운 것이라서, 확인할 건 추가 비용이 무시할 만한지예요.

| 항목 | 값 |
| --- | --- |
| 측정 환경 | MacBook Pro (M1), macOS 27.0, Xcode 27.0, iPhone 17 시뮬레이터 iOS 27.0 |
| 빌드 구성 | Release (`xcodebuild test -configuration Release`) |
| 반복 | 한 번 예열한 뒤 10회 실행한 중앙값. E만 7회 |
| 측정 뷰 | 아이콘 하나와 여러 줄 레이블 두 개를 스택뷰로 배치한 뷰 (데모의 `NoticeView`와 같은 구성) |

시뮬레이터는 Mac의 CPU로 돌아서 절대값은 실기기와 달라요. 같은 실행 안의 비율로 봐요.

| 항목 | 직접 작성 | `UIKitComponents` | 차이 |
| --- | --- | --- | --- |
| A. 뷰 생성 + 첫 값 설정 | 173µs | 195µs | +12%. 호스트 뷰 한 겹과 제약 4개 |
| B. 값이 바뀌는 갱신 | 2.34µs | 2.97µs (`Equatable`), 2.69µs (클로저) | +0.4~0.6µs. `Equatable`은 `==` 비교 비용이 더해져요 |
| B. 같은 값으로 갱신 | 0.46µs (레이블에 다시 설정) | 0.29µs (`Equatable`이라 건너뜀) | 갱신을 건너뛰어서 직접 작성한 것보다 빨라요 |
| C. 크기 계산 (너비 320pt) | 291µs | 285µs | 차이 없어요. 비용의 대부분이 Auto Layout 계산이에요 |
| D. SwiftUI 50행 첫 배치 | 59.2ms (직접 작성한 `UIViewRepresentable`) | 62.3ms (`ComponentView`) | +5% |
| D. SwiftUI 50행 갱신 (절반의 행 길이가 바뀜) | 13.4ms | 14.4ms | +8% |
| E. 컬렉션뷰 1000행 끝까지 스크롤 (셀 1개당) | 2.17ms (커스텀 셀 서브클래스) | 2.41ms (`contentConfiguration`) | +11%. 프레임 끊김이 아니라 CPU 시간이에요 |

- UIKit 뷰를 SwiftUI에 넣는 것 자체가 같은 모양의 순수 SwiftUI 행보다 3~4배 느렸어요(50행 첫 배치 13.4ms). 직접 작성한 `UIViewRepresentable`도 같아서, 이 타깃이 아니라 브리지 자체의 비용이에요.
- 처음 측정에서는 SwiftUI가 `ComponentView`의 행을 두 번 쟀어요(첫 배치 +18%, 갱신 +35%). [크기를 재는 방법](#크기를-재는-방법)의 iOS 16 이상 규칙으로 고친 뒤, 행당 측정 횟수가 직접 작성한 것과 같아졌어요(첫 배치 1회, 갱신 때는 바뀐 행만 1회).
- D의 시간은 저장소에 반영하기 직전의 같은 로직으로 잰 값이에요. 반영한 뒤 다시 잴 때는 같은 Mac에서 다른 빌드가 돌고 있어서, 시간 값은 버리고 행당 측정 횟수만 확인했어요. `확인 필요`: 부하가 없는 상태에서 저장소 코드로 D를 다시 재서 이 표를 갱신하기.
- 측정 코드는 저장소에 넣지 않았어요. 벤치마크 하니스를 어디에 둘지는 [성능 기준](../architecture/performance.md#측정-방법)의 `확인 필요` 항목이에요. 실기기 스크롤 끊김 측정은 아직 하지 않았어요.

## 검증 방법

| 무엇을 | 어떻게 | 어디서 |
| --- | --- | --- |
| 수명 규칙 (취소 순서, 한 번만 실행, 작업 취소) | `swift test --filter UIKitComponentsTests` | macOS, CI |
| 호스트 뷰, 셀, SwiftUI 크기와 갱신 | 아래 `xcodebuild test` | iOS 시뮬레이터 |
| 눌러 보는 확인 | `Demo/SwiftExtensionDemo` 앱의 `UIKitComponents` 섹션 | iOS 시뮬레이터 |

```bash
xcodebuild test \
  -scheme SwiftExtension-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UIKitComponentsTests
```

데모 앱의 `UIKit에서 쓰기`는 위쪽 스택뷰에 `ComponentHostView`를, 아래 목록에 `contentConfiguration()`을 써요. `SwiftUI에서 쓰기`는 같은 컴포넌트를 `ScrollView` 안에 넣었어요. 두 화면 모두 `짧게`·`길게`를 바꾸면 뷰를 새로 만들지 않고 높이를 다시 재요.

## 알려진 제한과 후속 과제

| 항목 | 지금 | 후속 |
| --- | --- | --- |
| iOS 15 실기기·시뮬레이터 | 너비 기반 `intrinsicContentSize` 방식은 iOS 18.3·27에서만 확인했어요. `확인 필요`: iOS 15 런타임에서 `UIKitComponentsTests` 실행 | iOS 15 런타임을 구하면 실행해서 결과를 이 표에 적기 |
| 가로 `ScrollView` | 제안 너비가 없으면 뷰의 자연 크기를 돌려줘요. 측정하지 않았어요 | 가로 캐러셀 데모와 테스트 추가 |
| iOS 15 셀의 비동기 크기 변경 | `selfSizingInvalidation`은 iOS 16부터라서, iOS 15에서는 셀을 다시 구성해야 할 수 있어요 | iOS 15에서 확인 |
| 프레임으로 배치한 `ComponentHostView`의 `invalidateLayout()` | 호스트 자신만 다시 배치해요. 부모는 알 수 없어서 `sizeThatFits(_:)`를 다시 부르지 않아요 | 필요해지면 크기 변경을 알리는 콜백 추가 |
| 화면 밖 셀의 작업 | 셀이 재사용되거나 해제될 때 취소돼요. 화면 밖으로 스크롤된 것만으로는 취소되지 않아요 | 어댑터 타깃에서 `didEndDisplaying`에 연결 |
| 상호작용 | 이벤트는 클로저로 받아요 | `onTap`·`pressedEffect`·`onLongPress` 같은 modifier. 모든 modifier가 조건부로 `View`를 따르게 해요 |
| 섹션 선언형 목록 | 데이터 소스는 쓰는 쪽이 만들어요 | `CollectionViewAdapter`를 이 타깃에 의존하는 별도 타깃으로 |
| `ComponentContext` 생성 | `init`이 내부라서, 쓰는 쪽 테스트에서 `updateView(_:context:)`를 직접 부를 수 없어요 | 필요해지면 테스트용 공개 생성자 |

## 참고한 구현

| 구현 | 가져온 것 | 다르게 한 것 |
| --- | --- | --- |
| [Haruhancut-V2 `CollectionViewAdapter`](https://github.com/team-GitDeulida/Haruhancut-V2/tree/main/Projects/Shared/CollectionViewAdapter)의 `Component` | 값 타입 컴포넌트가 뷰를 한 번 만들고 갱신만 반복하는 구조, 갱신마다 새 context와 취소 저장소, `Component & View` 이중 채택 | 컬렉션 뷰 개념(`Item: Identifiable`, `estimatedHeight`, `indexPath`)을 기본 계약에서 뺐어요. `createContent`·`render`를 `makeView`·`updateView`로 바꿨어요. SwiftUI 크기 계산을 고쳤고, 셀 연결과 `Equatable` 건너뛰기, window 기준 취소를 추가했어요. 세 호스트의 중복 코드는 `ComponentHost` 하나로 모았어요 |
| [Epoxy](https://github.com/airbnb/epoxy-ios)의 `SwiftUIMeasurementContainer` | 제안 너비로 높이를 재는 SwiftUI 측정 방식 | 의존성으로 쓰지 않고 방식만 참고했어요. 크기 전략 옵션은 아직 두지 않았어요 |
| `UIViewRepresentable` | `makeUIView`·`updateUIView` 이름 짝, `UIViewType` | 셀과 UIKit 뷰에서도 같은 계약을 써요 |
| `UIContentConfiguration` | 셀에 넣는 연결 방식 | 뷰 타입을 지우지 않아요 |
