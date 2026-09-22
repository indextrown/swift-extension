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
    ├── PlaceListViewController          시트 안 콘텐츠 (UITableView 40행)
    └── SwiftUIBottomSheetDemoScreen     SwiftUI 버전. TabView 탭 콘텐츠에 bottomSheet(detent:) 적용
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

### 실기기에서 실행하기

코드 서명은 `Automatic`이고 팀 ID는 커밋하지 않아요. 한 번만 아래를 해 두면 Xcode에서 기기를 골라 바로 실행돼요.

```bash
cp Demo/SwiftExtensionDemo/Config/Local.xcconfig.example Demo/SwiftExtensionDemo/Config/Local.xcconfig
```

그리고 `Local.xcconfig`의 `DEVELOPMENT_TEAM`을 본인 팀 ID로 바꿔요. 이 파일은 `.gitignore`에 있어서 저장소에 올라가지 않아요. 파일이 없어도 시뮬레이터 빌드는 그대로 돼요.

`The executable is not codesigned`가 나오면 `Local.xcconfig`가 없거나 팀 ID가 비어 있는 거예요. Xcode의 Signing & Capabilities에서 팀을 고르면 프로젝트 파일에 팀 ID가 기록되니, 그 변경은 커밋하지 말고 `Local.xcconfig`를 써요.

## 바텀시트 데모에서 볼 것

- `tip` 단계에서 시트 본체가 탭바 뒤로 이어지고 탭바는 그대로 눌려요.
- 손잡이를 위로 플릭하면 `full`, 리스트를 밀면 콘텐츠가 스크롤되고, 맨 위에서 계속 끌면 시트가 이어서 내려와요.
- 오른쪽 위 `불투명 탭바` 토글로 벽(불투명)과 유리창(기본 Liquid Glass)을 바꿔 가며 비교할 수 있어요.
- 상단 두 줄이 현재 단계, 도착 offset, 현재 offset, 가용 높이를 보여 줘요.
- `SwiftUIExtension` 섹션의 같은 이름 행은 SwiftUI 버전이에요. `TabView` 탭 콘텐츠에 `bottomSheet(detent:)`를 얹었고, 콘텐츠는 `BottomSheetScrollView`라 맨 위에서 아래로 끌면 시트로 넘어와요.
