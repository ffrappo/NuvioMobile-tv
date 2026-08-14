import Foundation

struct IndexedBatchValue<Value: Sendable>: Sendable {
    let index: Int
    let value: Value
}

enum AsyncBatcher {
    static func values<Input: Sendable, Output: Sendable>(
        _ inputs: [Input],
        limit: Int,
        operation: @escaping @Sendable (Input) async -> Output
    ) -> AsyncStream<IndexedBatchValue<Output>> {
        AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: IndexedBatchValue<Output>.self) { group in
                    let concurrency = max(limit, 1)
                    var nextIndex = 0

                    func submitNext() {
                        guard nextIndex < inputs.count, !Task.isCancelled else { return }
                        let index = nextIndex
                        let input = inputs[index]
                        nextIndex += 1
                        group.addTask {
                            IndexedBatchValue(index: index, value: await operation(input))
                        }
                    }

                    for _ in 0..<min(concurrency, inputs.count) { submitNext() }
                    while let result = await group.next() {
                        guard !Task.isCancelled else {
                            group.cancelAll()
                            break
                        }
                        continuation.yield(result)
                        submitNext()
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    static func batches<Input: Sendable, Output: Sendable>(
        _ inputs: [Input],
        limit: Int,
        operation: @escaping @Sendable (Input) async -> Output
    ) -> AsyncStream<[IndexedBatchValue<Output>]> {
        AsyncStream { continuation in
            let task = Task {
                var start = 0
                let batchSize = max(limit, 1)
                while start < inputs.count && !Task.isCancelled {
                    let end = min(start + batchSize, inputs.count)
                    let results = await withTaskGroup(
                        of: IndexedBatchValue<Output>.self,
                        returning: [IndexedBatchValue<Output>].self
                    ) { group in
                        for index in start..<end {
                            let input = inputs[index]
                            group.addTask {
                                IndexedBatchValue(
                                    index: index,
                                    value: await operation(input)
                                )
                            }
                        }
                        var batch: [IndexedBatchValue<Output>] = []
                        for await result in group { batch.append(result) }
                        return batch.sorted { $0.index < $1.index }
                    }
                    if !Task.isCancelled { continuation.yield(results) }
                    start = end
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }
}
