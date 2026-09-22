#if !os(tvOS)
import Foundation
import SwiftUI
import Testing
@testable import SwiftUIExtension

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
@Test func styleDefaultsMatchUIKitAppearance() {
    let style = BottomSheetStyle.default

    #expect(style.cornerRadius == 16)
    #expect(style.showsGrabber)
    #expect(style.grabberSize == CGSize(width: 36, height: 5))
    #expect(style.handleAreaHeight == 28)
    #expect(style.shadowRadius == 8)
    #expect(style.shadowY == -2)
    #expect(style.backdrop == nil)
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
@Test func backdropStyleDefaults() {
    let backdrop = BottomSheetBackdropStyle()

    #expect(backdrop.maximumOpacity == 0.4)
    #expect(backdrop.largestUndimmedDetent == nil)
    #expect(backdrop.collapsesOnTap)
}

@Test("스크롤 상태 preference는 스크롤뷰가 있는 값만 받아요")
func scrollStatePreferenceIgnoresAbsentValues() {
    var value = BottomSheetScrollStateKey.defaultValue

    BottomSheetScrollStateKey.reduce(value: &value) {
        BottomSheetScrollState(isAtTop: false, isPresent: false)
    }
    #expect(value.isAtTop)
    #expect(value.isPresent == false)

    BottomSheetScrollStateKey.reduce(value: &value) {
        BottomSheetScrollState(isAtTop: false, isPresent: true)
    }
    #expect(value.isAtTop == false)
    #expect(value.isPresent)
}

@Test func reexportsCoreTypes() {
    // SwiftUIExtension만 import해도 UIComponentsCore의 타입이 보여야 해요.
    let layout = BottomSheetLayout.standard

    #expect(layout.detents.count == 3)
}
#endif
