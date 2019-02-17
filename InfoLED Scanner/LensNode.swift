//
//  LensNode.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 2/8/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import SpriteKit

class LensNode : SKNode {
    var lensLabel: SKLabelNode
    var lensBracket: SKShapeNode
    var size: CGSize

    init(size: CGSize) {
        self.lensLabel = SKLabelNode()
        self.lensLabel.position = CGPoint(x: -size.width / 2, y: 0)
        self.lensLabel.verticalAlignmentMode = .bottom
        self.lensLabel.zRotation = CGFloat.pi / 2
        self.lensLabel.fontSize = 10
        self.lensLabel.fontName = "Menlo"
        self.lensBracket = SKShapeNode(rectOf: size)
        self.size = size
        super.init()
        self.addChild(lensLabel)
        self.addChild(lensBracket)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSize(size: CGSize) {
        if size == self.size {
            return
        }
        lensBracket.removeFromParent()
        lensBracket = SKShapeNode(rectOf: size)
        self.addChild(lensBracket)
        self.lensLabel.position.y = size.height / 2
    }

    func setAvailable(available: Bool) {
        self.lensLabel.isHidden = !available
        if available {
            self.lensBracket.strokeColor = .green
        } else {
            self.lensBracket.strokeColor = .gray
        }
    }
}