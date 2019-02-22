//
//  SampleBufferProcessor.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 2/21/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import AVFoundation
import Metal
import MetalKit
import MetalPerformanceShaders

class SampleBufferProcessor {

    lazy var metalDevice : MTLDevice! = MTLCreateSystemDefaultDevice()

    let computeQueue = DispatchQueue(label: "me.jackieyang.infoled.computeQueue")
    let captureQueue = DispatchQueue(label: "me.jackieyang.infoled.captureQueue")
    let renderQueue = DispatchQueue(label: "me.jackieyang.infoled.renderQueue")

    let imageProcessingQueue = DispatchQueue(label: "me.jackieyang.processing-queue")

    fileprivate lazy var captureTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(Constants.videoWidth) * Constants.decimation), height: Int(Double(Constants.videoHeight) * Constants.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var lensTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(Constants.videoWidth) * Constants.decimation * Constants.decimationLens), height: Int(Double(Constants.videoHeight) * Constants.decimation * Constants.decimationLens), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var oldCaptureTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(Constants.videoWidth) * Constants.decimation), height: Int(Double(Constants.videoHeight) * Constants.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var brightCaptureTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(Constants.videoWidth) * Constants.decimation), height: Int(Double(Constants.videoHeight) * Constants.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var diffTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(Constants.videoWidth) * Constants.decimation), height: Int(Double(Constants.videoHeight) * Constants.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var thresholdTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(Constants.videoWidth) * Constants.decimation), height: Int(Double(Constants.videoHeight) * Constants.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var erodeTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(Constants.videoWidth) * Constants.decimation), height: Int(Double(Constants.videoHeight) * Constants.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var dilateTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(Constants.videoWidth) * Constants.decimation), height: Int(Double(Constants.videoHeight) * Constants.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var cclTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(Constants.videoWidth) * Constants.decimation * Constants.decimationCcl), height: Int(Double(Constants.videoHeight) * Constants.decimation * Constants.decimationCcl), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var displayTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(Constants.videoWidth) * Constants.decimation), height: Int(Double(Constants.videoHeight) * Constants.decimation), mipmapped: false)
        textureDescriptor.usage = MTLTextureUsage.shaderWrite
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    lazy var processedImage = [UInt8](repeating: 0, count: Int(Double(Constants.videoWidth * Constants.videoHeight * 4) * Constants.decimation * Constants.decimation * Constants.decimationCcl * Constants.decimationCcl))

    fileprivate lazy var captureCommandQueue : MTLCommandQueue! = {
        NSLog("\(self.metalDevice.name)")
        return self.metalDevice.makeCommandQueue()
    }()

    fileprivate lazy var computeCommandQueue : MTLCommandQueue! = {
        NSLog("\(self.metalDevice.name)")
        return self.metalDevice.makeCommandQueue()
    }()

    fileprivate lazy var renderCommandQueue : MTLCommandQueue! = {
        NSLog("\(self.metalDevice.name)")
        return self.metalDevice.makeCommandQueue()
    }()

    fileprivate lazy var textureCache : CVMetalTextureCache! = {
        var _textureCache : CVMetalTextureCache?
        let error = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.metalDevice, nil, &_textureCache)
        assert(error == kCVReturnSuccess)
        return _textureCache
    }()

    var resizeKernel: MPSImageLanczosScale!
    var diffKernel: ILSImageDiff!
    var thresholdKernel: MPSImageThresholdBinary!
    var erodeKernel: MPSImageAreaMin!
    var dilateKernel: MPSImageAreaMax!
    var resize2Kernel: MPSImageLanczosScale!
    var brightKernel: MPSImageConvolution!

    var delegate: SampleBufferProcessorDelegate

    init(delegate: SampleBufferProcessorDelegate) {
        self.delegate = delegate
        self.delegate.historyLenses = (0..<SampleBufferProcessor.lensCount).map({ (_) in
            return HistoryLens(windowSize: windowSampleSize, poiSize: CGSize(width: Constants.poiWidth, height: Constants.poiHeight))
        })

        // Build MPS kernels
        buildKernels()
    }

    func buildKernels() {
        resizeKernel = MPSImageLanczosScale(device: self.metalDevice)
        diffKernel = ILSImageDiff(device: self.metalDevice)
        let colorTransform: [Float] = [1.0, 1.0, 1.0]
        withUnsafePointer(to: colorTransform) { (colorTransformRef) in
            thresholdKernel = MPSImageThresholdBinary(device: self.metalDevice, thresholdValue: 0.1, maximumValue: 1.0, linearGrayColorTransform: colorTransform)
        }
        erodeKernel = MPSImageAreaMin(device: metalDevice, kernelWidth: 3, kernelHeight: 3)
        dilateKernel = MPSImageAreaMax(device: metalDevice, kernelWidth: 3, kernelHeight: 3)
        resize2Kernel = MPSImageLanczosScale(device: self.metalDevice)

        var brightValue: [Float] = [16.0]
        brightKernel = MPSImageConvolution(device: metalDevice, kernelWidth: 1, kernelHeight: 1, weights: &brightValue)
    }

    func processSampleBuffer(sampleBuffer: CMSampleBuffer) {
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let frameDuration = self.delegate.callFpsCounter(time: presentationTime.seconds)

        captureQueue.async {
            swap(&self.captureTexture, &self.oldCaptureTexture)

            let localBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
            let imageWidth  = CVPixelBufferGetWidth(localBuffer)
            let imageHeight = CVPixelBufferGetHeight(localBuffer)
            var cvImageTexture: CVMetalTexture?

            CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                      self.textureCache,
                                                      localBuffer,
                                                      nil,
                                                      MTLPixelFormat.bgra8Unorm,
                                                      imageWidth,
                                                      imageHeight,
                                                      0,
                                                      &cvImageTexture)

            let imageTexture = CVMetalTextureGetTexture(cvImageTexture!)!

            //        CVPixelBufferLockBaseAddress(localBuffer, CVPixelBufferLockFlags.readOnly)
            //        CVPixelBufferUnlockBaseAddress(localBuffer, CVPixelBufferLockFlags.readOnly)
            let captureCommandBuffer = self.captureCommandQueue.makeCommandBuffer()!
            var transform = MPSScaleTransform(scaleX: Constants.decimation, scaleY: Constants.decimation, translateX: 0, translateY: 0)

            withUnsafePointer(to: &transform, { (transformPtr) in
                self.resizeKernel.scaleTransform = transformPtr
                self.resizeKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: imageTexture, destinationTexture: self.captureTexture)
            })

            var lensTransform = MPSScaleTransform(scaleX: Constants.decimationLens, scaleY: Constants.decimationLens, translateX: 0, translateY: 0)

            withUnsafePointer(to: &lensTransform, { (lensTransformPtr) in
                self.resizeKernel.scaleTransform = lensTransformPtr
                self.resizeKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.captureTexture, destinationTexture: self.lensTexture)
            })

            try! self.diffKernel.encode(commandBuffer: captureCommandBuffer, sourceTextureLhs: self.oldCaptureTexture, sourceTextureRhs: self.captureTexture, destinationTexture: self.diffTexture)

            self.thresholdKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.diffTexture, destinationTexture: self.thresholdTexture)

            self.erodeKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.thresholdTexture, destinationTexture: self.erodeTexture)

            self.dilateKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.erodeTexture, destinationTexture: self.dilateTexture)

            self.brightKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.captureTexture, destinationTexture: self.brightCaptureTexture)

            var transform2 = MPSScaleTransform(scaleX: Constants.decimationCcl, scaleY: Constants.decimationCcl, translateX: 0, translateY: 0)
            withUnsafePointer(to: &transform2, { (transformPtr) in
                self.resize2Kernel.scaleTransform = transformPtr
                self.resize2Kernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.dilateTexture, destinationTexture: self.cclTexture)
            })

            captureCommandBuffer.addCompletedHandler({ (MTLCommandBuffer) in
                let bytesPerRow = self.cclTexture.width * 4
                let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                       size: MTLSize(width: self.cclTexture.width,
                                                     height: self.cclTexture.height,
                                                     depth: self.cclTexture.depth))
                self.cclTexture.getBytes(&self.processedImage,
                                         bytesPerRow: bytesPerRow,
                                         from: region,
                                         mipmapLevel: 0)
                let labelImage = CcImage(array: &self.processedImage,
                                         width: self.cclTexture.width,
                                         height: self.cclTexture.height,
                                         bytesPerPixel: 4);
                let labelResult = CcLabel.labelImageFast(data: labelImage,
                                                         calculateBoundingBoxes: true)

                if let boundingBoxes = labelResult.boundingBoxes {
                    self.updateBoundingBoxes(boundingBoxes: boundingBoxes)
                }

                self.renderQueue.async {
                    self.displayTexture = self.brightCaptureTexture
                }

                for lens in self.delegate.historyLenses {
                    lens.processFrame(lensTexture: self.lensTexture, imageProcessingQueue: self.imageProcessingQueue, frameDuration: frameDuration)
                }
            })
            captureCommandBuffer.commit()
        }
    }

    func CopyDisplayTextureSync(to currentDrawable: CAMetalDrawable) {
        renderQueue.sync {
            let renderCommandBuffer = self.renderCommandQueue.makeCommandBuffer()!
            let blitEncoder = renderCommandBuffer.makeBlitCommandEncoder()!
            let copySize =
                MTLSize(width: min(displayTexture.width,
                                   currentDrawable.texture.width),
                        height: min(displayTexture.height,
                                    currentDrawable.texture.height),
                        depth: displayTexture.depth)
            blitEncoder.copy(from: displayTexture,
                             sourceSlice: 0,
                             sourceLevel: 0,
                             sourceOrigin: MTLOrigin(),
                             sourceSize: copySize,
                             to: currentDrawable.texture,
                             destinationSlice: 0,
                             destinationLevel: 0,
                             destinationOrigin: MTLOrigin())
            blitEncoder.endEncoding()
            renderCommandBuffer.present(currentDrawable)
            renderCommandBuffer.commit()
        }
    }


    // MARK: Deal with history lenses

    static let windowFrameSize = 5
    static let samplesPerFrame = 240/60
    let windowSampleSize = windowFrameSize * samplesPerFrame

    static let lensCount = 5
    static let boxesCount = 5
    static let movementsPerFrame = 1
    static let ignoreRaidus = 100
    static let maxHistory = 500

    class CandidateBox {
        var position: CGPoint
        var available: Bool

        init(_ position: CGPoint) {
            print("candidate: \(position)")
            self.position = position
            self.available = true
        }

        func match(with lens: HistoryLens) -> Bool {
            if available {
                let distance = hypot(self.position.x - lens.poiPos.x, self.position.y - lens.poiPos.y)
                if distance < CGFloat(movementsPerFrame * lens.cyclesFound) {
                    return true
                }
            }
            return false
        }

        func assigned(to lens: HistoryLens) {
            lens.cyclesFound = 0
            let poiX = lens.poiPos.x
            let poiY = lens.poiPos.y
            let distance = lens.poiPos.distance(with: position)
            let damping = CGFloat(max(1 - distance / 100, 0))
            lens.poiPos = CGPoint(x: poiX * damping + position.x * (1 - damping), y: poiY * damping + position.y * (1 - damping))
            self.available = false
        }

        func close(with candidate: CandidateBox) -> Bool {
            let distance = self.position.distance(with: candidate.position)
            if distance < CGFloat(SampleBufferProcessor.ignoreRaidus) {
                return true
            } else {
                return false
            }
        }
    }

    func updateBoundingBoxes(boundingBoxes: [Int: BoundingBox]) {
        let sortedBoxes = boundingBoxes.sorted { (arg0, arg1) -> Bool in
            let (_, value1) = arg0
            let (_, value2) = arg1
            return value1.getSize() > value2.getSize()
            }.prefix(SampleBufferProcessor.boxesCount * 2)

        let sortedCandidates = sortedBoxes.map { (arg0) -> CandidateBox in
            let (_, value) = arg0
            let poiX = CGFloat(Int(Double(value.x_start + value.x_end) / Constants.decimation / Constants.decimationCcl / 2))
            let poiY = CGFloat(Int(Double(value.y_start + value.y_end) / Constants.decimation / Constants.decimationCcl / 2))
            return CandidateBox(CGPoint(x: poiX, y: poiY))
        }

        var selectedCandidates = [CandidateBox]()

        for candidate in sortedCandidates {
            var close = false
            for selectedCandidate in selectedCandidates {
                if selectedCandidate.close(with: candidate) {
                    close = true
                    break
                }
            }
            if !close {
                selectedCandidates.append(candidate)
            }
        }

        delegate.historyLenses = delegate.historyLenses.sorted(by: { (lens0, lens1) -> Bool in
            return lens0.cyclesFound < lens1.cyclesFound
        })

        var newHistoryLenses = [HistoryLens]()

        for lens in delegate.historyLenses {
            lens.cyclesFound += 1
            var matchedCandidate: CandidateBox?
            for candidate in selectedCandidates {
                if candidate.match(with: lens) {
                    matchedCandidate = candidate
                    break
                }

            }
            if let candidate = matchedCandidate {
                candidate.assigned(to: lens)
            }
            var close = false
            for existedLens in newHistoryLenses {
                if (existedLens.poiPos.distance(with: lens.poiPos) < CGFloat(SampleBufferProcessor.ignoreRaidus)) {
                    close = true
                    break
                }
            }
            if (close || lens.cyclesFound > SampleBufferProcessor.maxHistory) {
                // if this lens is too close to another lens or haven't been updated for a long time
                let newLens = HistoryLens(windowSize: windowSampleSize, poiSize: CGSize(width: Constants.poiWidth, height: Constants.poiHeight))
                newLens.poiPos = CGPoint(x: Int.random(in: 0..<Constants.videoWidth), y: Int.random(in: 0..<Constants.videoHeight))
                newHistoryLenses.append(newLens)
            } else {
                newHistoryLenses.append(lens)
            }
        }
        delegate.historyLenses = newHistoryLenses
    }
}

protocol SampleBufferProcessorDelegate {
    var historyLenses: [HistoryLens] {
        get set
    }

    func callFpsCounter(time: Double) -> Double?
}
