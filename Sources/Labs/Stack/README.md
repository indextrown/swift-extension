# Stack Lab

`Stack`은 현재 Playground 안에서만 사용하는 실험용 구현이다. 기본 접근 제어인 `internal`을 유지하므로 `Labs` Swift Package 모듈의 공개 API로 노출되지 않는다.

```swift
var stack = Stack(array: ["A", "B"])
stack.push("C")
```

`Labs` product에는 추후 외부에 제공할 구현만 추가한다.
