//
//  OperatorTests.swift
//  ReactiveKit
//
//  Created by Srdan Rasic on 12/04/16.
//  Copyright © 2016 Srdan Rasic. All rights reserved.
//

import XCTest
import ReactiveKit
import Dispatch

enum TestError: Swift.Error {
    case Error
}

class SignalTests: XCTestCase {

    static let disposeBag = DisposeBag()
    
    override class func tearDown() {
        Self.disposeBag.dispose()
    }
    
    func testPerformance() {
        self.measure {
            (0..<1000).forEach { _ in
                let signal = ReactiveKit.Signal<Int, Never> { observer in
                    (0..<100).forEach(observer.receive(_:))
                    observer.receive(completion: .finished)
                    return NonDisposable.instance
                }
                _ = signal.observe { _ in }
            }
        }
    }

    func testProductionAndObservation() {
        let bob = Scheduler()
        bob.runRemaining()

        let operationObserver1 = TestObserver<Int, TestError>()
        let operationObserver2 = TestObserver<Int, TestError>()

        let operation = Signal<Int, TestError>(sequence: [1, 2, 3]).subscribe(on: bob.context)

        Self.disposeBag += operation.observe(with: operationObserver1.observer)
        Self.disposeBag += operation.observe(with: operationObserver2.observer)

        operationObserver1.assertDidCompleteWithValues([1, 2, 3])
        operationObserver2.assertDidCompleteWithValues([1, 2, 3])
        XCTAssertEqual(bob.numberOfRuns, 2)
    }

    func testDisposing() {
        let e = expectation(description: "Disposed")
        let disposable = BlockDisposable {
            e.fulfill()
        }

        let operation = Signal<Int, TestError> { _ in
            return disposable
        }

        operation.observe { _ in }.dispose()
        wait(for: [e], timeout: 1)
    }

    func testJust() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(just: 1)
        Self.disposeBag += operation.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([1])
    }

    func testSequence() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        Self.disposeBag += operation.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([1, 2, 3])
    }
    
    func testCompleted() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>.completed()
        Self.disposeBag += operation.observe(with: operationObserver.observer)
        operationObserver.assertDidNotEmitValue()
        operationObserver.assertDidComplete()
    }

    func testNever() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>.never()
        Self.disposeBag += operation.observe(with: operationObserver.observer)
        operationObserver.assertDidNotEmitValue()
    }

    func testFailed() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>.failed(.Error)
        Self.disposeBag += operation.observe(with: operationObserver.observer)
        operationObserver.assertDidFail()
    }

    func testObserveFailed() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>.failed(.Error)
        Self.disposeBag += operation.observe(with: operationObserver.observer)
        operationObserver.assertFailed(TestError.Error)
    }

    func testObserveCompleted() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>.completed()
        Self.disposeBag += operation.observe(with: operationObserver.observer)
        operationObserver.assertDidComplete()
    }

    func testBuffer() {
        let operationObserver1 = TestObserver<[Int], Never>()

        let operation1 = SafeSignal(sequence: [1, 2, 3]).buffer(size: 1)
        Self.disposeBag += operation1.observe(with: operationObserver1.observer)

        operationObserver1.assertDidCompleteWithValues([[1], [2], [3]])
        
        let operationObserver2 = TestObserver<[Int], Never>()
        let operation2 = SafeSignal(sequence: [1, 2, 3, 4]).buffer(size: 2)
        Self.disposeBag += operation2.observe(with: operationObserver2.observer)

        operationObserver2.assertDidCompleteWithValues([[1, 2], [3, 4]])

        let operationObserver3 = TestObserver<[Int], Never>()
        let operation3 = SafeSignal(sequence: [1, 2, 3, 4, 5]).buffer(size: 2)
        Self.disposeBag += operation3.observe(with: operationObserver3.observer)

        operationObserver3.assertDidCompleteWithValues([[1, 2], [3, 4]])

    }
    
    func testMap() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let mapped = operation.map { $0 * 2 }
        Self.disposeBag += mapped.observe(with: operationObserver.observer)

        operationObserver.assertDidCompleteWithValues([2, 4, 6])
    }

    func testScan() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let scanned = operation.scan(0, +)
        Self.disposeBag += scanned.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([0, 1, 3, 6])
    }
    
    func testScanForThreadSafety() {
        let subject = PassthroughSubject<Int, TestError>()
        let scanned = subject.scan(0, +)
        let disposeBag = DisposeBag()
        let exp = expectation(description: "race_condition?")
        scanned.stress(with: [subject], expectation: exp).dispose(in: disposeBag)
        waitForExpectations(timeout: 3)
    }

    func testToSignal() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let operation2 = operation.toSignal()
        Self.disposeBag += operation2.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([1, 2, 3])
    }

    func testSuppressError() {
        let operationObserver = TestObserver<Int, Never>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let signal = operation.suppressError(logging: false)
        Self.disposeBag += signal.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([1, 2, 3])
    }

    func testSuppressError2() {
        let operationObserver = TestObserver<Int, Never>()
        let operation = Signal<Int, TestError>.failed(.Error)
        let signal = operation.suppressError(logging: false)
        Self.disposeBag += signal.observe(with: operationObserver.observer)
        operationObserver.assertDidNotEmitValue()
        operationObserver.assertDidComplete()
    }

    func testRecover() {
        let operationObserver = TestObserver<Int, Never>()
        let operation = Signal<Int, TestError>.failed(.Error)
        let signal = operation.replaceError(with: 1)
        Self.disposeBag += signal.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([1])
    }

    func testWindow() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let window = operation.window(ofSize: 2)
        Self.disposeBag += window.merge().observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([1, 2])
    }

    //  func testDebounce() {
    //    let operation = Signal<Int, TestError>.interval(0.1, queue: Queue.global).take(first: 3)
    //    let distinct = operation.debounce(interval: 0.3, on: Queue.global)
    //    let exp = expectation(withDescription: "completed")
    //    distinct.expectComplete(after: [2], expectation: exp)
    //    waitForExpectations(withTimeout: 1)
    //  }

    func testDistinct() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 2, 3])
        let distinct = operation.removeDuplicates(by: ==)
        Self.disposeBag += distinct.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([1, 2, 3])
    }

    func testDistinct2() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 2, 3])
        let distinct = operation.removeDuplicates()
        Self.disposeBag += distinct.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([1, 2, 3])
    }

    func testElementAt() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let elementAt1 = operation.output(at: 1)
        Self.disposeBag += elementAt1.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([2])
    }

    func testFilter() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let filtered = operation.filter { $0 % 2 != 0 }
        Self.disposeBag += filtered.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([1, 3])
    }

    func testFirst() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let first = operation.first()
        Self.disposeBag += first.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([1])
    }

    func testIgnoreElement() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let ignoreElements = operation.ignoreOutput()
        Self.disposeBag += ignoreElements.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([])
    }

    func testLast() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let first = operation.last()
        Self.disposeBag += first.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([3])
    }

    // TODO: sample

    func testSkip() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let skipped1 = operation.dropFirst(1)
        Self.disposeBag += skipped1.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([2, 3])
    }

    func testSkipLast() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let skippedLast1 = operation.dropLast(1)
        Self.disposeBag += skippedLast1.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([1, 2])
    }

    func testTakeFirst() {
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let taken2 = operation.prefix(maxLength: 2)
        taken2.expectComplete(after: [1, 2])
    }

    func testTakeLast() {
        let operationObserver = TestObserver<Int, TestError>()
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let takenLast2 = operation.suffix(maxLength: 2)
        Self.disposeBag += takenLast2.observe(with: operationObserver.observer)
        operationObserver.assertDidCompleteWithValues([2, 3])
    }

    func testTakeFirstOne() {
        let operationObserver = TestObserver<[Bool], Never>()
        let observable = Property(false)
        
        Self.disposeBag += observable
            .prefix(maxLength: 1)
            .collect()
            .observe(with: operationObserver.observer)

        operationObserver.assertDidCompleteWithValues([[false]])
    }

    func testTakeUntil() {
        let operationObserver = TestObserver<Int, TestError>()

        let bob = Scheduler()
        let eve = Scheduler()

        let operation = Signal<Int, TestError>(sequence: [1, 2, 3, 4]).receive(on: bob.context)
        let interrupt = Signal<String, TestError>(sequence: ["A", "B"]).receive(on: eve.context)

        let takeuntil = operation.prefix(untilOutputFrom: interrupt)
        Self.disposeBag += takeuntil.observe(with: operationObserver.observer)

        
        bob.runOne()                // Sends 1.
        bob.runOne()                // Sends 2.
        eve.runOne()                // Sends A, effectively stopping the receiver.
        bob.runOne()                // Ignored.
        eve.runRemaining()          // Ignored. Sends B, with termination.
        bob.runRemaining()          // Ignored.

        operationObserver.assertDidCompleteWithValues([1, 2])
    }

    //  func testThrottle() {
    //    let operation = Signal<Int, TestError>.interval(0.4, queue: Queue.global).take(5)
    //    let distinct = operation.throttle(1)
    //    let exp = expectation(withDescription: "completed")
    //    distinct.expectComplete(after: [0, 3], expectation: exp)
    //    waitForExpectationsWithTimeout(3)
    //  }

    func testIgnoreNils() {
        let operation = Signal<Int?, TestError>(sequence: Array<Int?>([1, nil, 3]))
        let unwrapped = operation.ignoreNils()
        unwrapped.expectComplete(after: [1, 3])
    }

    func testReplaceNils() {
        let operation = Signal<Int?, TestError>(sequence: Array<Int?>([1, nil, 3, nil]))
        let unwrapped = operation.replaceNils(with: 7)
        unwrapped.expectComplete(after: [1, 7, 3, 7])
    }

    func testCombineLatestWith() {
        let bob = Scheduler()
        let eve = Scheduler()

        let operationA = Signal<Int, TestError>(sequence: [1, 2, 3]).receive(on: bob.context)
        let operationB = Signal<String, TestError>(sequence: ["A", "B", "C"]).receive(on: eve.context)
        let combined = operationA.combineLatest(with: operationB).map { "\($0)\($1)" }

        let exp = expectation(description: "completed")
        combined.expectAsyncComplete(after: ["1A", "1B", "2B", "3B", "3C"], expectation: exp)

        bob.runOne()
        eve.runOne()
        eve.runOne()
        bob.runRemaining()
        eve.runRemaining()

        waitForExpectations(timeout: 1)
    }
    
    func testCombineLatestWithForThreadSafety() {
        let subjectOne = PassthroughSubject<Int, TestError>()
        let subjectTwo = PassthroughSubject<Int, TestError>()
        let combined = subjectOne.combineLatest(with: subjectTwo)
        
        let disposeBag = DisposeBag()
        let exp = expectation(description: "race_condition?")
        combined.stress(with: [subjectOne, subjectTwo], expectation: exp).dispose(in: disposeBag)
        
        waitForExpectations(timeout: 3)
    }

    func testMergeWith() {
        let bob = Scheduler()
        let eve = Scheduler()
        let operationA = Signal<Int, TestError>(sequence: [1, 2, 3]).receive(on: bob.context)
        let operationB = Signal<Int, TestError>(sequence: [4, 5, 6]).receive(on: eve.context)
        let merged = operationA.merge(with: operationB)

        let exp = expectation(description: "completed")
        merged.expectAsyncComplete(after: [1, 4, 5, 2, 6, 3], expectation: exp)

        bob.runOne()
        eve.runOne()
        eve.runOne()
        bob.runOne()
        eve.runRemaining()
        bob.runRemaining()

        waitForExpectations(timeout: 1)
    }
    
    func testStartWith() {
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let startWith4 = operation.prepend(4)
        startWith4.expectComplete(after: [4, 1, 2, 3])
    }

    func testZipWith() {
        let operationA = Signal<Int, TestError>(sequence: [1, 2, 3])
        let operationB = Signal<String, TestError>(sequence: ["A", "B"])
        let combined = operationA.zip(with: operationB).map { "\($0)\($1)" }
        combined.expectComplete(after: ["1A", "2B"])
    }
    
    func testZipWithForThreadSafety() {
        let subjectOne = PassthroughSubject<Int, TestError>()
        let subjectTwo = PassthroughSubject<Int, TestError>()
        let combined = subjectOne.zip(with: subjectTwo)
        
        let disposeBag = DisposeBag()
        let exp = expectation(description: "race_condition?")
        combined.stress(with: [subjectOne, subjectTwo], expectation: exp).dispose(in: disposeBag)
        
        waitForExpectations(timeout: 3)
    }

    func testZipWithWhenNotComplete() {
        let operationA = Signal<Int, TestError>(sequence: [1, 2, 3]).ignoreTerminal()
        let operationB = Signal<String, TestError>(sequence: ["A", "B"])
        let combined = operationA.zip(with: operationB).map { "\($0)\($1)" }
        combined.expectComplete(after: ["1A", "2B"])
    }

    func testZipWithWhenNotComplete2() {
        let operationA = Signal<Int, TestError>(sequence: [1, 2, 3])
        let operationB = Signal<String, TestError>(sequence: ["A", "B"]).ignoreTerminal()
        let combined = operationA.zip(with: operationB).map { "\($0)\($1)" }
        combined.expect(events: [.next("1A"), .next("2B")])
    }

    func testZipWithAsyncSignal() {
        let operationA = Signal<Int, TestError>(sequence: 0..<4, interval: 0.5)
        let operationB = Signal<Int, TestError>(sequence: 0..<10, interval: 1.0)
        let combined = operationA.zip(with: operationB).map { $0 + $1 } // Completes after 4 nexts due to operationA and takes 4 secs due to operationB
        let exp = expectation(description: "completed")
        combined.expectAsyncComplete(after: [0, 2, 4, 6], expectation: exp)
        waitForExpectations(timeout: 5.0)
    }

    func testFlatMapError() {
        let operation = Signal<Int, TestError>.failed(.Error)
        let recovered = operation.flatMapError { error in Signal<Int, TestError>(just: 1) }
        recovered.expectComplete(after: [1])
    }

    func testFlatMapError2() {
        let operation = Signal<Int, TestError>.failed(.Error)
        let recovered = operation.flatMapError { error in Signal<Int, Never>(just: 1) }
        recovered.expectComplete(after: [1])
    }

    func testRetry() {
        let bob = Scheduler()
        bob.runRemaining()

        let operation = Signal<Int, TestError>.failed(.Error).subscribe(on: bob.context)
        let retry = operation.retry(3)
        retry.expect(events: [.failed(.Error)])

        XCTAssertEqual(bob.numberOfRuns, 4)
    }
    
    func testRetryForThreadSafety() {
        let subjectOne = PassthroughSubject<Int, TestError>()
        let retry = subjectOne.retry(3)
        
        let disposeBag = DisposeBag()
        let exp = expectation(description: "race_condition?")
        retry.stress(with: [subjectOne], expectation: exp).dispose(in: disposeBag)
        
        waitForExpectations(timeout: 3)
    }

    func testexecuteIn() {
        let bob = Scheduler()
        bob.runRemaining()

        let operation = Signal<Int, TestError>(sequence: [1, 2, 3]).subscribe(on: bob.context)
        operation.expectComplete(after: [1, 2, 3])

        XCTAssertEqual(bob.numberOfRuns, 1)
    }

    // TODO: delay

    func testDoOn() {
        let e = expectation(description: "Disposed")
        let operation = Signal<Int, Never>(sequence: [1, 2, 3])
        var start = 0
        var next = 0
        var completed = 0
        var disposed = 0 {
            didSet {
                e.fulfill()
            }
        }

        let d = operation.handleEvents(receiveSubscription: { start += 1 }, receiveOutput: { _ in next += 1 }, receiveCompletion: { _ in completed += 1 }, receiveCancel: { disposed += 1 }).sink { _ in }

        XCTAssert(start == 1)
        XCTAssert(next == 3)
        XCTAssert(completed == 1)

        d.dispose()
        wait(for: [e], timeout: 1)
    }

    func testobserveIn() {
        let bob = Scheduler()
        bob.runRemaining()

        let operation = Signal<Int, TestError>(sequence: [1, 2, 3]).receive(on: bob.context)
        operation.expectComplete(after: [1, 2, 3])

        XCTAssertEqual(bob.numberOfRuns, 4) // 3 elements + completion
    }

    func testPausable() {
        let operation = PassthroughSubject<Int, TestError>()
        let controller = PassthroughSubject<Bool, TestError>()
        let paused = operation.share().pausable(by: controller)

        let exp = expectation(description: "completed")
        paused.expectAsyncComplete(after: [1, 3], expectation: exp)

        operation.send(1)
        controller.send(false)
        operation.send(2)
        controller.send(true)
        operation.send(3)
        operation.send(completion: .finished)

        waitForExpectations(timeout: 1)
    }

    func testTimeoutNoFailure() {
        let exp = expectation(description: "completed")
        Signal<Int, TestError>(just: 1).timeout(after: 0.2, with: .Error, on: DispatchQueue.main).expectAsyncComplete(after: [1], expectation: exp)
        waitForExpectations(timeout: 1)
    }

    func testTimeoutFailure() {
        let exp = expectation(description: "completed")
        Signal<Int, TestError>.never().timeout(after: 0.5, with: .Error, on: DispatchQueue.main).expectAsync(events: [.failed(.Error)], expectation: exp)
        waitForExpectations(timeout: 1)
    }
    
    func testTimeoutForThreadSafety() {
        let exp = expectation(description: "race_condition?")
        exp.expectedFulfillmentCount = 10000
        for _ in 0..<exp.expectedFulfillmentCount {
            let subject = PassthroughSubject<Int, TestError>()
            let timeout = subject.timeout(after: 1, with: .Error)
            let disposeBag = DisposeBag()
            timeout.stress(with: [subject], eventsCount: 10, expectation: exp).dispose(in: disposeBag)
        }
        waitForExpectations(timeout: 3)
    }

    func testAmbWith() {
        let bob = Scheduler()
        let eve = Scheduler()

        let operationA = Signal<Int, TestError>(sequence: [1, 2]).receive(on: bob.context)
        let operationB = Signal<Int, TestError>(sequence: [3, 4]).receive(on: eve.context)
        let ambdWith = operationA.amb(with: operationB)

        let exp = expectation(description: "completed")
        ambdWith.expectAsyncComplete(after: [3, 4], expectation: exp)

        eve.runOne()
        bob.runRemaining()
        eve.runRemaining()

        waitForExpectations(timeout: 1)
    }

    func testAmbForThreadSafety() {
        let subjectOne = PassthroughSubject<Int, TestError>()
        let subjectTwo = PassthroughSubject<Int, TestError>()
        let combined = subjectOne.amb(with: subjectTwo)
        
        let disposeBag = DisposeBag()
        let exp = expectation(description: "race_condition?")
        combined.stress(with: [subjectOne, subjectTwo], expectation: exp).dispose(in: disposeBag)
        
        waitForExpectations(timeout: 3)
    }
    
    func testCollect() {
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let collected = operation.collect()
        collected.expectComplete(after: [[1, 2, 3]])
    }

    func testAppend() {
        let bob = Scheduler()
        let eve = Scheduler()

        let operationA = Signal<Int, TestError>(sequence: [1, 2]).receive(on: bob.context)
        let operationB = Signal<Int, TestError>(sequence: [3, 4]).receive(on: eve.context)
        let merged = operationA.append(operationB)

        let exp = expectation(description: "completed")
        merged.expectAsyncComplete(after: [1, 2, 3, 4], expectation: exp)

        bob.runOne()
        eve.runOne()
        bob.runRemaining()
        eve.runRemaining()

        waitForExpectations(timeout: 1)
    }
    
    func testWithLatestFrom() {
        let bob = Scheduler()
        let eve = Scheduler()
        
        let operationA = Signal<Int, TestError>(sequence: [1, 2, 5]).receive(on: bob.context)
        let operationB = Signal<Int, TestError>(sequence: [3, 4, 6]).receive(on: eve.context)
        let merged = operationA.with(latestFrom: operationB)
        
        let exp = expectation(description: "completed")
        merged.expectAsyncComplete(after: [(2, 3), (5, 4)], expectation: exp)
        
        bob.runOne()
        eve.runOne()
        bob.runOne()
        eve.runOne()
        bob.runRemaining()
        eve.runRemaining()
        
        waitForExpectations(timeout: 1)
    }
    
    func testWithLatestFromForThreadSafety() {
        let subjectOne = PassthroughSubject<Int, TestError>()
        let subjectTwo = PassthroughSubject<Int, TestError>()
        let merged = subjectOne.with(latestFrom: subjectTwo)
        
        let disposeBag = DisposeBag()
        let exp = expectation(description: "race_condition?")
        merged.stress(with: [subjectOne, subjectTwo], expectation: exp).dispose(in: disposeBag)
        
        waitForExpectations(timeout: 3)
    }

    func testReplaceEmpty() {
        let operation = Signal<Int, TestError>(sequence: [])
        let defaulted = operation.replaceEmpty(with: 1)
        defaulted.expectComplete(after: [1])
    }

    func testReduce() {
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let reduced = operation.reduce(0, +)
        reduced.expectComplete(after: [6])
    }

    func testZipPrevious() {
        let operation = Signal<Int, TestError>(sequence: [1, 2, 3])
        let zipped = operation.zipPrevious()
        zipped.expectComplete(after: [(nil, 1), (1, 2), (2, 3)])
    }

    func testFlatMapMerge() {
        let bob = Scheduler()
        let eves = [Scheduler(), Scheduler()]

        let operation = Signal<Int, TestError>(sequence: [1, 2]).receive(on: bob.context)
        let merged = operation.flatMapMerge { num in
            return Signal<Int, TestError>(sequence: [5, 6].map { $0 * num }).receive(on: eves[num-1].context)
        }

        let exp = expectation(description: "completed")
        merged.expectAsyncComplete(after: [5, 10, 12, 6], expectation: exp)

        bob.runOne()
        eves[0].runOne()
        bob.runRemaining()
        eves[1].runRemaining()
        eves[0].runRemaining()

        waitForExpectations(timeout: 1)
    }
    
    func testFlatMapMergeForThreadSafety() {
        let subjectOne = PassthroughSubject<Int, TestError>()
        let subjectTwo = PassthroughSubject<Int, TestError>()
        let merged = subjectOne.flatMapMerge { _ in subjectTwo }
        
        let disposeBag = DisposeBag()
        let exp = expectation(description: "race_condition?")
        merged.stress(with: [subjectOne, subjectTwo], expectation: exp).dispose(in: disposeBag)
        
        waitForExpectations(timeout: 3)
    }

    func testFlatMapLatest() {
        let bob = Scheduler()
        let eves = [Scheduler(), Scheduler()]

        let operation = Signal<Int, TestError>(sequence: [1, 2]).receive(on: bob.context)
        let merged = operation.flatMapLatest { num in
            return Signal<Int, TestError>(sequence: [5, 6].map { $0 * num }).receive(on: eves[num-1].context)
        }

        let exp = expectation(description: "completed")
        merged.expectAsyncComplete(after: [5, 10, 12], expectation: exp)

        bob.runOne()
        eves[0].runOne()
        bob.runRemaining()
        eves[1].runRemaining()
        eves[0].runRemaining()

        waitForExpectations(timeout: 1)
    }
    
    func testFlatMapLatestForThreadSafety() {
        let subjectOne = PassthroughSubject<Int, TestError>()
        let subjectTwo = PassthroughSubject<Int, TestError>()
        let merged = subjectOne.flatMapLatest { _ in subjectTwo }
        
        let disposeBag = DisposeBag()
        let exp = expectation(description: "race_condition?")
        merged.stress(with: [subjectOne, subjectTwo], expectation: exp).dispose(in: disposeBag)
        
        waitForExpectations(timeout: 3)
    }

    func testFlatMapConcat() {
        let bob = Scheduler()
        let eves = [Scheduler(), Scheduler()]

        let operation = Signal<Int, TestError>(sequence: [1, 2]).receive(on: bob.context)
        let combined = operation.flatMapConcat { num in
            return Signal<Int, TestError>(sequence: [5, 6].map { $0 * num }).receive(on: eves[num-1].context)
        }

        let exp = expectation(description: "completed")
        combined.expectAsyncComplete(after: [5, 6, 10, 12], expectation: exp)

        bob.runRemaining()
        eves[1].runOne()
        eves[0].runRemaining()
        eves[1].runRemaining()

        waitForExpectations(timeout: 1)
    }
    
    func testFlatMapConcatForThreadSafety() {
        let subjectOne = PassthroughSubject<Int, TestError>()
        let subjectTwo = PassthroughSubject<Int, TestError>()
        let merged = subjectOne.flatMapConcat { _ in subjectTwo }
        
        let disposeBag = DisposeBag()
        let exp = expectation(description: "race_condition?")
        merged.stress(with: [subjectOne, subjectTwo], expectation: exp).dispose(in: disposeBag)
        
        waitForExpectations(timeout: 3)
    }

    func testReplay() {
        let bob = Scheduler()
        bob.runRemaining()

        let operation = Signal<Int, TestError>(sequence: [1, 2, 3]).subscribe(on: bob.context)
        let replayed = operation.replay(limit: 2)

        operation.expectComplete(after: [1, 2, 3])
        let _ = replayed.connect()
        replayed.expectComplete(after: [2, 3])
        XCTAssertEqual(bob.numberOfRuns, 2)
    }

    func testReplayLatestWith() {
        let bob = Scheduler()
        let eve = Scheduler()

        let a = Signal<Int, TestError>(sequence: [1, 2, 3]).receive(on: bob.context)
        let b = Signal<String, Never>(sequence: ["A", "A", "A", "A", "A"]).receive(on: eve.context)
        let combined = a.replayLatest(when: b)

        let exp = expectation(description: "completed")
        combined.expectAsyncComplete(after: [1, 2, 2, 2, 3, 3], expectation: exp)

        eve.runOne()
        eve.runOne()
        bob.runOne()
        bob.runOne()
        eve.runOne()
        eve.runOne()
        bob.runOne()
        eve.runRemaining()
        bob.runRemaining()

        waitForExpectations(timeout: 1)
    }
    
    func testReplayLatestWithForThreadSafety() {
        let subjectOne = PassthroughSubject<Int, Never>()
        let subjectTwo = PassthroughSubject<Int, Never>()
        let combined = subjectOne.replayLatest(when: subjectTwo)
        
        let disposeBag = DisposeBag()
        let exp = expectation(description: "race_condition?")
        combined.stress(with: [subjectOne, subjectTwo], expectation: exp).dispose(in: disposeBag)
        
        waitForExpectations(timeout: 3)
    }

    func testPublish() {
        let bob = Scheduler()
        bob.runRemaining()

        let operation = Signal<Int, TestError>(sequence: [1, 2, 3]).subscribe(on: bob.context)
        let published = operation.publish()

        operation.expectComplete(after: [1, 2, 3])
        let _ = published.connect()
        published.expectNoEvent()

        XCTAssertEqual(bob.numberOfRuns, 2)
    }
  
    func testAnyCancallableHashable() {
      let emptyClosure: () -> Void = { }
      
      let cancellable1 = AnyCancellable(emptyClosure)
      let cancellable2 = AnyCancellable(emptyClosure)
      let cancellable3 = AnyCancellable { print("Disposed") }
      let cancellable4 = cancellable3
      
      XCTAssertNotEqual(cancellable1, cancellable2)
      XCTAssertNotEqual(cancellable1, cancellable3)
      XCTAssertEqual(cancellable3, cancellable4)
      
    }

    #if  os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    func testBindTo() {

        class User: NSObject, BindingExecutionContextProvider {

            var age: Int = 0

            var bindingExecutionContext: ExecutionContext {
                return .immediate
            }
        }

        let user = User()

        SafeSignal(just: 20).bind(to: user) { (object, value) in object.age = value }
        XCTAssertEqual(user.age, 20)

        SafeSignal(just: 30).bind(to: user, keyPath: \.age)
        XCTAssertEqual(user.age, 30)
    }
    #endif
}

extension SignalTests {

    static var allTests : [(String, (SignalTests) -> () -> Void)] {
        return [
            ("testPerformance", testPerformance),
            ("testProductionAndObservation", testProductionAndObservation),
            ("testDisposing", testDisposing),
            ("testJust", testJust),
            ("testSequence", testSequence),
            ("testCompleted", testCompleted),
            ("testNever", testNever),
            ("testFailed", testFailed),
            ("testObserveFailed", testObserveFailed),
            ("testObserveCompleted", testObserveCompleted),
            ("testBuffer", testBuffer),
            ("testMap", testMap),
            ("testScan", testScan),
            ("testToSignal", testToSignal),
            ("testSuppressError", testSuppressError),
            ("testSuppressError2", testSuppressError2),
            ("testRecover", testRecover),
            ("testWindow", testWindow),
            ("testDistinct", testDistinct),
            ("testDistinct2", testDistinct2),
            ("testElementAt", testElementAt),
            ("testFilter", testFilter),
            ("testFirst", testFirst),
            ("testIgnoreElement", testIgnoreElement),
            ("testLast", testLast),
            ("testSkip", testSkip),
            ("testSkipLast", testSkipLast),
            ("testTakeFirst", testTakeFirst),
            ("testTakeLast", testTakeLast),
            ("testIgnoreNils", testIgnoreNils),
            ("testReplaceNils", testReplaceNils),
            ("testCombineLatestWith", testCombineLatestWith),
            ("testMergeWith", testMergeWith),
            ("testStartWith", testStartWith),
            ("testZipWith", testZipWith),
            ("testZipWithWhenNotComplete", testZipWithWhenNotComplete),
            ("testZipWithWhenNotComplete2", testZipWithWhenNotComplete2),
            ("testZipWithAsyncSignal", testZipWithAsyncSignal),
            ("testFlatMapError", testFlatMapError),
            ("testFlatMapError2", testFlatMapError2),
            ("testRetry", testRetry),
            ("testexecuteIn", testexecuteIn),
            ("testDoOn", testDoOn),
            ("testobserveIn", testobserveIn),
            ("testPausable", testPausable),
            ("testTimeoutNoFailure", testTimeoutNoFailure),
            ("testTimeoutFailure", testTimeoutFailure),
            ("testAmbWith", testAmbWith),
            ("testCollect", testCollect),
            ("testAppend", testAppend),
            ("testReplaceEmpty", testReplaceEmpty),
            ("testReduce", testReduce),
            ("testZipPrevious", testZipPrevious),
            ("testFlatMapMerge", testFlatMapMerge),
            ("testFlatMapLatest", testFlatMapLatest),
            ("testFlatMapConcat", testFlatMapConcat),
            ("testReplay", testReplay),
            ("testPublish", testPublish),
            ("testReplayLatestWith", testReplayLatestWith),
            ("testAnyCancallableHashable", testAnyCancallableHashable)
        ]
    }
}
