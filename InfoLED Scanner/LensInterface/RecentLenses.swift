//
//  RecentLenses.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/27/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import SpriteKit

let LensMovementSpeed = CGFloat(300)

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow((point.x - x), 2) + pow((point.y - y), 2))
    }
}

class RecentLenses: SKNode {
    var bracketNode: SKShapeNode
    var size: CGSize

    private var recentDevices = Set<SKNode>()
    private var recentDeviceAddedTime = [SKNode: NSDate]()
    let maxDevices = 5

    init(size parentSize: CGSize) {
        size = CGSize(width: parentSize.width / 2 - 10, height: IconSize.height + 20)
        self.bracketNode = SKShapeNode.init(rectOf: size, cornerRadius: 10)
        self.bracketNode.fillColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        super.init()
        addChild(self.bracketNode)
    }

    func addRecentDevice(device: LensDevice) {
        recentDevices.insert(device)
        recentDeviceAddedTime[device] = NSDate()
    }

    func removeRecentDevice(device: LensDevice) {
        recentDevices.remove(device)
        recentDeviceAddedTime.removeValue(forKey: device)
    }

    var devicePositions: [CGPoint] {
        let spacing = IconSize.width + 10
        let offset =  -spacing * CGFloat(recentDevices.count) / 2
        return Array((0..<recentDevices.count).map{CGPoint(x: CGFloat($0) * spacing + offset, y: 0)})
    }

    func updateDevicePositions() {
        while recentDevices.count > maxDevices {
            recentDevices.remove(recentDevices.first!)
        }
        for (device, position) in zip(recentDevices, devicePositions) {
            if (recentDeviceAddedTime[device]!.timeIntervalSinceNow < -1.0) {
                let distance = position.distance(to: device.position)
                let time = distance / LensMovementSpeed
                device.run(SKAction.move(to: position, duration: TimeInterval(time)))
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
