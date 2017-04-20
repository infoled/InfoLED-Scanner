//
//  FpsCounter.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 5/19/16.
//  Copyright © 2016 yangjunrui. All rights reserved.
//

import UIKit

open class FpsCounter {
    let callTimeQueue = Queue<TimeInterval>();
    open func call () {
        callTimeQueue.enqueue(Date().timeIntervalSince1970)
        if callTimeQueue.count() > 100 {
            _ = callTimeQueue.dequeue()
        }
    }

    open func getFps() -> Double {
        if let front = callTimeQueue.front() {
            if let back = callTimeQueue.back() {
                if callTimeQueue.count() > 1 {
                    let count = callTimeQueue.count()
                    let fps = (back - front) / Double(count - 1)
                    return 1.0 / fps;
                }
            }
        }
        return 0.0
    }
}
