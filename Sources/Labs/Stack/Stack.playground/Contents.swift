struct Stack<T> {
    private var array: [T] = []

    var count: Int {
        array.count
    }
    
    var isEmpty: Bool {
        array.isEmpty
    }

    init(array: [T]) {
        self.array = array
    }

    mutating func push(_ element: T) {
        array.append(element)
    }

    @discardableResult
    mutating func pop() -> T? {
        array.popLast()
    }
    
    func peek() -> T? {
        array.last
    }
}

var stackOfNames = Stack(array: ["A", "B", "C", "D", "E"])
stackOfNames.push("F")
stackOfNames.peek()
stackOfNames.count
