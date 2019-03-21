//
//  FpsCounter.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 5/19/16.
//  Copyright © 2016 yangjunrui. All rights reserved.
//

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif
import os

open class FpsCounter {
    let callTimeQueue = Queue<Double>();
    open func call (time: Double) -> Double? {
//        os_log("FpsCounter: time %f", time)
        let currentTime = time;
        var frameDuration: Double? = nil;
        if let lastTime = callTimeQueue.back() {
            frameDuration = currentTime - lastTime;
        }
        callTimeQueue.enqueue(currentTime)
        if callTimeQueue.count() > 100 {
            _ = callTimeQueue.dequeue()
        }
        return frameDuration
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
