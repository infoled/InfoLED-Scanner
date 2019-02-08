//
//  LedLens.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 2/4/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import SpriteKit

struct Lens {
    public var position : CGPoint
    public var text : String
    public var size : CGSize
}

class LedLens: SKScene {

    public var lenses : [Lens] = []
    private var lensNodes : [LensNode] = []

    override func update(_ currentTime: TimeInterval) {
        for i in 0..<lenses.count {
            let currentLens = lenses[i]
            var currentNode : LensNode!
            if i < lensNodes.count {
                currentNode = lensNodes[i]
            } else {
                currentNode = LensNode(size:currentLens.size)
                lensNodes.append(currentNode)
                self.addChild(currentNode)
            }
            currentNode.position = CGPoint(x: currentLens.position.x, y: self.size.height - currentLens.position.y)
            currentNode.setSize(size: currentLens.size)
            currentNode.lensLabel.text = currentLens.text
        }
        if lensNodes.count > lenses.count {
            lensNodes.dropFirst(lenses.count).forEach { (node) in
                node.removeFromParent()
            }
            lensNodes.removeLast(lensNodes.count - lenses.count)
        }
    }
}
