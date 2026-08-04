import Labs
import Testing

@Test func stackSupportsLastInFirstOutAccess() {
    var stack = Stack(array: ["A", "B"])

    stack.push("C")

    #expect(stack.count == 3)
    #expect(stack.pop() == "C")
    #expect(stack.top == "B")
}

@Test func emptyStackHasNoTopElement() {
    var stack = Stack<Int>()

    #expect(stack.count == 0)
    #expect(stack.top == nil)
    #expect(stack.pop() == nil)
}
