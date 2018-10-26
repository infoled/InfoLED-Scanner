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
    func createTexture(from image: UIImage) throws -> MTLTexture {
        guard let cgImage = image.cgImage else {
            throw TextureCreationError.CannotExtractCGImage
        }

        let textureLoader = MTKTextureLoader(device: self)
        do {
            let textureOut = try textureLoader.newTexture(with: cgImage)
            return textureOut
        }
        catch {
            fatalError("Can't load texture")
        }
    }

    func emptyTexture(from texture: MTLTexture) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat, width: texture.width, height: texture.height, mipmapped: false)
        textureDescriptor.usage = MTLTextureUsage.shaderWrite
        let newTexture = self.makeTexture(descriptor: textureDescriptor)
        return newTexture
    }
}
