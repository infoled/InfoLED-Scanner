//
//  SwitchLens.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/24/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import SpriteKit

class SwitchLens: SKNode, LensObjectProtocol {
    static func checkData(data: [Int]) -> Bool {
        return Array(data.prefix(12)) == [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    }

    private var lensLabel: SKLabelNode
    var lensBracket: SKShapeNode
    var size: CGSize
    var switchId: UInt8!
    var switchState: Bool!

    var appliance: ParticleAppliance?

    let DeviceIds = [0: "230030000647373034353237"]

    required init(size: CGSize) {
        self.lensLabel = SKLabelNode()
        self.lensLabel.position = CGPoint(x: 0, y: size.width / 2)
        self.lensLabel.verticalAlignmentMode = .bottom
        self.lensBracket = SKShapeNode(rectOf: size)
        self.size = size
        super.init()
        self.addChild(lensLabel)
        self.addChild(lensBracket)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setData(data: [Int]) {
        self.switchState = HistoryProcessor.packetToInt(packet: Array(data.suffix(2))) == 1
        self.switchId = UInt8(HistoryProcessor.packetToInt(packet: Array(data.dropLast(2).suffix(2))))
        setLabelText(text: "Switchmate[\(switchId ?? 99)][\(switchState ?? false)]")
        if let deviceId = DeviceIds[Int(switchId)] {
            self.appliance = ParticleAppliancesManager.defaultManager[deviceId]
        }
    }

    func setLabelText(text: String) {
        if text != "" {
            if #available(iOS 11.0, *) {
                let attributedText = NSMutableAttributedString(string: text)
                let entireRange = NSRange(location: 0, length: attributedText.length)
                attributedText.addAttributes([
                    .foregroundColor: UIColor.white,
                    .strokeColor: UIColor.black,
                    .font: UIFont(name: "Menlo", size: 15)!,
                    .strokeWidth: -2.0
                    ], range: entireRange)
                self.lensLabel.attributedText = attributedText
            } else {
                self.lensLabel.text = text
            }
        }
    }

    func setSize(size: CGSize) {
        if size == self.size {
            return
        }
        lensBracket.removeFromParent()
        lensBracket = SKShapeNode(rectOf: size)
        self.addChild(lensBracket)
        self.lensLabel.position.y = -size.height / 2
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

extension SwitchLens {
    override var isUserInteractionEnabled: Bool {
        set {
            // ignore
        }
        get {
            return true
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.appliance?.status == .Initialized {
            self.appliance?.device.callFunction("setSwitch", withArguments: nil, completion: { (number, error) in
                guard error == nil else {
                    print(error!)
                    return
                }
            })
        }
    }
}
