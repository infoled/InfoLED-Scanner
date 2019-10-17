//
//  SensorLens.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 4/5/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import SpriteKit

class SensorIcon: SKNode {
    var spinner: SKSpriteNode
    var sensor: SKSpriteNode

    var internalState: SensorLens.SensorState
    var state: SensorLens.SensorState {
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

    func applyEffectForState(state: SensorLens.SensorState, effect: SKAction) {
        switch state {
        case .loading:
            self.spinner.removeAllActions()
            self.spinner.run(effect)
        case .ready:
            self.sensor.removeAllActions()
            self.sensor.run(effect)
        }
    }

    override init() {
        let size = IconSize
        sensor = SKSpriteNode(texture: SKTexture(imageNamed: "sensor"))
        sensor.size = size
        spinner = SKSpriteNode(texture: SKTexture(imageNamed: "spinner"))
        spinner.size = size
        sensor.alpha = 0
        spinner.alpha = 1
        spinner.run(SKAction.rotate(byAngle: 360, duration: 1.0))
        self.internalState = .loading
        super.init()
        self.addChild(sensor)
        self.addChild(spinner)
        self.state = .loading
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SensorLens: SKNode, LensObjectProtocol {
    static func checkData(data: [Int]) -> Bool {
        let checkDevice = Array(data.prefix(8)) == [1, 0, 1, 0, 0, 0, 0, 1]
        let checkId = deviceIds.keys.contains(Int(getDeviceId(data: data)))
        return checkDevice && checkId
    }

    private var lensLabel: SKLabelNode
    var warningLabel: SKLabelNode
    var lensBracket: SKShapeNode?
    var lensIcon: SensorIcon
    var size: CGSize
    var sensorId: UInt8!
    var internalSensorState: SensorState
    var sensorState: SensorState {
        get {
            return internalSensorState
        }
        set(value) {
            if value != internalSensorState {
                self.lensIcon.state = value
            }
            internalSensorState = value
        }
    }

    enum SensorState {
        case loading
        case ready
    }

    var value = 0

    var appliance: ParticleAppliance?

    var subscriberId: Any?

    var linkedDevices = [SKNode & LensOutputDeviceProtocol]()
    var linkedDeviceLinks = [SKNode: SKShapeNode]()

    static let deviceIds = [0: "520034000c51353432383931"]

    required init(size inputSize: CGSize) {
        let size = IconSize
        self.lensLabel = SKLabelNode()
        self.lensLabel.verticalAlignmentMode = .bottom
        self.warningLabel = SKLabelNode()
        self.warningLabel.verticalAlignmentMode = .top
        self.lensIcon = SensorIcon()
        self.size = size
        self.internalSensorState = .loading
        super.init()
        self.addChild(lensLabel)
        self.addChild(lensIcon)
        self.setSize(size: size)
        self.sensorState = .loading
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var description: String {
        get {
            //            return "Sensor[\(sensorId ?? 99)][\(sensorState)]"
            return "Air Quality: \(value * 3 + 21)"
        }
    }

    static func getDeviceId(data: [Int]) -> UInt8 {
        return 0
    }

    static func valueFromBit(bits: [Int]) -> Int {
        var value = 0;
        for i in 0..<8 {
            value += (bits[i] << i)
        }
        return value
    }

    static func getSensorValue(data: [Int]) -> Int {
        let valueBits = Array(data[8..<16])
        return valueFromBit(bits: valueBits)
    }

    func setData(data: [Int]) {
        sensorState = .ready
        self.sensorId = SensorLens.getDeviceId(data: data)
        self.value = SensorLens.getSensorValue(data: data)
        setLabelText(text: description, label: self.lensLabel)
        if let deviceId = SensorLens.deviceIds[Int(sensorId)] {
            self.appliance = ParticleAppliancesManager.defaultManager[deviceId]
        }
    }

    func setLabelText(text: String, label: SKLabelNode) {
        if text != "" {
            if #available(iOS 11.0, *) {
                let attributedText = NSMutableAttributedString(string: text)
                let entireRange = NSRange(location: 0, length: attributedText.length)
                attributedText.addAttributes([
                    .foregroundColor: UIColor.white,
                    .strokeColor: UIColor.black,
                    .font: UIFont(name: "Menlo-Bold", size: 15)!,
                    .strokeWidth: -5.0
                    ], range: entireRange)
                label.attributedText = attributedText
            } else {
                label.text = text
            }
        } else {
            label.text = text
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
        self.lensBracket!.fillColor = #colorLiteral(red: 0.1411764771, green: 0.3960784376, blue: 0.5647059083, alpha: 1)
        self.lensBracket?.zPosition = -10
        self.addChild(lensBracket!)
        self.lensLabel.position.y = size.height / 2 + 10
        self.warningLabel.position.y = -(size.height / 2 + 10)
    }

    func setAvailable(available: Bool) {
        self.lensLabel.isHidden = !available
        if available {
            self.lensBracket?.strokeColor = .green
        } else {
            self.lensBracket?.strokeColor = .gray
        }
    }
}

extension SensorLens: LensInputDeviceProtocol {
    func subscribe() -> Bool {
        guard let appliance = self.appliance else {
            return false
        }
        guard let device = appliance.device else {
            return false
        }
        return true;
    }

    func addLinked(device: SKNode & LensOutputDeviceProtocol) -> Bool {
        if (subscriberId == nil) {
            _ = subscribe()
        }
        guard subscriberId != nil else {
            return false
        }
        linkedDevices.append(device)
        let link = SKShapeNode()
        link.strokeColor = #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)
        link.lineWidth = 5
        linkedDeviceLinks[device] = link
        addChild(link)
        return true
    }

    func updateLinks() {
        for device in linkedDevices {
            let position = device.convert(CGPoint(x: 0, y: 0), to: self)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: position)
            linkedDeviceLinks[device]?.path = path
        }
    }

    func checkDataDevice(data: [Int]) -> Bool {
        if (SensorLens.checkData(data: data)) {
            return SensorLens.getDeviceId(data: data) == self.sensorId
        }
        return false
    }

    func touch() {
    }
}
