import XCTest
@testable import NuvioTV

final class AsyncBatcherTests: XCTestCase {
    func testBatchesPreserveInputOrderAndLimit() async {
        let tracker = ConcurrencyTracker()
        var output: [[Int]] = []
        let stream = AsyncBatcher.batches(Array(0..<7), limit: 3) { value in
            await tracker.enter()
            try? await Task.sleep(for: .milliseconds((3 - value % 3) * 10))
            await tracker.leave()
            return value
        }
        for await batch in stream { output.append(batch.map(\.value)) }
        XCTAssertEqual(output, [[0, 1, 2], [3, 4, 5], [6]])
        let maximum = await tracker.maximum
        XCTAssertLessThanOrEqual(maximum, 3)
    }

    func testTerminationCancelsRemainingBatches() async {
        let count = AsyncCounter()
        var iterator: AsyncStream<[IndexedBatchValue<Int>]>.Iterator? = AsyncBatcher
            .batches(Array(0..<20), limit: 2) { value in
                await count.increment()
                try? await Task.sleep(for: .milliseconds(20))
                return value
            }
            .makeAsyncIterator()
        _ = await iterator?.next()
        iterator = nil
        try? await Task.sleep(for: .milliseconds(60))
        let completed = await count.value
        XCTAssertLessThan(completed, 20)
    }
}

private actor ConcurrencyTracker {
    private var current = 0
    private(set) var maximum = 0
    func enter() { current += 1; maximum = max(maximum, current) }
    func leave() { current -= 1 }
}

private actor AsyncCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}
