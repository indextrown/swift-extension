# AlgorithmDemo

`AlgorithmDemo`는 현재 저장소의 `Algorithm` product를 로컬 Swift Package 의존성으로 등록한 macOS SwiftUI Xcode 프로젝트다.

프로젝트의 `XCLocalSwiftPackageReference`는 루트 패키지를 가리키는 `../..` 경로를 사용하고, 앱 Target은 `Algorithm` product를 Frameworks 단계에 추가한다.

`AlgorithmDemo.xcodeproj`를 Xcode에서 열거나 아래 명령으로 빌드할 수 있다.

```sh
xcodebuild \
  -project Demo/AlgorithmDemo/AlgorithmDemo.xcodeproj \
  -scheme AlgorithmDemo \
  -configuration Debug \
  build
```
