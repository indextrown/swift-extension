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
    ├── BottomSheetHostViewController    지도 역할 호스트. 시트를 자식으로 붙이고 상태를 표시
    └── PlaceListViewController          시트 안 콘텐츠 (UITableView 40행)
```

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

코드 서명을 끄고 있어서 시뮬레이터에서만 바로 실행돼요. 실제 기기에서 돌리려면 Signing 설정에 팀을 넣어요.

## 바텀시트 데모에서 볼 것

- `tip` 단계에서 시트 본체가 탭바 뒤로 이어지고 탭바는 그대로 눌려요.
- 손잡이를 위로 플릭하면 `full`, 리스트를 밀면 콘텐츠가 스크롤되고, 맨 위에서 계속 끌면 시트가 이어서 내려와요.
- 오른쪽 위 `불투명 탭바` 토글로 벽(불투명)과 유리창(기본 Liquid Glass)을 바꿔 가며 비교할 수 있어요.
- 상단 두 줄이 현재 단계, 도착 offset, 현재 offset, 가용 높이를 보여 줘요.
