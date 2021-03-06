//
//  Lens.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/21/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class Lens {
    public var position : CGPoint
    public var data : [Int]
    public var size : CGSize
    public var detected: Bool = false

    public init(position: CGPoint, data: [Int], size: CGSize) {
        self.position = position
        self.data = data
        self.size = size
    }
}
