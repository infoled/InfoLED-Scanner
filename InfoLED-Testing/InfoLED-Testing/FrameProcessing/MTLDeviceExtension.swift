//
//  MTLDeviceExtension.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 4/22/17.
//  Copyright © 2017 yangjunrui. All rights reserved.
//

import Foundation
import Metal
import MetalKit


enum TextureCreationError : Error {
    case CannotExtractCGImage
}

extension MTLDevice {

    func emptyTexture(from texture: MTLTexture) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat, width: texture.width, height: texture.height, mipmapped: false)
        textureDescriptor.usage = MTLTextureUsage.shaderWrite
        let newTexture = self.makeTexture(descriptor: textureDescriptor)
        return newTexture!
    }
}
