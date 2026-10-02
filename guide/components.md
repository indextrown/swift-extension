# 컴포넌트 사용법

> 이 패키지의 UI 컴포넌트를 앱에 넣어 쓰는 방법이에요. 설치부터 가장 흔한 사용 예까지만 담았어요. 설계 이유, 동작 규칙, 검증 방법은 컴포넌트별 문서에 있어요.

## 목차

- [어떤 product를 추가하나요](#어떤-product를-추가하나요)
- [바텀시트](#바텀시트)
  - [UIKit에서 쓰기](#uikit에서-쓰기)
  - [SwiftUI에서 쓰기](#swiftui에서-쓰기)
  - [단계 바꾸기](#단계-바꾸기)
- [뷰 컴포넌트](#뷰-컴포넌트)
  - [컴포넌트 만들기](#컴포넌트-만들기)
  - [UIKit 뷰와 스택뷰에 넣기](#uikit-뷰와-스택뷰에-넣기)
  - [셀에 넣기](#셀에-넣기)
  - [SwiftUI에 넣기](#swiftui에-넣기)
  - [이미지처럼 나중에 오는 값 넣기](#이미지처럼-나중에-오는-값-넣기)
  - [알아 둘 점](#알아-둘-점)
- [데모 앱에서 보기](#데모-앱에서-보기)

## 어떤 product를 추가하나요

필요한 product만 추가해요. 추가하지 않은 product는 빌드도 링크도 되지 않아요.

| Product | 컴포넌트 | 넣는 곳 | 최소 버전 |
| --- | --- | --- | --- |
| `UIKitExtension` | `BottomSheetController` | UIKit 화면 | iOS 15 |
| `SwiftUIExtension` | `bottomSheet(detent:)`, `BottomSheetScrollView` | SwiftUI 화면 | iOS 17 |
| `UIKitComponents` | `ViewComponent`, `ComponentHostView`, `contentConfiguration()`, `ComponentView` | UIKit 뷰·스택뷰·셀, SwiftUI | iOS 15 |

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/indextrown/swift-extension.git", from: "0.1.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "UIKitExtension", package: "swift-extension"),
            .product(name: "UIKitComponents", package: "swift-extension")
        ]
    )
]
```

Xcode에서는 **File → Add Package Dependencies…** 에서 저장소 주소를 넣고 필요한 product를 골라요.

## 바텀시트

탭바 뒤에서 올라오는 바텀시트예요. `present`로 띄우는 기본 시트와 달리 부모 화면 안에 붙어서, 시트를 올려 둔 채로 탭바를 누를 수 있어요.

> 자세한 내용: [바텀시트](../docs/components/bottom-sheet.md) — 단계와 offset, 스크롤 따라가기, 모양·움직임 바꾸기, 대리자, 검증 방법

### UIKit에서 쓰기

시트에 넣을 화면을 뷰컨트롤러로 만들고, 부모 화면에 `add(to:)`로 붙여요.

```swift
import UIKitExtension

final class MapViewController: UIViewController {

    private let listViewController = PlaceListViewController()
    private lazy var sheet = BottomSheetController(
        contentViewController: self.listViewController,
        layout: .standard,       // tip · half · full
        initialDetent: .tip
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        self.sheet.add(to: self)
        self.sheet.track(scrollView: self.listViewController.tableView)
    }

    func showFullList() {
        self.sheet.move(to: .full, animated: true)
    }
}
```

| 하고 싶은 일 | 방법 |
| --- | --- |
| 시트 붙이기 | `add(to:)`. 다른 서브뷰를 모두 추가한 뒤에 부르면 시트가 맨 위에 놓여요 |
| 시트 안 목록 스크롤과 이어 붙이기 | `track(scrollView:)`. 목록 맨 위에서 아래로 끌면 시트가 내려와요 |
| 단계 옮기기 | `move(to:animated:)` |
| 멈출 수 있는 단계 좁히기 | `allowedDetents` |
| 시트가 움직일 때 알림 받기 | `delegate`(`BottomSheetControllerDelegate`) |
| 떼어 내기 | `remove()` |

### SwiftUI에서 쓰기

부모 View에 `bottomSheet(detent:)` 수정자를 붙여요. 스크롤이 필요한 콘텐츠는 `ScrollView` 대신 `BottomSheetScrollView`를 써요. 그래야 목록 맨 위에서 아래로 끌 때 시트가 내려와요.

```swift
import SwiftUIExtension

struct MapScreen: View {

    let places: [Place]

    @State private var detent: BottomSheetDetent.Identifier = .tip

    var body: some View {
        MapView()
            .bottomSheet(detent: self.$detent, layout: .standard) {
                BottomSheetScrollView {
                    LazyVStack {
                        ForEach(self.places) { place in
                            PlaceRow(place: place)
                        }
                    }
                }
            }
    }
}
```

`detent`는 양방향 바인딩이에요. 값을 바꾸면 시트가 움직이고, 사용자가 끌어 옮기면 값이 바뀌어요. 시트 위치를 프레임마다 받으려면 `onOffsetChange:`를 넘겨요.

### 단계 바꾸기

단계는 UIKit과 SwiftUI가 같은 `BottomSheetLayout`을 써요.

| 레이아웃 | 단계 |
| --- | --- |
| `.standard` | `tip`(96pt) · `half`(50%) · `full`(위 16pt 남김) |
| `.dismissible` | `hidden` · `tip` · `half` · `full` |
| 직접 만들기 | `BottomSheetLayout(detents: [.tip(height: 120), .half(fraction: 0.4), .full()])` |

콘텐츠 높이만큼만 올라오게 하려면 `.content(padding:)` 단계를 써요. 동작은 [바텀시트 문서](../docs/components/bottom-sheet.md#콘텐츠-높이만큼-올라오는-content-단계)에 있어요.

## 뷰 컴포넌트

평범한 UIKit 뷰 하나를 `ViewComponent`로 감싸면, 같은 코드로 UIKit 뷰·스택뷰·테이블/컬렉션 셀·SwiftUI에 넣을 수 있어요. 넣을 곳마다 `UIViewRepresentable`이나 셀 서브클래스를 새로 쓰지 않아도 돼요.

> 자세한 내용: [뷰 컴포넌트](../docs/components/view-component.md) — 크기를 재는 방법, 갱신과 작업 수명, 성능 측정, 검증 방법

### 컴포넌트 만들기

UIKit 뷰는 그대로 두고, 상태를 담는 값 하나를 만들어요.

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

| 메서드 | 불리는 때 | 할 일 |
| --- | --- | --- |
| `makeView()` | 넣은 곳마다 한 번 | 서브뷰, 제약, 고정 스타일처럼 상태와 무관한 구성 |
| `updateView(_:context:)` | 상태가 바뀔 때마다, 같은 뷰에 | 값 반영. 셀이 재사용되면 다른 항목을 그리던 뷰가 오니 이전 값을 덮어써요 |

상태만 담은 컴포넌트는 `Equatable`을 채택해요. 같은 값이 다시 들어오면 갱신을 건너뛰어요.

이벤트는 클로저로 받아요. 클로저를 담으면 `Equatable`을 채택할 수 없어서 매번 갱신해요.

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

### UIKit 뷰와 스택뷰에 넣기

`ComponentHostView`로 감싸요. 평범한 `UIView`라서 `addSubview(_:)`나 `addArrangedSubview(_:)`로 넣고 Auto Layout으로 배치해요. 높이는 뷰의 제약에서 정해져요.

```swift
let notice = ComponentHostView(NoticeComponent(title: "점검 안내", message: "00:00부터 접속할 수 없어요."))
stackView.addArrangedSubview(notice)

// 상태가 바뀌면 새 컴포넌트를 넣어요. 뷰는 다시 만들지 않아요.
notice.update(NoticeComponent(title: "점검이 끝났어요", message: "다시 접속할 수 있어요."))
```

### 셀에 넣기

데이터 소스와 레이아웃은 쓰던 방식 그대로 두고, 셀의 `contentConfiguration`에 넣어요. 셀 높이는 뷰의 Auto Layout 제약에서 정해져요.

```swift
// 컬렉션뷰
let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Notice> { cell, _, notice in
    cell.contentConfiguration = NoticeComponent(title: notice.title, message: notice.message).contentConfiguration()
}

// 테이블뷰
override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "notice", for: indexPath)
    let notice = self.notices[indexPath.row]
    cell.contentConfiguration = NoticeComponent(title: notice.title, message: notice.message).contentConfiguration()
    return cell
}
```

상태가 바뀐 셀은 `reconfigureItems(_:)`로 다시 구성해요. 셀도 뷰도 새로 만들지 않고 높이만 다시 재요.

### SwiftUI에 넣기

`ComponentView`로 감싸요. 컴포넌트가 `View`를 함께 채택하면 그대로 넣을 수도 있어요. 어느 쪽이든 `.frame(height:)`로 높이를 고정하지 않아도 돼요.

```swift
extension NoticeComponent: View {}

struct SettingsView: View {
    @State private var isAlarmOn = true

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // View를 채택한 컴포넌트
                NoticeComponent(title: "점검 안내", message: "00:00부터 접속할 수 없어요.")

                // 채택하지 않은 컴포넌트
                ComponentView(
                    ToggleRowComponent(title: "알림", isOn: self.isAlarmOn) { isOn in
                        self.isAlarmOn = isOn
                    }
                )
            }
            .padding(16)
        }
    }
}
```

### 이미지처럼 나중에 오는 값 넣기

갱신이 끝난 뒤에도 이어지는 작업은 `context.task`로 시작해요. 셀이 재사용되거나, 다시 갱신되거나, 화면에서 빠지면 자동으로 취소돼요. 값을 넣은 뒤 크기가 바뀌면 `context.invalidateLayout()`을 불러요.

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
                let image = UIImage(data: data),
                !Task.isCancelled
            else {
                return
            }

            view.image = image
            context.invalidateLayout()
        }
    }
}
```

`await`에서 돌아온 뒤에는 `Task.isCancelled`를 확인하고 값을 넣어요. 취소는 이미 끝난 요청을 되돌리지 못해요. 확인하지 않으면 그사이 재사용된 셀에 이전 항목의 이미지가 들어갈 수 있어요.

작업이 끝날 때 정리할 것이 있으면 `context.onCancel { ... }`에 등록해요.

### 알아 둘 점

- `View`를 채택하면 `body`라는 이름의 프로퍼티를 쓸 수 없어요. SwiftUI `View`의 `body`와 겹쳐요.
- 프레임으로 배치한 `ComponentHostView`는 `invalidateLayout()`을 불러도 부모가 `sizeThatFits(_:)`를 다시 불러야 크기가 바뀌어요. Auto Layout으로 붙였거나 셀, SwiftUI에 넣었으면 저절로 다시 재요.
- 셀은 화면 밖으로 스크롤돼도 작업이 계속 돌아요. 재사용되거나 해제될 때 취소돼요.
- 셀의 강조·선택 상태만 바뀌면 갱신하지 않아요.

## 데모 앱에서 보기

`Demo/SwiftExtensionDemo`를 실행하면 목록에서 바로 눌러 볼 수 있어요. 실행 방법은 [데모 README](../Demo/SwiftExtensionDemo/README.md)에 있어요.

| 목록 섹션 | 행 | 보여 주는 것 |
| --- | --- | --- |
| `UIKitExtension` | 탭바 뒤 바텀시트, 애플 기본 시트, 콘텐츠 높이 시트 | `BottomSheetController`와 기본 시트 비교 |
| `SwiftUIExtension` | 같은 세 행 | `bottomSheet(detent:)` |
| `UIKitComponents` | UIKit에서 쓰기, SwiftUI에서 쓰기 | 같은 컴포넌트를 스택뷰·셀과 SwiftUI에 넣은 화면 |
