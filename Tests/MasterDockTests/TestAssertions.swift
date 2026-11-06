import Foundation

public struct TestFailure: Error {
    public let message: String
}

public func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, file: String = #file, line: Int = #line) {
    if a != b {
        print("\n   ❌ FAILURE: '\(a)' is not equal to '\(b)' [\(file):\(line)]")
        exit(1)
    }
}

public func XCTAssertEqual(_ a: Double, _ b: Double, accuracy: Double, file: String = #file, line: Int = #line) {
    if abs(a - b) > accuracy {
        print("\n   ❌ FAILURE: '\(a)' is not within \(accuracy) of '\(b)' [\(file):\(line)]")
        exit(1)
    }
}

public func XCTAssertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
    if !condition {
        print("\n   ❌ FAILURE: Expected true, got false. \(message) [\(file):\(line)]")
        exit(1)
    }
}

public func XCTAssertFalse(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
    if condition {
        print("\n   ❌ FAILURE: Expected false, got true. \(message) [\(file):\(line)]")
        exit(1)
    }
}

public func XCTAssertGreaterThan<T: Comparable>(_ a: T, _ b: T, file: String = #file, line: Int = #line) {
    if a <= b {
        print("\n   ❌ FAILURE: '\(a)' is not greater than '\(b)' [\(file):\(line)]")
        exit(1)
    }
}

public func XCTAssertNotNil<T>(_ a: T?, _ message: String = "", file: String = #file, line: Int = #line) {
    if a == nil {
        print("\n   ❌ FAILURE: Expected non-nil value, got nil. \(message) [\(file):\(line)]")
        exit(1)
    }
}

public func XCTAssertNil<T>(_ a: T?, _ message: String = "", file: String = #file, line: Int = #line) {
    if a != nil {
        print("\n   ❌ FAILURE: Expected nil, got '\(String(describing: a))'. \(message) [\(file):\(line)]")
        exit(1)
    }
}

public func XCTFail(_ message: String, file: String = #file, line: Int = #line) {
    print("\n   ❌ FAILURE: \(message) [\(file):\(line)]")
    exit(1)
}
