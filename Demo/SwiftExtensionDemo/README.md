# SwiftExtensionDemo

패키지의 UI 컴포넌트를 실제 기기·시뮬레이터에서 눌러 보는 iOS 데모 앱이에요. 루트 패키지를 `../..` 경로의 로컬 Swift Package로 참조해요.

## 구조

```text
SwiftExtensionDemo/
├── SwiftExtensionDemoApp.swift          앱 진입점. NavigationStack 안에 데모 목록
├── DemoListView.swift                   데모 목록. DemoItem 카탈로그를 섹션별로 그려요
├── Support/
│   ├── DemoItem.swift                   목록의 행. 목적지는 SwiftUI View든 UIKit이든 상관없어요
│   └── UIKitContainer.swift             UIViewControllerContainer / UIViewContainer 범용 포장
└── BottomSheet/
    ├── BottomSheetDemoView.swift        UITabBarController를 컨테이너로 감싼 화면. 불투명·유리 탭바 토글
    ├── BottomSheetHostViewController    MKMapView 위에 시트를 붙이는 UIKit 화면. Locate 버튼은 sheet.view.topAnchor에 묶임
    ├── MapHostViewModel                 UIKit 화면의 ViewModel. 위치 권한·현재 위치를 클로저로 알림
    ├── PlaceListViewController          시트 안 콘텐츠 (UITableView 40행)
    ├── SwiftUIBottomSheetDemoScreen     SwiftUI 버전. Map 위 TabView 탭 콘텐츠에 bottomSheet(detent:) 적용
    ├── MapDemoViewModel                 SwiftUI 화면의 ViewModel. @Observable로 위치를 알림
    ├── NativeSheetDemoView              비교용. 같은 탭바 구성에서 애플 UISheetPresentationController를 띄움
    └── SwiftUINativeSheetDemoScreen     비교용. 같은 TabView 구성에서 애플 .sheet + presentationDetents를 띄움
```

목록은 `UIKitExtension`·`SwiftUIExtension` 섹션에 각각 두 행이에요. 첫 행이 이 패키지의 커스텀 시트, 둘째 행이 같은 단계(96pt·medium·large)로 맞춘 애플 기본 시트예요. 나란히 눌러 보면 차이가 바로 보여요.

| | 커스텀 시트 (`탭바 뒤 바텀시트`) | 애플 기본 시트 (`애플 기본 시트`) |
| --- | --- | --- |
| 탭바 | 시트가 탭바 **뒤**로 이어지고 탭바는 그대로 눌려요 | 모달이라 탭바 **위**를 덮어요. 탭을 바꿀 수 없어요 |
| 시트 위치 알림 | 끄는 동안 매 프레임 (`didMoveTo`, `onOffsetChange`) | 단계가 바뀐 뒤에만. 지도가 시트를 따라가지 않아요 |
| 끝까지 내리면 | `hidden` 단계에 머물러요 | 닫혀요. `시트 열기` 버튼으로 다시 띄워요 |

## 데모 추가하기

`Support/DemoItem.swift`의 카탈로그에 행을 하나 추가해요. 목적지가 SwiftUI면 View를 그대로, UIKit이면 컨테이너로 감싸요.

```swift
// SwiftUI 컴포넌트
DemoItem(id: "badge", title: "배지", subtitle: "BadgeView · SwiftUI", systemImage: "circle.badge") {
    BadgeDemoView()
}

// UIKit 뷰컨트롤러
DemoItem(id: "toast", title: "토스트", subtitle: "ToastController · UIKit", systemImage: "bubble") {
    UIViewControllerContainer { ToastDemoViewController() }
}

// UIKit View 하나
DemoItem(id: "chip", title: "칩", subtitle: "ChipView · UIKit", systemImage: "capsule") {
    UIViewContainer { ChipView() }
}
```

## 실행

Xcode에서 `SwiftExtensionDemo.xcodeproj`를 열고 iOS 시뮬레이터를 골라 실행해요. 터미널에서는:

```bash
xcodebuild \
  -project Demo/SwiftExtensionDemo/SwiftExtensionDemo.xcodeproj \
  -scheme SwiftExtensionDemo \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  build
```

### 실기기에서 실행하기

코드 서명은 `Automatic`이고 팀 ID는 커밋하지 않아요. 한 번만 아래를 해 두면 Xcode에서 기기를 골라 바로 실행돼요.

```bash
cp Demo/SwiftExtensionDemo/Config/Local.xcconfig.example Demo/SwiftExtensionDemo/Config/Local.xcconfig
```

그리고 `Local.xcconfig`의 `DEVELOPMENT_TEAM`을 본인 팀 ID로 바꿔요. 이 파일은 `.gitignore`에 있어서 저장소에 올라가지 않아요. 파일이 없어도 시뮬레이터 빌드는 그대로 돼요.

`The executable is not codesigned`가 나오면 `Local.xcconfig`가 없거나 팀 ID가 비어 있는 거예요. Xcode의 Signing & Capabilities에서 팀을 고르면 프로젝트 파일에 팀 ID가 기록되니, 그 변경은 커밋하지 말고 `Local.xcconfig`를 써요.

## 바텀시트 데모에서 볼 것

배경은 MapKit 지도예요. 화면이 열리면 위치 권한을 묻고 현재 위치로 지도를 옮겨요. `Locate` 버튼을 누르면 다시 현재 위치로 가요. 위치는 UIKit 쪽 `MapHostViewModel`(클로저), SwiftUI 쪽 `MapDemoViewModel`(`@Observable`)이 각각 독립적으로 다뤄요.

시트를 올리고 내리면 지도도 따라가요. 보이는 영역의 가운데에 있던 지점이 계속 가운데에 남도록 시트가 더 가린 높이의 절반만큼 중심을 밀어요. UIKit 판은 델리게이트 `didChangeCoveredHeight(_:animated:)`에서 `setCenter`로, SwiftUI 판은 `onOffsetChange`가 매 프레임 준 offset을 `Map`의 `safeAreaInset`에 묶어 MapKit이 알아서 해요.

시뮬레이터에서는 위치가 비어 있을 수 있어요. 아래처럼 위치를 넣어 두면 돼요.

```bash
xcrun simctl location booted set 37.5665,126.9780
```

- `tip` 단계에서 시트 본체가 탭바 뒤로 이어지고 탭바는 그대로 눌려요.
- 손잡이를 위로 플릭하면 `full`, 리스트를 밀면 콘텐츠가 스크롤되고, 맨 위에서 계속 끌면 시트가 이어서 내려와요.
- 오른쪽 위 `⋯` 메뉴의 `불투명 탭바` 토글로 벽(불투명)과 유리창(기본 Liquid Glass)을, `스크롤이 시트를 올려요` 토글로 목록 스크롤이 시트를 먼저 올릴지(Apple 지도 방식)를 바꿔 가며 비교할 수 있어요. 데모는 끈 상태로 시작해요.
- 상단 두 줄이 현재 단계, 도착 offset, 현재 offset, 가용 높이를 보여 줘요.
- `SwiftUIExtension` 섹션의 같은 이름 행은 SwiftUI 버전이에요. `TabView` 탭 콘텐츠에 `bottomSheet(detent:)`를 얹었고, 콘텐츠는 `BottomSheetScrollView`라 맨 위에서 아래로 끌면 시트로 넘어와요.
