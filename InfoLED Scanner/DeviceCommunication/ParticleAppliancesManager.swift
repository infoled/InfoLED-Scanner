//
//  ParticleAppliancesManager.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/25/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import Foundation
import Particle_SDK

class ParticleAppliancesManager {
    private var deviceMap = [String: ParticleAppliance]()

    subscript(index: String) -> ParticleAppliance {
        if !deviceMap.keys.contains(index) {
            deviceMap[index] = ParticleAppliance(deviceId: index)
            ParticleCloud.sharedInstance().getDevice(index) { [unowned self] (device, error) in
                guard error == nil else {
                    print(error!)
                    self.deviceMap[index]!.deviceError()
                    return
                }
                self.deviceMap[index]!.setDevice(device: device!)
            }
        }
        return deviceMap[index]!
    }

    private static var privateDefaultManager: ParticleAppliancesManager?

    public static var defaultManager: ParticleAppliancesManager {
        if privateDefaultManager == nil {
            privateDefaultManager = ParticleAppliancesManager()
        }
        return privateDefaultManager!
    }
}
