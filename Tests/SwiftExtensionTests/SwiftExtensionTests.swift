import Testing
@testable import SwiftExtension

@Test func packageVersionIsAvailable() {
    #expect(SwiftExtension.version == "0.1.0")
}
