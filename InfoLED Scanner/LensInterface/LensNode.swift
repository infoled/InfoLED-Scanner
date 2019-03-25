//
//  LensNode.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 2/8/19.
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

let possibleRepresentations: [LensObjectProtocol.Type] = [SwitchLens.self, DebugLens.self]

class LensNode: SKNode {
    var size: CGSize
    var object: LensObjectProtocol & SKNode
    var data: [Int]?

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
        if self.data != data {
            self.setDifferentData(data: data)
        }
    }

    func setDifferentData(data: [Int]) {
        for representation in possibleRepresentations {
            if (representation.checkData(data: data)) {
                if (!object.isKind(of: representation)) {
                    switchRepresentation(type: representation)
                }
                break
            }
        }
        self.object.setData(data: data)
    }

    func switchRepresentation(type: LensObjectProtocol.Type) {
        self.object.removeFromParent()
        self.object = type.init(size: size) as! SKNode & LensObjectProtocol
        self.addChild(self.object)
    }

    func setSize(size: CGSize) {
        self.size = size
        object.setSize(size: size)
    }

    func setAvailable(available: Bool) {
        object.setAvailable(available: available)
    }
}
