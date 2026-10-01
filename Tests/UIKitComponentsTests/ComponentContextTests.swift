import Testing
@testable import UIKitComponents

@MainActor
@Test func cancelRunsRegisteredActionsOnceInOrder() {
    let context = ComponentContext()
    var calls: [Int] = []
    context.onCancel { calls.append(1) }
    context.onCancel { calls.append(2) }
    context.onCancel { calls.append(3) }

    context.cancel()
    context.cancel()

    #expect(calls == [1, 2, 3])
}

@MainActor
@Test func cancelWithoutActionsOnlyMarksCancelled() {
    let context = ComponentContext()

    context.cancel()

    #expect(context.isCancelled)
}

@MainActor
@Test func onCancelAfterCancelRunsImmediately() {
    let context = ComponentContext()
    context.cancel()
    var didRun = false

    context.onCancel { didRun = true }

    #expect(didRun)
}

@MainActor
@Test func invalidateLayoutReachesHostOnlyUntilCancelled() {
    var invalidations = 0
    let context = ComponentContext { invalidations += 1 }

    context.invalidateLayout()
    context.cancel()
    context.invalidateLayout()

    #expect(invalidations == 1)
}

@MainActor
@Test func taskDoesNotStartOnCancelledContext() async {
    let context = ComponentContext()
    context.cancel()
    var didRun = false

    context.task { didRun = true }
    for _ in 0..<10 {
        await Task.yield()
    }

    #expect(!didRun)
}

@MainActor
@Test func taskIsCancelledWithContext() async {
    let context = ComponentContext()

    let wasCancelled = await withCheckedContinuation { continuation in
        context.task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            continuation.resume(returning: Task.isCancelled)
        }
        context.cancel()
    }

    #expect(wasCancelled)
}
