//
//  Queue.swift
//  NTBSwift
//
//  Created by Kåre Morstøl on 11/07/14.
//
//  Using the "Two-Lock Concurrent Queue Algorithm" from http://www.cs.rochester.edu/research/synchronization/pseudocode/queues.html#tlq, without the locks.
// should be an inner class of Queue, but inner classes and generics crash the compiler, SourceKit (repeatedly) and occasionally XCode.
class _QueueItem<T> {
    let value: T!
    var next: _QueueItem?
    init(_ newvalue: T?) {
        self.value = newvalue
    }
}
///
/// A standard queue (FIFO - First In First Out). Supports simultaneous adding and removing, but only one item can be added at a time, and only one item can be removed at a time.
///
public class Queue<T> {
    var _front: _QueueItem<T>
    var _back: _QueueItem<T>
    var _count: Int
    public init () {
        // Insert dummy item. Will disappear when the first item is added.
        _back = _QueueItem(nil)
        _front = _back
        _count = 0
    }
    /// Add a new item to the back of the queue.
    public func enqueue (value: T) {
        _back.next = _QueueItem(value)
        _back = _back.next!
        _count = _count + 1
    }
    /// Return and remove the item at the front of the queue.
    public func dequeue () -> T? {
        if let newhead = _front.next {
            _front = newhead
            _count = _count - 1
            return newhead.value
        } else {
            return nil
        }
    }
    public func isEmpty() -> Bool {
        return _front === _back
    }
    public func count() -> Int {
        return _count
    }
    public func front() -> T? {
        return _front.value
    }
    public func back() -> T? {
        return _back.value
    }
}