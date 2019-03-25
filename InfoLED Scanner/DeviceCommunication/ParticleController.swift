//
//  ParticleController.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/24/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import Particle_SDK

class ParticleController {

    init() {

        let bundle = Bundle.main
        let configPath = bundle.path(forResource: "config", ofType: "plist")!
        let config = NSDictionary(contentsOfFile: configPath)!
        let particleClientSecretconfig = config["ParticleClientSecret"]

        self.particleCloud = ParticleCloud()
        self.particleCloud.log
    }
    static var defaultController: ParticleController {
        get {
        }
    }
}
