//
//  Constants.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 2/11/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import UIKit

class Constants {
    static let videoWidth = 1280
    static let videoHeight = 720
    static let decimation = 0.25
    static let decimationLens = 0.125
    static let decimationCcl = 0.25

    static let poiWidth = CGFloat(1 / (decimation * decimationLens))
    static let poiHeight = CGFloat(1 / (decimation * decimationLens))

    static let cycleLimit = 240
}
