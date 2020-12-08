/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

@testable import Basics
import TSCBasic
import TSCTestSupport
import XCTest

final class ConcurrencyHelpersTest: XCTestCase {
    let queue = DispatchQueue(label: "ConcurrencyHelpersTest", attributes: .concurrent)

    func testThreadSafeKeyValueStore() {
        for _ in 0 ..< 100 {
            let sync = DispatchGroup()

            var expected = [Int: Int]()
            let lock = Lock()

            var cache = ThreadSafeKeyValueStore<Int, Int>()
            for index in 0 ..< 1000 {
                self.queue.async(group: sync) {
                    usleep(UInt32.random(in: 100 ... 300))
                    let value = Int.random(in: Int.min ..< Int.max)
                    lock.withLock {
                        expected[index] = value
                    }
                    cache.memoize(index) {
                        value
                    }
                    cache.memoize(index) {
                        Int.random(in: Int.min ..< Int.max)
                    }
                }
            }

            switch sync.wait(timeout: .now() + 1) {
            case .timedOut:
                XCTFail("timeout")
            case .success:
                expected.forEach { key, value in
                    XCTAssertEqual(cache[key], value)
                }
            }
        }
    }

    func testThreadSafeBox() {
        for _ in 0 ..< 100 {
            let sync = DispatchGroup()

            var winner: Int?
            let lock = Lock()

            let serial = DispatchQueue(label: "testThreadSafeBoxSerial")

            var cache = ThreadSafeBox<Int>()
            for index in 0 ..< 1000 {
                self.queue.async(group: sync) {
                    usleep(UInt32.random(in: 100 ... 300))
                    serial.async {
                        lock.withLock {
                            if winner == nil {
                                winner = index
                            }
                        }
                        cache.memoize {
                            index
                        }
                    }
                }
            }

            switch sync.wait(timeout: .now() + 1) {
            case .timedOut:
                XCTFail("timeout")
            case .success:
                XCTAssertEqual(cache.get(), winner)
            }
        }
    }
}