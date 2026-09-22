# 바텀시트

> 탭바 뒤에서 올라오는 바텀시트를 쓰고 고치는 기준이에요. UIKit 판 `BottomSheetController`와 SwiftUI 판 `bottomSheet(detent:)`가 있고, 둘은 `UIComponentsCore`의 같은 단계·위치 계산을 써요. 문서와 코드가 다르면 코드를 따르고 이 문서도 같은 작업에서 고쳐요.

## 목차

- [무엇이 다른가](#무엇이-다른가)
- [구성 요소](#구성-요소)
- [기본 사용법](#기본-사용법)
- [단계와 offset](#단계와-offset)
- [탭바 뒤에서 올라오는 원리](#탭바-뒤에서-올라오는-원리)
- [스크롤뷰 따라가기](#스크롤뷰-따라가기)
- [모양과 움직임 바꾸기](#모양과-움직임-바꾸기)
- [콘텐츠 높이 모드](#콘텐츠-높이-모드)
- [대리자](#대리자)
- [접근성](#접근성)
- [SwiftUI에서 쓰기](#swiftui에서-쓰기)
- [검증 방법](#검증-방법)
- [알려진 제한과 후속 과제](#알려진-제한과-후속-과제)
- [참고한 구현](#참고한-구현)

## 무엇이 다른가

UIKit의 `UISheetPresentationController`는 `present`로 띄워요. 창 전체를 덮는 프레젠테이션이라 **탭바까지 가려요.** 시트를 올려 둔 채로 다른 탭을 누르거나, 지도 위에 정보를 얹은 상태로 화면을 계속 조작해야 하는 곳에는 맞지 않아요.

`BottomSheetController`는 `present` 대신 **부모 화면의 자식 뷰컨트롤러로 붙어요.** 부모가 탭바 컨트롤러의 자식이면 시트도 탭바 뒤에 놓이고, 탭바는 그대로 눌려요.

| | `UISheetPresentationController` | `BottomSheetController` |
| --- | --- | --- |
| 붙는 방식 | `present` (모달) | `add(to:)` (자식 뷰컨트롤러) |
| 탭바 | 가려요 | 뒤에 놓여요. 탭바는 그대로 눌려요 |
| 단계 | `.medium()`, `.large()`, iOS 16부터 `.custom` | 값으로 정한 단계 목록. 이름을 새로 만들 수 있어요 |
| 형제 View 배치 | 시트 위치에 다른 View를 붙일 수 없어요 | `sheet.view.topAnchor`에 지도 버튼 같은 형제를 붙일 수 있어요 |
| 스크롤 연동 | 자동 | `track(scrollView:)`로 지정 |
| 최소 버전 | iOS 15 | iOS 15 |

## 구성 요소

세 타깃에 나뉘어 있어요. 계산은 한 곳에 두고, 그리는 쪽만 프레임워크별로 따로 만들었어요.

| 타깃 | 파일 | 역할 |
| --- | --- | --- |
| `UIComponentsCore` | `BottomSheetAnchor.swift` | 단계의 높이를 재는 방법(`height`, `fraction`, `topInset`, `hidden`)과 offset 계산 |
| `UIComponentsCore` | `BottomSheetDetent.swift` | 이름(`Identifier`)과 anchor를 묶은 단계 값. `tip`, `half`, `full`, `hidden` 프리셋 |
| `UIComponentsCore` | `BottomSheetLayout.swift` | 단계 목록. 가장 가까운 단계, 위·아래 단계, 저항, 속도 투영, 뒷판 진행률 |
| `UIComponentsCore` | `BottomSheetBehavior.swift` | 감속률, 스프링 감쇠, 애니메이션 길이, 저항 한계 |
| `UIKitExtension` | `BottomSheetAppearance.swift` | 배경색, 모서리, 손잡이, 그림자, 뒷판 (UIKit 타입) |
| `UIKitExtension` | `BottomSheetSurfaceView.swift` | 시트 겉면과 손잡이 View. 그림자 경로, VoiceOver 조작 |
| `UIKitExtension` | `BottomSheetControllerDelegate.swift` | 끌기 시작·이동·도착 단계 결정·단계 변경 콜백 |
| `UIKitExtension` | `BottomSheetController.swift` | 자식으로 붙이기, 제스처, 스크롤 따라가기, 애니메이션 |
| `SwiftUIExtension` | `BottomSheetStyle.swift` | 배경, 모서리, 손잡이, 그림자, 뒷판 (SwiftUI 타입) |
| `SwiftUIExtension` | `BottomSheetScrollView.swift` | 스크롤 위치를 시트에 알리는 `ScrollView` 포장 |
| `SwiftUIExtension` | `BottomSheetModifier.swift` | `View.bottomSheet(detent:)` 수정자와 시트를 그리는 overlay |

`UIComponentsCore`는 `import Foundation`만 써서 macOS `swift test`와 CI에서 검증돼요. 위치 계산의 회귀는 PR 단계에서 잡혀요. 두 UI 타깃은 이 모듈을 `@_exported import`로 다시 내보내므로 `import UIKitExtension` 또는 `import SwiftUIExtension` 하나로 `BottomSheetLayout` 같은 타입을 써요.

UIKit 파일은 `#if canImport(UIKit) && !os(watchOS) && !os(tvOS)`, SwiftUI 파일은 `#if !os(tvOS)`와 `@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)`로 감쌌어요.

## 기본 사용법

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

        self.sheet.delegate = self
        self.sheet.add(to: self)
        self.sheet.track(scrollView: self.listViewController.tableView)

        // 시트 위에 떠서 함께 올라가는 버튼
        self.locateButton.bottomAnchor.constraint(
            equalTo: self.sheet.view.topAnchor,
            constant: -12
        ).isActive = true
    }
}
```

- `add(to:)`는 부모의 `view`에 시트를 넣고 제약을 걸어요. 다른 서브뷰를 모두 추가한 뒤에 호출하면 시트가 맨 위에 놓여요.
- `move(to:animated:)`로 단계를 옮겨요. 화면에 붙기 전에 호출하면 기억해 두고 처음 나타날 때 그 단계에서 시작해요.
- `remove()`로 떼어 내요.
- `allowedDetents`로 지금 멈출 수 있는 단계를 좁혀요. 내용이 많아 낮은 단계에 넣을 수 없을 때 써요. 현재 단계가 빠지면 가장 가까운 허용 단계로 옮겨 가요.

## 단계와 offset

시트의 위치는 **offset** 하나로 정해요. 부모 안전 영역의 위쪽 끝에서 시트 위쪽 끝까지의 거리이고, 값이 클수록 시트가 아래에 있어요. 시트 높이를 직접 다루지 않는 이유는, 위치의 근거를 한 곳에 두어야 손잡이·그림자·콘텐츠 배치가 서로 어긋나지 않기 때문이에요.

단계(`BottomSheetDetent`)는 이름과 높이 기준(`BottomSheetAnchor`)의 쌍이에요.

| Anchor | 뜻 | 쓰는 곳 |
| --- | --- | --- |
| `.height(96)` | 바닥에서 96pt | 손잡이와 요약 한 줄. 기기가 달라도 같은 크기여야 해요 |
| `.fraction(0.5)` | 쓸 수 있는 높이의 절반 | 화면 비중이 기준인 단계 |
| `.topInset(16)` | 위에서 16pt 남김 | 거의 다 채우는 단계 |
| `.hidden` | 화면 밖 | 시트를 완전히 내릴 때. 되돌릴 조작이 화면에 있어야 해요 |

```swift
let layout = BottomSheetLayout(detents: [
    .tip(height: 120),
    BottomSheetDetent("connect", anchor: .fraction(0.68)),
    .full(topInset: 16)
])
```

- 같은 레이아웃 안에서 이름은 겹치면 안 돼요. 겹치면 `precondition`으로 중단돼요.
- 순서는 상관없어요. 어느 단계가 더 높은지는 실제 offset으로 매번 계산해요. 화면이 좁아 순서가 뒤바뀌어도 동작해요.
- anchor의 결과는 `0...availableHeight`로 잘라 내요. 요청한 높이가 화면보다 커도 안전 영역 위로 나가지 않아요.

## 탭바 뒤에서 올라오는 원리

`add(to:)`가 거는 제약이 핵심이에요.

```text
sheet.view.top    == host.safeAreaLayoutGuide.top + offset
sheet.view.bottom == host.bottom            ← 안전 영역이 아니라 View 바닥
```

- 위쪽은 **안전 영역** 기준이라 내비게이션 바 아래에서 시작해요.
- 아래쪽은 **부모 View 바닥**까지 이어져요. 탭바와 홈 인디케이터 뒤까지 배경이 깔려 아래가 잘린 것처럼 보이지 않아요.
- `availableHeight`는 부모 안전 영역의 높이라서 탭바 높이가 이미 빠져 있어요. `tip`의 96pt는 탭바 **위에서** 보이는 높이예요.
- 시트 View의 `safeAreaInsets.bottom`에 탭바 높이가 그대로 전달돼요. 콘텐츠 화면이 `safeAreaLayoutGuide`를 쓰면 탭바에 가리는 부분이 저절로 빠져요.
- `hidden` 단계는 안전 영역 바닥이 아니라 **창 바닥**까지 내려요. 안전 영역 끝에 세우면 탭바가 없는 화면에서 손잡이가 홈 인디케이터 옆에 남고, 부모 View 바닥에 세우면 불투명 탭바가 부모 View를 탭바 위까지로 줄인 경우 iOS 26 탭바의 반투명한 위 가장자리로 시트가 비쳐 보여요. 데모에서 실제로 그렇게 보여 창 바닥으로 바꿨어요.

## 스크롤뷰 따라가기

`track(scrollView:)`로 넘긴 스크롤뷰와 시트의 팬 제스처를 **동시에 인식**시키고, 손가락 하나가 둘 중 무엇을 움직일지 매 프레임 정해요.

| 상황 | 움직이는 것 |
| --- | --- |
| 시트가 가장 높은 단계 아래에 있어요 | 시트. 스크롤은 맨 위에 붙잡아 둬요 |
| 시트가 가장 높은 단계에 있고, 스크롤이 맨 위가 아니에요 | 스크롤 |
| 시트가 가장 높은 단계에 있고, 스크롤이 맨 위에서 아래로 끌려요 | 시트 |
| 시트를 가장 높은 단계 너머로 밀고, 스크롤할 내용이 남았어요 | 스크롤로 넘겨요 |

- 스크롤을 붙잡을 때 `isScrollEnabled`를 끄지 않아요. 끄면 진행 중인 터치가 취소돼 손가락이 끊겨요. 대신 `contentOffset`을 KVO로 지켜보며 매번 맨 위로 되돌려요.
- 붙잡는 동안 세로 스크롤 인디케이터를 숨기고, 손을 떼면 원래 값으로 돌려요.
- 가로로 끄는 동작은 시트가 받지 않아요. 콘텐츠 안의 가로 스크롤이나 스와이프에 맡겨요.
- 세로 스크롤뷰 하나만 따라가요. 콘텐츠 안에 스크롤뷰가 여러 개면 대표 하나를 넘겨요.

## 모양과 움직임 바꾸기

색·간격을 하드코딩하지 않는다는 [UI 모듈 가이드](../architecture/ui-modules.md)의 규칙대로, 모양은 `BottomSheetAppearance`, 손맛은 `BottomSheetBehavior`로 주입해요.

```swift
var appearance = BottomSheetAppearance()
appearance.cornerRadius = 24
appearance.backdrop = BottomSheetBackdrop(
    maximumAlpha: 0.3,
    largestUndimmedDetent: .half   // half 이하에서는 뒷판 없음
)

let behavior = BottomSheetBehavior(
    springDampingRatio: 0.9,
    overDragLimit: 48
)

let sheet = BottomSheetController(
    contentViewController: content,
    appearance: appearance,
    behavior: behavior
)
```

| 값 | 기본 | 뜻 |
| --- | --- | --- |
| `decelerationRate` | 0.99 | 손을 뗀 속도가 얼마나 멀리 미치는지. `UIScrollView`의 0.998은 시트에서는 두 단계를 건너뛰어 낮췄어요 |
| `springDampingRatio` | 0.85 | 1에 가까울수록 덜 튕겨요 |
| `animationDuration` | 0.4s | 단계 사이 이동 시간. 대리자에서 다른 값을 함께 움직일 때 같은 길이를 써요 |
| `overDragLimit` | 64 | 한계를 넘어 끌 때 따라오는 최대 거리. `tanh`로 점점 덜 따라와요 |
| `animatesInitialAppearance` | true | 처음 붙을 때 아래에서 올라오는 애니메이션 |

뒷판(`backdrop`)은 기본으로 없어요. 지도처럼 뒤 화면을 계속 조작해야 하는 곳이 기본 사용처라서요. 켜면 시트가 올라갈수록 진해지고, 탭하면 정한 단계로 내려가요.

## 콘텐츠 높이 모드

UIKit 판은 시트가 움직일 때 콘텐츠 높이를 다루는 방식을 `contentMode`로 골라요. 기본은 `.static`이에요.

| 모드 | 동작 | 언제 |
| --- | --- | --- |
| `.static` (기본) | 시트 높이를 **가장 높은 단계 기준으로 고정**하고 위치만 옮겨요. 낮은 단계에서는 콘텐츠 아랫부분이 화면 밖에 있어요 | 리스트처럼 위에서부터 보이는 콘텐츠. 끌 때 부드러워요 |
| `.fitToBounds` | 시트 높이를 단계에 맞춰 늘리고 줄여요 | 내용을 세로 가운데에 맞추는 등 콘텐츠가 자기 크기를 다 알아야 할 때 |

처음엔 `fitToBounds`만 있었는데 데모에서 **손으로 끌면 딱딱하고 버튼으로 옮기면 부드러운** 차이가 났어요. 버튼 이동은 Core Animation이 레이어를 보간해 배치가 한 번만 돌지만, 끌 때는 매 프레임 제약을 바꿔 Auto Layout이 다시 돌고, 시트 높이가 매 프레임 바뀌니 `UITableView`가 매 프레임 셀을 다시 배치했어요. `static`은 높이를 고정해 이 재배치를 없애요. FloatingPanel의 기본값도 같은 이유로 `static`이에요.

`static`의 시트 높이는 `가장 높은 단계에서 보이는 높이 + 안전 영역 아래쪽 여백 + overDragLimit`이에요. 마지막 항은 한계 너머로 끌어 올릴 때 바닥이 뜨지 않게 하는 여유예요. 그만큼 시트 바닥이 화면 아래로 내려가 있지만, 콘텐츠가 `safeAreaLayoutGuide`를 쓰면 UIKit이 화면 밖 부분을 안전 영역 밖으로 계산해 주어 마지막 줄이 탭바 위에 보여요.

SwiftUI 판은 `fitToBounds`만 있어요. `LazyVStack` 재배치가 가벼워서 같은 문제가 나지 않았어요.

## 대리자

`BottomSheetControllerDelegate`의 네 메서드는 모두 기본 구현이 비어 있어요. 필요한 것만 구현해요.

| 메서드 | 호출 시점 | 쓰는 곳 |
| --- | --- | --- |
| `bottomSheetWillBeginDragging` | 손가락이 시트를 끌기 시작할 때 | 진행 중인 다른 애니메이션 정리 |
| `bottomSheet(_:didMoveTo:)` | 끄는 동안 위치가 바뀔 때마다 | 지도 카메라 여백처럼 시트 높이를 따라가는 값 |
| `bottomSheet(_:willEndDraggingWithVelocity:targetDetent:)` | 손을 뗀 직후, 도착 단계가 계산된 뒤 | `targetDetent`를 바꿔 다른 단계로 보내기 |
| `bottomSheet(_:didChangeDetent:)` | 도착 단계가 정해졐을 때 | 단계별 UI 갱신. 애니메이션 시작 시점이라 같은 길이로 함께 움직일 수 있어요 |
| `bottomSheet(_:didChangeCoveredHeight:animated:)` | 끄는 동안 매 프레임(`animated: false`), 도착값이 정해질 때 한 번(`animated: true`), 처음 자리 잡을 때 한 번 | 지도 여백처럼 **시트가 가린 높이 하나에 묶이는 값**. 위 두 메서드를 합친 편의 콜백이에요 |

`didMoveTo`는 손으로 끄는 동안만 와요. 손을 뗀 뒤의 애니메이션 중에는 오지 않아요. 지도 여백처럼 시트가 가린 높이 하나에 묶이는 값은 `didChangeCoveredHeight`를 쓰면 끄는 동안과 도착 시점을 한 메서드로 받아요.

```swift
func bottomSheet(_ controller: BottomSheetController, didChangeCoveredHeight height: CGFloat, animated: Bool) {
    // 시트가 더 가린 만큼의 절반을 밀면, 보이는 영역 가운데에 있던 지점이 계속 가운데에 남아요.
    let delta = height - self.lastCoveredHeight
    self.lastCoveredHeight = height

    let shifted = CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY + delta / 2)
    mapView.setCenter(mapView.convert(shifted, toCoordinateFrom: mapView), animated: animated)
}
```

`didChangeDetent`에서 직접 하려면 도착 위치를 `controller.offset(for: detent)`로 구해요. 이 시점의 `currentOffset`은 아직 출발 위치예요.

## 접근성

- 손잡이 영역이 VoiceOver 요소예요. 이름은 `appearance.handleAccessibilityLabel`, 값은 현재 단계 이름이에요.
- `adjustable` 특성이라 위로 쓸어 올리면 한 단계 올라가고, 내리면 한 단계 내려가요. `allowedDetents`를 따라요.
- 동작 줄이기(`UIAccessibility.isReduceMotionEnabled`)가 켜져 있으면 스프링 대신 완만한 곡선으로 옮기고, 처음 올라오는 애니메이션을 생략해요.

## SwiftUI에서 쓰기

`SwiftUIExtension`의 `bottomSheet(detent:)` 수정자를 부모 View에 붙여요. `TabView`의 탭 콘텐츠에 붙이면 시트가 탭바 뒤에 놓여요.

```swift
import SwiftUIExtension

struct MapScreen: View {

    @State private var detent: BottomSheetDetent.Identifier = .tip

    var body: some View {
        MapView()
            .bottomSheet(detent: self.$detent, layout: .standard) {
                BottomSheetScrollView {
                    LazyVStack { ForEach(self.places) { PlaceRow($0) } }
                }
            }
    }
}
```

- `detent`는 양방향 바인딩이에요. 값을 바꾸면 시트가 움직이고, 사용자가 끌어 옮기면 값이 바뀌어요. UIKit의 `move(to:)`와 `currentDetent`를 하나로 합친 거예요. 손을 뗀 뒤 바뀌는 `detent`는 시트 애니메이션 블록 **안에서** 바뀌므로 `detent`에 묶인 바깥 View도 시트와 같이 움직여요.
- 스크롤이 필요한 콘텐츠는 **`ScrollView` 대신 `BottomSheetScrollView`를 써요.** SwiftUI `ScrollView`는 스크롤 위치를 바깥에 알려 주지 않아서, 시트가 "맨 위에서 아래로 끌었다"를 알 방법이 없어요. 이 포장이 위치를 `PreferenceKey`로 올려 보내요.
- 단계·레이아웃·움직임은 UIKit 판과 **같은 타입**(`BottomSheetLayout`, `BottomSheetBehavior`)을 써요. 모양만 `BottomSheetStyle`로 따로 있어요. SwiftUI 타입(`Color`, `ShapeStyle`)을 쓰기 때문이에요.
- `onOffsetChange`는 끄는 동안 매 프레임 오고, 손을 뗀 뒤나 `detent`를 바꿔 옮길 때는 **도착 위치를 애니메이션 블록 안에서 한 번** 더 와요. 받은 값을 `@State`에 넣고 버튼 위치나 지도 여백을 거기 묶으면 시트와 나란히 움직여요. UIKit의 `didMoveTo`(끄는 동안) + `didChangeDetent`(도착)를 하나로 합친 셈이에요.
- 손잡이는 VoiceOver `adjustable` 요소이고, 동작 줄이기가 켜져 있으면 스프링 대신 완만한 곡선을 써요.

UIKit 판과 다른 점이에요.

| | UIKit `BottomSheetController` | SwiftUI `bottomSheet(detent:)` |
| --- | --- | --- |
| 붙는 방식 | `add(to:)`로 자식 뷰컨트롤러 | 부모 View의 `.overlay` |
| 최소 버전 | iOS 15 | iOS 17, macOS 14, watchOS 10 |
| 스크롤 잠그기 | `contentOffset`을 KVO로 되돌려요 | `scrollDisabled`로 잠가요. 잠기는 순간 진행 중인 스크롤이 끊겨요 |
| 스크롤 → 시트 (맨 위에서 아래로) | 어떤 `UIScrollView`든 `track(scrollView:)` | `BottomSheetScrollView`를 쓴 콘텐츠만 |
| 시트 → 스크롤 (가장 높은 단계 너머로 밀 때) | 스크롤로 넘겨요 | 넘기지 않고 저항만 줘요. 손을 떼면 가장 높은 단계에 멈추고 그 뒤에 스크롤이 돼요 |
| 위치 읽기 | `currentOffset`, `availableHeight`, `offset(for:)` | `onOffsetChange`가 끄는 동안과 도착 시점의 offset을 줘요. 높이가 필요하면 `GeometryReader`로 부모 안전 영역 높이를 재요 |

## 검증 방법

| 무엇을 | 어떻게 | 어디서 |
| --- | --- | --- |
| 위치 계산, 저항, 속도 투영 | `swift test --filter UIKitExtensionTests` | macOS, CI |
| 자식 붙이기, 단계 이동, 허용 목록, 대리자, hidden 위치 | 아래 `xcodebuild test` | iOS 시뮬레이터 |
| 제스처 손맛, 스크롤 핸드오프, 탭바 뒤 배치 | `Demo/SwiftExtensionDemo` 앱을 눌러 봐요. UIKit 판은 `UIKitExtension` 섹션, SwiftUI 판은 `SwiftUIExtension` 섹션 | iOS 시뮬레이터 |

```bash
xcodebuild test \
  -scheme SwiftExtension-Package \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  -only-testing:UIKitExtensionTests
```

`-destination`의 기기 이름은 `xcrun simctl list devices available`에 있는 것으로 바꿔요. macOS `swift test`는 UIKit 코드를 컴파일하지 않으니, 컨트롤러를 바꿨으면 반드시 시뮬레이터 테스트를 돌려요.

눌러 보는 검증은 데모 앱에서 해요. Xcode로 `Demo/SwiftExtensionDemo/SwiftExtensionDemo.xcodeproj`를 열어 실행하고, 목록의 `탭바 뒤 바텀시트`로 들어가요. 오른쪽 위 토글로 불투명 탭바와 기본 Liquid Glass 탭바를 바꿔 볼 수 있어요. 실행 방법은 [데모 README](../../Demo/SwiftExtensionDemo/README.md)에 있어요.

## 알려진 제한과 후속 과제

| 항목 | 지금 | 후속 |
| --- | --- | --- |
| 애니메이션 중 위치 콜백 | 손으로 끄는 동안만 `didMoveTo` | `CADisplayLink`로 애니메이션 중에도 위치를 알리기 |
| 키보드 | 대응하지 않아요 | 키보드가 올라오면 시트를 함께 올리는 옵션 |
| 가로 모드·iPad | 세로 바텀시트 하나 | 넓은 화면에서 옆으로 붙는 패널 레이아웃 |
| 콘텐츠 크기 기반 단계 | 없어요 | `intrinsicContentSize`로 높이를 재는 anchor |
| SwiftUI 일반 `ScrollView` | 가장 높은 단계 아래에서만 잠겨요. 맨 위에서 시트로 넘어오지 않아요 | `BottomSheetScrollView`를 쓰거나, iOS 18 `onScrollGeometryChange`로 일반 `ScrollView`도 지원 |
| SwiftUI 시트 → 스크롤 핸드오프 | 가장 높은 단계 너머로 밀어도 스크롤로 넘기지 않아요 | SwiftUI에서 진행 중인 제스처를 `ScrollView`에 넘길 방법이 생기면 |
| CI | macOS 러너라 UIKit·SwiftUI 코드가 컴파일되지 않아요 (SwiftUI 파일은 macOS 14 availability로 컴파일은 돼요) | 시뮬레이터 빌드·테스트 잡 추가 |

## 참고한 구현

| 구현 | 붙는 방식 | 가져온 것 | 다르게 한 것 |
| --- | --- | --- | --- |
| RTK SDK 샘플의 `CustomSheetView` | 자식 View | offset 하나로 위치를 정하는 설계, 안전 영역 top 기준 + View bottom 제약, `tanh` 저항, 감속 투영, 표시 계층에서 멈춘 애니메이션 위치 이어받기 | 단계를 열거형에서 값·이름으로 바꿈, 스크롤 따라가기 추가, 모양·움직임 주입, 대리자 확장, 기하 계산을 UIKit 없이 테스트, hidden을 View 바닥까지, 그림자 경로 지정 |
| [FloatingPanel](https://github.com/scenee/FloatingPanel) | 자식 뷰컨트롤러 또는 모달 | `addPanel(toParent:)` 구조, `track(scrollView:)`라는 이름, 뒷판, `willEndDragging`에서 도착 단계 바꾸기 | 상·하·좌·우 위치와 SwiftUI 연동은 빼고 세로 바텀시트에 집중 |
| [PanModal](https://github.com/slackhq/PanModal) | 모달 (`UIPresentationController`) | KVO로 `contentOffset`을 되돌려 스크롤을 붙잡는 방식 | 모달이라 탭바를 가려요. 2025년 11월에 보관(archived)돼 의존하지 않아요 |
| [Pulley](https://github.com/52inc/Pulley) | 컨테이너 뷰컨트롤러 | 단계 이름(`collapsed`/`partiallyRevealed`/`open`) 감각 | 화면 구조를 컨테이너 안에 다시 짜야 해서 기존 화면에 얹기 어려워요. 바운스용으로 시트를 20pt 늘리는 우회는 쓰지 않았어요 |
| `UISheetPresentationController` | 모달 | `largestUndimmedDetentIdentifier` 개념 | 탭바를 가려요 |
