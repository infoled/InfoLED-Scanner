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

class ILSImageDiff : MPSKernel {

    enum IFLImageDiffError : Error {
        case FailedToGetDefaultLibrary
        case FailedToFindMetalFunction
        case TexturesSizeDoNotMatch
        case TextureTypeNotValid
    }

    let functionName = "image_diff_2d"
    var pipelineState: MTLComputePipelineState!

    override init(device: MTLDevice) {
        super.init(device: device)
        if let library = device.makeDefaultLibrary() {
            if let computeFunction = library.makeFunction(name: functionName) {
                do {
                    try pipelineState = device.makeComputePipelineState(function: computeFunction)
                } catch {
                    print("Error occurred when compiling compute pipeline: \(error)")
                }
            } else {
                print("Failed to retrieve kernel function \(functionName) from library")
            }
        }
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
                sourceTextureLhs.pixelFormat != .bgra8Unorm ||
                sourceTextureRhs.pixelFormat != .bgra8Unorm {
                throw IFLImageDiffError.TextureTypeNotValid
            }
        }
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(sourceTextureLhs, index: 0)
        commandEncoder.setTexture(sourceTextureRhs, index: 1)
        commandEncoder.setTexture(destinationTexture, index: 2)

        let threadGroupCount = MTLSizeMake(16, 16, 1)

        let threadGroups: MTLSize = {
            MTLSizeMake(Int(sourceTextureLhs.width) / threadGroupCount.width,
                        Int(sourceTextureLhs.height) / threadGroupCount.height,
                        1)
        }()

        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
    }
}
