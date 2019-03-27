//
//  ParticleAppliance.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/25/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import Foundation
import Particle_SDK

class ParticleAppliance {
    let deviceId: String
    enum Status {
        case Loading
        case Error
        case Initialized
    }
    var status: Status = .Loading
    var device: ParticleDevice?

    init(deviceId: String) {
        self.deviceId = deviceId
    }

    func setDevice(device: ParticleDevice) {
        self.device = device
        self.status = .Initialized
    }

    func deviceError() {
        self.status = .Error
    }
}
