//
//  LensNode.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 2/8/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import SpriteKit

protocol LensObjectProtocol {
    func setData(data: [Int])
    func setSize(size: CGSize)
    func setAvailable(available: Bool)
}

class LensNode: SKNode {
    var size: CGSize
    var object: LensObjectProtocol & SKNode

    init(size: CGSize) {
        self.object = DebugLens(size: size)
        self.size = size
        super.init()
        self.addChild(self.object)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setData(data: [Int]) {
        object.setData(data: data)
    }

    func setSize(size: CGSize) {
        self.size = size
        object.setSize(size: size)
    }

    func setAvailable(available: Bool) {
        object.setAvailable(available: available)
    }
}
