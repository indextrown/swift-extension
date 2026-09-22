# swift-extension 작업 안내

`swift-extension`은 앱이 아니라 **Swift Package 라이브러리**예요. 저수준 자료구조와 고성능 확장, 그리고 앞으로 추가할 UIKit·SwiftUI 재사용 뷰를 제공해요. 앱의 화면 흐름이나 의존성 주입 구조를 이 저장소에 만들지 않아요.

## 작업 전에 확인할 문서

| 확인할 내용 | 문서 | 확인 기준 |
| --- | --- | --- |
| 패키지 소개와 사용 방법 | `README.md` | 모듈 목록과 요구 버전을 실제 `Package.swift`와 비교해요. |
| 타깃 구성과 모듈 경계 | [패키지 구조](docs/architecture/architecture.md) | 문서의 타깃 표를 `Package.swift`와 비교해요. 다르면 실제 설정을 따라요. |
| 공개 API 설계 | [API 설계 규칙](docs/architecture/api-design.md) | `public`을 추가하거나 기존 시그니처를 바꾸기 전에 확인해요. |
| 성능 변경과 측정 | [성능 기준](docs/architecture/performance.md) | 성능을 주장하기 전에 Release 구성에서 측정해요. |
| UIKit·SwiftUI 타깃 | [UI 모듈 가이드](docs/architecture/ui-modules.md) | 컴포넌트를 추가하거나 고칠 때 이 문서의 규칙을 따라요. |
| 바텀시트 컴포넌트 | [바텀시트](docs/components/bottom-sheet.md) | `BottomSheetController`를 쓰거나 고치기 전에 단계·offset 개념과 검증 방법을 확인해요. |
| Swift 코드 작성 규칙 | [Swift 스타일](docs/development/swiftstyle.md) | 주변 코드와 다르면 주변 코드를 먼저 확인해요. |
| 테스트 타깃과 실행 명령 | [테스트](docs/development/testing.md) | 문서에 적힌 명령으로 실행하고 결과를 기록해요. |
| 브랜치·커밋·PR 규칙 | [Git 작업 흐름](docs/development/gitflow.md) | 저장소에서 확인한 규칙을 따라요. |
| 한국어 문서·PR 윤문 | [한국어 윤문 원칙](docs/development/korean-editing.md) | 원문의 의미·사실·말투·보호 구간을 유지하며 기계적인 표현만 수정해요. |
| 커밋·PR의 AI 작성 표기 | [AI 작성 표기 규칙](docs/development/ai-attribution.md) | AI 공동 작성자 트레일러와 생성 문구·세션 링크를 넣지 않아요. |

## 이 저장소에서 지키는 것

| 상황 | 판단 기준 |
| --- | --- |
| 새 자료구조나 API를 만들어요. | 표준 라이브러리나 swift-collections로 충분한지 먼저 확인해요. 충분하면 만들지 않아요. |
| 공개 범위를 정해요. | 기본은 `internal`이에요. 외부에서 필요한 이유를 설명할 수 있을 때만 `public`으로 올려요. |
| 공개 API를 추가하거나 바꿔요. | 문서 주석에 동작과 시간·공간 복잡도를 적고, 호환성 영향을 PR에 적어요. |
| 성능이 좋아졌다고 적어요. | Release 구성에서 측정한 결과와 환경을 함께 적어요. 측정하지 않았으면 그렇게 적지 않아요. |
| 코어 모듈(`Algorithm`, `SwiftExtension`, `UIComponentsCore`)을 수정해요. | UIKit·SwiftUI·AppKit을 import하지 않아요. 플랫폼 중립을 유지해요. |
| UIKit과 SwiftUI 타깃이 같은 코드를 쓰게 돼요. | `UIComponentsCore`로 내려요. 두 UI 타깃은 서로 의존하지 않아요. |
| 외부 의존성을 추가하고 싶어요. | 바로 추가하지 않고 필요한 이유와 대안을 먼저 정리해요. |
| 실험 중인 구현을 추가해요. | `Sources/Labs/`에서 시작하고, 정식 모듈로 옮기는 기준은 [패키지 구조](docs/architecture/architecture.md)를 따라요. |
| 문서와 코드가 달라요. | 실제 코드와 `Package.swift`를 기준으로 작업하고 관련 문서도 같은 작업에서 고쳐요. |
| 확인하지 못한 내용이 있어요. | 단정하지 말고 `확인 필요`라고 표시해요. 확인할 파일이나 명령도 함께 적어요. |
| 커밋 제목을 적어요. | `유형: 변경 내용` 형식의 개조식으로 적어요. 예: `feat: RingBuffer 추가` |
| PR 제목과 본문을 적어요. | `[유형] 변경 내용` 형식에 해요체로 적어요. 예: `[feature] RingBuffer를 추가했어요` |
| 커밋 메시지나 PR 본문을 작성해요. | `Co-Authored-By: Claude` 같은 AI 공동 작성자 트레일러, `Generated with Claude Code` 같은 생성 문구와 AI 세션 링크를 넣지 않아요. 실제 사람의 기여 기록은 유지해요. |

## 작업 완료 전 확인

- [ ] `swift test`를 실행하고 결과를 기록했어요.
- [ ] 추가·변경한 공개 API에 문서 주석과 복잡도를 적었어요.
- [ ] 빈 상태와 경계값을 포함한 테스트를 추가했어요.
- [ ] 성능이나 Unsafe 코드를 바꿨다면 측정 결과나 Sanitizer 결과를 기록했어요.
- [ ] UIKit·SwiftUI 코드를 바꿨다면 iOS 시뮬레이터에서 `xcodebuild test`를 돌렸어요. macOS `swift test`는 그 코드를 컴파일하지 않아요.
- [ ] 타깃 구성이나 실행 방법을 바꿨다면 관련 문서와 `README.md`도 갱신했어요.
- [ ] 확인하지 못한 내용에는 `확인 필요`와 확인 대상을 남겼어요.
- [ ] 커밋 메시지와 PR 본문에 AI 공동 작성자·생성 문구·세션 링크가 없는지 확인했어요.
