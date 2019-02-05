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
}

class LedLens: SKScene {

    private var lensNodeTemplate : SKShapeNode?
    public var lenses : [Lens] = []
    private var lensNodes : [SKShapeNode] = []

    override func didMove(to view: SKView) {
        if lensNodeTemplate == nil {
            setLensWidth(width: 1.0)
        }
    }

    func setLensWidth(width: CGFloat) {
        self.lensNodeTemplate = SKShapeNode.init(rectOf: CGSize.init(width: width, height: width), cornerRadius: 0)
        if let lensNode = self.lensNodeTemplate {
            lensNode.lineWidth = 1.0          
        }
    }
    

    override func update(_ currentTime: TimeInterval) {
        for i in 0..<lenses.count {
            let currentLens = lenses[i]
            var currentNode : SKShapeNode!
            if i < lensNodes.count {
                currentNode = lensNodes[i]
            } else {
                currentNode = self.lensNodeTemplate?.copy() as? SKShapeNode
                lensNodes.append(currentNode)
                self.addChild(currentNode)
            }
            currentNode.position = CGPoint(x: currentLens.position.x, y: self.size.height - currentLens.position.y)
        }
        if lensNodes.count > lenses.count {
            lensNodes.dropFirst(lenses.count).forEach { (node) in
                node.removeFromParent()
            }
            lensNodes.removeLast(lensNodes.count - lenses.count)
        }
    }
}
