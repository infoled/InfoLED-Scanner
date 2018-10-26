//
//  ILSImageDiff.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 4/21/17.
//  Copyright © 2017 yangjunrui. All rights reserved.
//

import Foundation
import MetalPerformanceShaders
import MetalKit

class IFLImageDiff : MPSKernel {

    enum IFLImageDiffError : Error {
        case FailedToGetDefaultLibrary
        case FailedToFindMetalFunction
        case TexturesSizeDoNotMatch
        case TextureTypeNotValid
    }

    public let multiplier : Float

    init(device: MTLDevice, multiplier: Float) {
        self.multiplier = multiplier
        super.init(device: device)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func encode(commandBuffer: MTLCommandBuffer,
                sourceTextureLhs: MTLTexture,
                sourceTextureRhs: MTLTexture,
                destinationTexture: MTLTexture) throws {
        if !self.options.contains(.skipAPIValidation) {
            if sourceTextureLhs.height != sourceTextureRhs.height ||
                sourceTextureLhs.width != sourceTextureRhs.width {
                throw IFLImageDiffError.TexturesSizeDoNotMatch
            }
            if sourceTextureLhs.textureType != .type2D ||
                sourceTextureRhs.textureType != .type2D ||
                sourceTextureLhs.pixelFormat != .rgba8Unorm ||
                sourceTextureRhs.pixelFormat != .rgba8Unorm {
                throw IFLImageDiffError.TextureTypeNotValid
            }
        }
        let defaultLibrary = self.device.newDefaultLibrary()!
        let kernelFunction = defaultLibrary.makeFunction(name: "image_diff_2d")!
        let pipelineState = try! device.makeComputePipelineState(function: kernelFunction)
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(sourceTextureLhs, at: 0)
        commandEncoder.setTexture(sourceTextureRhs, at: 1)
        commandEncoder.setTexture(destinationTexture, at: 2)

        let threadGroupCount = MTLSizeMake(16, 16, 1)

        let threadGroups: MTLSize = {
            MTLSizeMake(Int(sourceTextureLhs.width) / threadGroupCount.width,
                        Int(sourceTextureLhs.height) / threadGroupCount.height,
                        1)
        }()

        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
    }
}
