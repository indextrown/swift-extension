/// A last-in, first-out collection.
public struct Stack<Element> {
    private var elements: [Element]

    /// Creates an empty stack.
    public init() {
        elements = []
    }

    /// Creates a stack whose top is the final element of `elements`.
    public init(array: [Element]) {
        elements = array
    }

    /// The number of elements in the stack.
    public var count: Int {
        elements.count
    }

    /// The element at the top of the stack, if one exists.
    public var top: Element? {
        elements.last
    }

    /// Adds an element to the top of the stack.
    public mutating func push(_ element: Element) {
        elements.append(element)
    }

    /// Removes and returns the element at the top of the stack.
    public mutating func pop() -> Element? {
        elements.popLast()
    }
}
