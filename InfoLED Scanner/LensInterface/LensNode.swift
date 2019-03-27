//
//  LensNode.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 2/8/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import SpriteKit

let possibleRepresentations: [LensObjectProtocol.Type] = [SwitchLens.self, ButtonLens.self, DebugLens.self]
//let possibleRepresentations: [LensObjectProtocol.Type] = [DebugLens.self]

class LensNode: SKNode {
    var size: CGSize
    var object: LensObjectProtocol & SKNode
    var data: [Int]?

    var lensScene: LensScene {
        get {
            return self.scene! as! LensScene
        }
    }

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
        if let device = lensScene.requestDevice(data: data) {
            self.object.removeFromParent()
            device.removeFromParent()
            self.addChild(device)
            self.object = device
            self.object.position = CGPoint(x: 0, y: 0)
        } else {
            for representation in possibleRepresentations {
                if (representation.checkData(data: data)) {
                    if (!object.isKind(of: representation)) {
                        switchRepresentation(type: representation)
                    }
                    break
                }
            }
        }
        self.object.setData(data: data)
    }

    func switchRepresentation(type: LensObjectProtocol.Type) {
        self.object.removeFromParent()
        if object.self is LensInputDeviceProtocol {
            self.lensScene.addChild(self.object)
            self.object.position = self.position
        }
        if object.self is LensOutputDeviceProtocol {
            self.lensScene.addChild(self.object)
            self.object.position = self.position
        }
        self.object = type.init(size: size) as! SKNode & LensObjectProtocol
        if type is LensInputDeviceProtocol.Type {
            self.lensScene.addInputLens(node: self.object as! SKNode & LensInputDeviceProtocol)
        }
        if type is LensOutputDeviceProtocol.Type {
            self.lensScene.addOutputLens(node: self.object as! SKNode & LensOutputDeviceProtocol)
        }
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
