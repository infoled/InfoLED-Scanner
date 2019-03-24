//
//  Constants.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 2/11/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

extension CGPoint {
    func distance(with point: CGPoint) -> CGFloat {
        return hypot(self.x - point.x, self.y - point.y)
    }
}

class Constants {
    #if os(OSX)
    static let videoWidth = 1920
    static let videoHeight = 1080
    #elseif os(iOS)
    static let videoWidth = 1280
    static let videoHeight = 720
    #endif
    static let decimation = 0.25
    static let decimationLens = 0.25
    static let decimationCcl = 0.25

    static let poiWidth = CGFloat(1 / (decimation * decimationLens))
    static let poiHeight = CGFloat(1 / (decimation * decimationLens))

    static let cycleLimit = 240
}
