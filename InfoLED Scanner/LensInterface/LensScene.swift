//
//  LedLens.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 2/4/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import SpriteKit

let IconSize = CGSize(width: 50, height: 50)

class LensScene: SKScene {

    public var lenses : [Lens] = []
    private var lensNodes : [LensNode] = []

    func convert(size: CGSize) -> CGSize {
        let displayHeight = size.width / CGFloat(Constants.videoWidth) * UIScreen.main.scale * self.size.height
        let displayWidth = size.height / CGFloat(Constants.videoHeight) * UIScreen.main.scale * self.size.width
        return CGSize(width: displayWidth, height: displayHeight)
    }

    func convert(position: CGPoint) -> CGPoint {
        let displayY = (1 - position.x / CGFloat(Constants.videoWidth) * UIScreen.main.scale) * size.height
        let displayX = (1 - position.y / CGFloat(Constants.videoHeight) * UIScreen.main.scale) * size.width
        return CGPoint(x: displayX, y: displayY)
    }

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
            currentNode.position = convert(position: currentLens.position)
            currentNode.setSize(size: convert(size: currentLens.size))
            currentNode.setData(data: currentLens.data)
            currentNode.setAvailable(available: currentLens.detected)
        }
        if lensNodes.count > lenses.count {
            lensNodes.dropFirst(lenses.count).forEach { (node) in
                node.removeFromParent()
            }
            lensNodes.removeLast(lensNodes.count - lenses.count)
        }
    }
}
