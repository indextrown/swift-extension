struct Stack<T> {
    private var array: [T] = []

    var count: Int {
        array.count
    }

    var top: T? {
        array.last
    }

    init(array: [T]) {
        self.array = array
    }

    mutating func push(_ element: T) {
        array.append(element)
    }

    mutating func pop() -> T? {
        array.popLast()
    }
}

var stackOfNames = Stack(array: ["A", "B", "C", "D", "E"])
stackOfNames.push("F")
stackOfNames.top
stackOfNames.count
