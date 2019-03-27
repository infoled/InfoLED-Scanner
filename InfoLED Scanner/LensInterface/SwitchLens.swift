//
//  SwitchLens.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/24/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import SpriteKit

class SwitchIcon: SKNode {
    var part1: SKSpriteNode
    var part2_bright: SKSpriteNode
    var part2_dark: SKSpriteNode
    var spinner: SKSpriteNode

    var internalState: SwitchLens.SwitchState
    var state: SwitchLens.SwitchState {
        set(value) {
            let fadeIn = SKAction.fadeIn(withDuration: 0.3)
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            applyEffectForState(state: internalState, effect: fadeOut)
            applyEffectForState(state: value, effect: fadeIn)

            internalState = value
        }
        get {
            return internalState
        }
    }

    func applyEffectForState(state: SwitchLens.SwitchState, effect: SKAction) {
        switch state {
        case .loading:
            self.spinner.removeAllActions()
            self.spinner.run(effect)
        case .on:
            self.part1.removeAllActions()
            self.part1.run(effect)
            self.part2_bright.removeAllActions()
            self.part2_bright.run(effect)
        case .off:
            self.part1.removeAllActions()
            self.part1.run(effect)
            self.part2_dark.removeAllActions()
            self.part2_dark.run(effect)
        }
    }

    override init() {
        let size = IconSize
        part1 = SKSpriteNode(texture: SKTexture(imageNamed: "light-p1"))
        part1.size = size
        part2_bright = SKSpriteNode(texture: SKTexture(imageNamed: "light-p2-bright"))
        part2_bright.size = size
        part2_dark = SKSpriteNode(texture: SKTexture(imageNamed: "light-p2-dark"))
        part2_dark.size = size
        spinner = SKSpriteNode(texture: SKTexture(imageNamed: "spinner"))
        spinner.size = size
        part1.alpha = 0
        part2_bright.alpha = 0
        part2_dark.alpha = 0
        spinner.alpha = 1
        spinner.run(SKAction.rotate(byAngle: 360, duration: 1.0))
        self.internalState = .loading
        super.init()
        self.addChild(part1)
        self.addChild(part2_bright)
        self.addChild(part2_dark)
        self.addChild(spinner)
        self.state = .loading
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SwitchLens: SKNode, LensObjectProtocol {
    static func checkData(data: [Int]) -> Bool {
        return Array(data.prefix(12)) == [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    }

    private var lensLabel: SKLabelNode
    var lensBracket: SKShapeNode?
    var lensIcon: SwitchIcon
    var size: CGSize
    var switchId: UInt8!
    var internalSwitchState: SwitchState
    var switchState: SwitchState {
        get {
            return internalSwitchState
        }
        set(value) {
            if value != internalSwitchState {
                self.lensIcon.state = value
            }
            internalSwitchState = value
        }
    }

    enum SwitchState {
        case loading
        case on
        case off
    }

    var appliance: ParticleAppliance?

    let DeviceIds = [0: "230030000647373034353237"]

    required init(size inputSize: CGSize) {
        let size = IconSize
        self.lensLabel = SKLabelNode()
        self.lensLabel.verticalAlignmentMode = .bottom
        self.lensIcon = SwitchIcon()
        self.size = size
        self.internalSwitchState = .loading
        super.init()
        self.addChild(lensLabel)
        self.addChild(lensIcon)
        self.setSize(size: size)
        self.switchState = .loading
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func getDeviceId(data: [Int]) -> UInt8 {
        return UInt8(HistoryProcessor.packetToInt(packet: Array(data.dropLast(2).suffix(2))))
    }

    override var description: String {
        get {
            return "Switchmate[\(switchId ?? 99)][\(switchState)]"
        }
    }

    func setData(data: [Int]) {
        let lightOn = HistoryProcessor.packetToInt(packet: Array(data.suffix(2))) == 1
        self.switchState = lightOn ? .on : .off
        self.switchId = getDeviceId(data: data)
        setLabelText(text: description)
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

    func setSize(size inputSize: CGSize) {
        let size = IconSize
        if lensBracket != nil {
            if size == self.size {
                return
            }
            lensBracket?.removeFromParent()
        }
        self.lensBracket = SKShapeNode(rectOf: CGSize(width: size.width + 10, height: size.height + 10), cornerRadius: 10)
        self.lensBracket!.fillColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
        self.lensBracket?.zPosition = -10
        self.addChild(lensBracket!)
        self.lensLabel.position.y = size.height / 2 + 10
    }

    func setAvailable(available: Bool) {
        self.lensLabel.isHidden = !available
        if available {
            self.lensBracket?.strokeColor = .green
        } else {
            self.lensBracket?.strokeColor = .gray
        }
    }

    func toggle() {
        if self.appliance?.status == .Initialized {
            self.appliance?.device?.callFunction("setSwitch", withArguments: nil, completion: { (number, error) in
                guard error == nil else {
                    print(error!)
                    return
                }
            })
        }
    }
}

extension SwitchLens: LensOutputDeviceProtocol {
    func checkDataDevice(data: [Int]) -> Bool {
        if (SwitchLens.checkData(data: data)) {
            return getDeviceId(data: data) == self.switchId
        }
        return false
    }

    func input(data: String) {
        toggle()
    }

    func touch() {
        toggle()
    }
}
