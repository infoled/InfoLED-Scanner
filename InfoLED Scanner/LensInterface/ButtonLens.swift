//
//  ButtonLens.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/26/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import SpriteKit

class ButtonIcon: SKNode {
    var spinner: SKSpriteNode
    var warning: SKSpriteNode
    var button: SKSpriteNode

    var internalState: ButtonLens.ButtonState
    var state: ButtonLens.ButtonState {
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

    func applyEffectForState(state: ButtonLens.ButtonState, effect: SKAction) {
        switch state {
        case .loading:
            self.spinner.removeAllActions()
            self.spinner.run(effect)
        case .lowBattery:
            self.warning.removeAllActions()
            self.warning.run(effect)
        case .noNetwork:
            self.warning.removeAllActions()
            self.warning.run(effect)
        case .ready:
            self.button.removeAllActions()
            self.button.run(effect)
        }
    }

    override init() {
        let size = IconSize
        warning = SKSpriteNode(texture: SKTexture(imageNamed: "warning"))
        warning.size = size
        button = SKSpriteNode(texture: SKTexture(imageNamed: "button"))
        button.size = size
        spinner = SKSpriteNode(texture: SKTexture(imageNamed: "spinner"))
        spinner.size = size
        warning.alpha = 0
        button.alpha = 0
        spinner.alpha = 1
        spinner.run(SKAction.rotate(byAngle: 360, duration: 1.0))
        self.internalState = .loading
        super.init()
        self.addChild(warning)
        self.addChild(button)
        self.addChild(spinner)
        self.state = .loading
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ButtonLens: SKNode, LensObjectProtocol {
    static func checkData(data: [Int]) -> Bool {
        return Array(data.prefix(12)) == [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    }

    private var lensLabel: SKLabelNode
    var warningLabel: SKLabelNode
    var lensBracket: SKShapeNode?
    var lensIcon: ButtonIcon
    var size: CGSize
    var switchId: UInt8!
    var internalButtonState: ButtonState
    var buttonState: ButtonState {
        get {
            return internalButtonState
        }
        set(value) {
            if value != internalButtonState {
                self.lensIcon.state = value
            }
            internalButtonState = value
        }
    }

    enum ButtonState {
        case loading
        case lowBattery
        case noNetwork
        case ready
    }

    var appliance: ParticleAppliance?

    let DeviceIds = [0: "40003b001247363336383437"]

    required init(size inputSize: CGSize) {
        let size = IconSize
        self.lensLabel = SKLabelNode()
        self.lensLabel.verticalAlignmentMode = .bottom
        self.warningLabel = SKLabelNode()
        self.warningLabel.verticalAlignmentMode = .top
        self.lensIcon = ButtonIcon()
        self.size = size
        self.internalButtonState = .loading
        super.init()
        self.addChild(lensLabel)
        self.addChild(lensIcon)
        self.setSize(size: size)
        self.buttonState = .loading
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setData(data: [Int]) {
        let wifiStatus = data[14] == 1
        let batteryStatus = data[15] == 1
        if !wifiStatus {
            buttonState = .noNetwork
            setLabelText(text: "No network connection", label: self.warningLabel)
        } else if !batteryStatus {
            buttonState = .lowBattery
            setLabelText(text: "Low Battery", label: self.warningLabel)
        } else {
            buttonState = .ready
            setLabelText(text: "", label: self.warningLabel)
        }
        self.switchId = UInt8(HistoryProcessor.packetToInt(packet: Array(data.dropLast(2).suffix(2))))
        setLabelText(text: "Button[\(switchId ?? 99)][\(buttonState)]", label: self.lensLabel)
        if let deviceId = DeviceIds[Int(switchId)] {
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
                    .font: UIFont(name: "Menlo", size: 15)!,
                    .strokeWidth: -2.0
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

extension ButtonLens {
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
            switch self.buttonState {
            case .noNetwork:
                let alert = UIAlertController(title: "No network connection", message: "Your smart button is not connected to Wi-Fi", preferredStyle: .actionSheet)
                let alertAction = UIAlertAction(title: "Connect", style: .default)
                {
                    (UIAlertAction) -> Void in
                    self.appliance?.device.callFunction("setWifiState", withArguments: ["on"], completion: { (number, error) in
                        guard error == nil else {
                            print(error!)
                            return
                        }
                    })
                }
                alert.addAction(alertAction)
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                {
                    (UIAlertAction) -> Void in

                }
                alert.addAction(cancelAction)
                UIApplication.shared.keyWindow?.rootViewController!.present(alert, animated: true)
                {
                    () -> Void in
                }
                self.buttonState = .loading
            case .lowBattery:
                let alert = UIAlertController(title: "Low Battery", message: "Your smart button is low on battery", preferredStyle: .actionSheet)
                let alertAction = UIAlertAction(title: "Video walkthrough", style: .default)
                {
                    (UIAlertAction) -> Void in
                    guard let url = URL(string: "https://youtu.be/r2tMu9JnXXI") else { return }
                    UIApplication.shared.open(url)
                }
                alert.addAction(alertAction)
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                {
                    (UIAlertAction) -> Void in

                }
                alert.addAction(cancelAction)
                UIApplication.shared.keyWindow?.rootViewController!.present(alert, animated: true)
                {
                    () -> Void in
                }
            default:
                break
            }
        }
    }
}
