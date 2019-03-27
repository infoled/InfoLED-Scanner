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
    private var recentLensesNode: RecentLenses!;

    private var connectionLine: SKShapeNode?
    private var connectionTouch: UITouch?
    private var connectionInput: (SKNode & LensInputDeviceProtocol)?

    private var inputLensNodes = [SKNode & LensInputDeviceProtocol]()
    private var outputLensNodes = [SKNode & LensOutputDeviceProtocol]()

    override func sceneDidLoad() {
        recentLensesNode = RecentLenses(size: self.size)
        addChild(recentLensesNode)
        recentLensesNode.position = CGPoint(x: self.size.width / 4, y: recentLensesNode.size.height / 2)
    }

    func unclaimDevice(device: SKNode & LensDeviceProtocol) {
        device.removeAllActions()
        device.move(toParent: recentLensesNode)
        device.zPosition = 10
        recentLensesNode.recentDevices.append(device)
    }

    func claimDevice(device: SKNode & LensDeviceProtocol, for node: SKNode) {
        device.removeAllActions()
        recentLensesNode.recentDevices.removeAll { (recentDevice) -> Bool in
            return recentDevice == device
        }
        device.move(toParent: node)
    }

    func addInputLens(node: SKNode & LensInputDeviceProtocol) {
        inputLensNodes.append(node)
    }

    func addOutputLens(node: SKNode & LensOutputDeviceProtocol) {
        outputLensNodes.append(node)
    }

    func requestDevice(data: [Int]) -> (SKNode & LensDeviceProtocol)? {
        for device in inputLensNodes as [SKNode & LensDeviceProtocol] + outputLensNodes as [SKNode & LensDeviceProtocol] {
            if device.checkDataDevice(data: data) {
                return device
            }
        }
        return nil
    }

    var realSize: CGSize {
        get {
            let width = self.size.width
            let height = self.size.width * 640 / 360
            return CGSize(width: width, height: height)
        }
    }

    func convert(size: CGSize) -> CGSize {
        let displayHeight = size.width / CGFloat(Constants.videoWidth) * UIScreen.main.scale * realSize.height
        let displayWidth = size.height / CGFloat(Constants.videoHeight) * UIScreen.main.scale * realSize.width
        return CGSize(width: displayWidth, height: displayHeight)
    }

    func convert(position: CGPoint) -> CGPoint {
        let displayY = self.size.height - position.x / CGFloat(Constants.videoWidth) * UIScreen.main.scale * realSize.height
        let displayX = (1 - position.y / CGFloat(Constants.videoHeight) * UIScreen.main.scale) * realSize.width
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
            currentNode.setSize(size: convert(size: currentLens.size))
            currentNode.setData(data: currentLens.data)
            currentNode.setAvailable(available: currentLens.detected)
            currentNode.position = convert(position: currentLens.position)
        }
        if lensNodes.count > lenses.count {
            lensNodes.dropFirst(lenses.count).forEach { (node) in
                node.removeFromParent()
            }
            lensNodes.removeLast(lensNodes.count - lenses.count)
        }
        for input in inputLensNodes {
            input.updateLinks()
        }
        recentLensesNode.updateDevicePositions()
    }
}

extension LensScene {
    override var isUserInteractionEnabled: Bool {
        get {
            return true
        }
        set {
        }
    }

    func getParent<T>(node: SKNode?, as type: T.Type) -> T? {
        var currentNode: SKNode? = node
        while currentNode != nil {
            if currentNode is T {
                return currentNode as? T
            } else {
                currentNode = currentNode?.parent
            }
        }
        return nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let position = touch.location(in: self)
            if let childrenNode = nodes(at: position).first {
                if let touchedNode = getParent(node: childrenNode, as: (SKNode & LensInputDeviceProtocol).self) {
                    connectionInput = touchedNode
                    connectionTouch = touch
                    let path = CGMutablePath()
                    path.move(to: touchedNode.convert(CGPoint(x: 0, y: 0), to: self))
                    path.addLine(to: position)
                    connectionLine = SKShapeNode()
                    connectionLine?.path = path
                    connectionLine?.strokeColor = #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)
                    connectionLine?.lineWidth = 5
                    addChild(connectionLine!)
                    break
                }
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = connectionTouch {
            if touches.contains(touch) {
                let position = touch.location(in: self)
                let path = CGMutablePath()
                path.move(to: connectionInput!.convert(CGPoint(x: 0, y: 0), to: self))
                path.addLine(to: position)
                connectionLine?.path = path
            } else {
                connectionLine?.removeFromParent()
                connectionTouch = nil
                connectionLine = nil
                connectionInput = nil
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        var resolved = false
        if let touch = connectionTouch {
            if touches.contains(touch) {
                let position = touch.location(in: self)
                for childrenNode in nodes(at: position) {
                    if let touchedNode = getParent(node: childrenNode, as: LensDeviceProtocol.self){
                        if touchedNode is LensOutputDeviceProtocol {
                            _ = connectionInput?.addLinked(device: touchedNode as! (SKNode & LensOutputDeviceProtocol))
                            resolved = true
                            break
                        }
                    }
                }
            }
            connectionLine?.removeFromParent()
            connectionTouch = nil
            connectionLine = nil
            connectionInput = nil
        }
        if !resolved {
            for touch in touches {
                let position = touch.location(in: self)
                if let childrenNode = nodes(at: position).first {
                    if let touchedNode = getParent(node: childrenNode, as: LensDeviceProtocol.self){
                        touchedNode.touch()
                    }
                }
            }
        }
    }
}
