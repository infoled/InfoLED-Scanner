//
//  LensProtocol.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/27/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import SpriteKit

protocol LensObjectProtocol: AnyObject {
    init(size: CGSize)

    func setData(data: [Int])
    func setSize(size: CGSize)
    func setAvailable(available: Bool)
    static func checkData(data: [Int]) -> Bool
}

typealias LensDevice = SKNode & LensDeviceProtocol

protocol LensDeviceProtocol: LensObjectProtocol {
    func checkDataDevice(data: [Int]) -> Bool
    func touch()
}

protocol LensOutputDeviceProtocol: LensDeviceProtocol {
    func input(data: String)
}

protocol LensInputDeviceProtocol: LensDeviceProtocol {
    func addLinked(device: SKNode & LensOutputDeviceProtocol) -> Bool
    func updateLinks()
}
