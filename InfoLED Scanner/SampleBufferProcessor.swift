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

    fileprivate lazy var captureTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(Constants.videoWidth) * Constants.decimation), height: Int(Double(Constants.videoHeight) * Constants.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var linearTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(Constants.videoWidth) * Constants.decimation), height: Int(Double(Constants.videoHeight) * Constants.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var lensTextures : [MTLTexture] = (0..<SampleBufferProcessor.windowSampleSize).map {_ in
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: Int(Double(Constants.videoWidth) * Constants.decimation * Constants.decimationLens), height: Int(Double(Constants.videoHeight) * Constants.decimation * Constants.decimationLens), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        var emptyFloat = [Float](repeating: 0, count: newTexture.width * newTexture.height * 4)
        newTexture.replace(region: MTLRegionMake2D(0, 0, newTexture.width, newTexture.height), mipmapLevel: 0, withBytes: &emptyFloat, bytesPerRow: newTexture.width * 4 * 4)
        return newTexture
    }

    fileprivate lazy var averageLensTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: Int(Double(Constants.videoWidth) * Constants.decimation * Constants.decimationLens), height: Int(Double(Constants.videoHeight) * Constants.decimation * Constants.decimationLens), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var tempLensTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: Int(Double(Constants.videoWidth) * Constants.decimation * Constants.decimationLens), height: Int(Double(Constants.videoHeight) * Constants.decimation * Constants.decimationLens), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var emptyLensTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: Int(Double(Constants.videoWidth) * Constants.decimation * Constants.decimationLens), height: Int(Double(Constants.videoHeight) * Constants.decimation * Constants.decimationLens), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        var emptyFloat = [Float](repeating: 0, count: newTexture.width * newTexture.height * 4)
        newTexture.replace(region: MTLRegionMake2D(0, 0, newTexture.width, newTexture.height), mipmapLevel: 0, withBytes: &emptyFloat, bytesPerRow: newTexture.width * 4 * 4)
        return newTexture
    }()

    fileprivate lazy var oldLinearTexture : MTLTexture = {
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
    var linearKernel: MPSImageConversion!
    var diffKernel: ILSImageDiff!
    var thresholdKernel: MPSImageThresholdBinary!
    var erodeKernel: MPSImageAreaMin!
    var dilateKernel: MPSImageAreaMax!
    var resize2Kernel: MPSImageLanczosScale!
    var brightKernel: MPSImageConvolution!
    var addKernel: MPSImageAdd!
    var subtractKernel: MPSImageSubtract!

    var delegate: SampleBufferProcessorDelegate

    var eventLogger: EventLogger?

    var currentLensIndex = 0

    var currentFrameId = 0;

    func createHistoryLens() -> HistoryLens {
        return HistoryLens(
            windowSize: SampleBufferProcessor.windowSampleSize,
            poiSize: CGSize(width: Constants.poiWidth, height: Constants.poiHeight),
            eventLogger: eventLogger
        )
    }

    init(delegate: SampleBufferProcessorDelegate, eventLogger: EventLogger? = nil) {
        self.eventLogger = eventLogger
        self.delegate = delegate
        self.delegate.historyLenses = (0..<SampleBufferProcessor.lensCount).map({ (_) in
            return createHistoryLens()
        })

        // Build MPS kernels
        buildKernels()
    }

    func buildKernels() {
        resizeKernel = MPSImageLanczosScale(device: self.metalDevice)
        let conversionInfo = CGColorConversionInfo(src: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                   dst: CGColorSpace(name: CGColorSpace.linearSRGB)!)

        linearKernel = MPSImageConversion(device: self.metalDevice,
                                          srcAlpha: .alphaIsOne,
                                          destAlpha: .alphaIsOne,
                                          backgroundColor: nil,
                                          conversionInfo: conversionInfo)
        diffKernel = ILSImageDiff(device: self.metalDevice)
        let colorTransform: [Float] = [1.0, 1.0, 1.0]
        withUnsafePointer(to: colorTransform) { (colorTransformRef) in
            thresholdKernel = MPSImageThresholdBinary(device: self.metalDevice, thresholdValue: 0.1, maximumValue: 1.0, linearGrayColorTransform: colorTransform)
        }
        erodeKernel = MPSImageAreaMin(device: metalDevice, kernelWidth: 3, kernelHeight: 3)
        dilateKernel = MPSImageAreaMax(device: metalDevice, kernelWidth: 9, kernelHeight: 9)
        resize2Kernel = MPSImageLanczosScale(device: self.metalDevice)

        var brightValue: [Float] = [16.0]
        brightKernel = MPSImageConvolution(device: metalDevice, kernelWidth: 1, kernelHeight: 1, weights: &brightValue)

        addKernel = MPSImageAdd(device: metalDevice)
        subtractKernel = MPSImageSubtract(device: metalDevice)
    }

    func processSampleBufferAsync(sampleBuffer: CMSampleBuffer) {
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let frameDuration = self.delegate.callFpsCounter(time: presentationTime.seconds)

        captureQueue.async {
            self.processSampleBufferOnCaptureQueue(sampleBuffer: sampleBuffer, frameDuration: frameDuration, async: true)
        }
    }

    func processSampleBufferSync(sampleBuffer: CMSampleBuffer) {
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let frameDuration = self.delegate.callFpsCounter(time: presentationTime.seconds)

        captureQueue.sync {
            self.processSampleBufferOnCaptureQueue(sampleBuffer: sampleBuffer, frameDuration: frameDuration, async: false)
        }
    }

    func processSampleBufferOnCaptureQueue(sampleBuffer:CMSampleBuffer, frameDuration: Double?, async: Bool) {
        swap(&self.linearTexture, &self.oldLinearTexture)

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

        self.linearKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.captureTexture, destinationTexture: self.linearTexture)

        var lensTransform = MPSScaleTransform(scaleX: Constants.decimationLens, scaleY: Constants.decimationLens, translateX: 0, translateY: 0)

        withUnsafePointer(to: &lensTransform, { (lensTransformPtr) in
            self.resizeKernel.scaleTransform = lensTransformPtr
            self.resizeKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.linearTexture, destinationTexture: self.lensTextures[currentLensIndex])
        })

        try! self.diffKernel.encode(commandBuffer: captureCommandBuffer, sourceTextureLhs: self.oldLinearTexture, sourceTextureRhs: self.linearTexture, destinationTexture: self.diffTexture)

        self.thresholdKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.diffTexture, destinationTexture: self.thresholdTexture)

//        self.erodeKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.thresholdTexture, destinationTexture: self.erodeTexture)
//
        self.dilateKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.thresholdTexture, destinationTexture: self.dilateTexture)

        self.brightKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.captureTexture, destinationTexture: self.brightCaptureTexture)

        var transform2 = MPSScaleTransform(scaleX: Constants.decimationCcl, scaleY: Constants.decimationCcl, translateX: 0, translateY: 0)
        withUnsafePointer(to: &transform2, { (transformPtr) in
            self.resize2Kernel.scaleTransform = transformPtr
            self.resize2Kernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.dilateTexture, destinationTexture: self.cclTexture)
        })

        self.copyTexture(buffer: captureCommandBuffer, fromTexture: self.emptyLensTexture, toTexture: self.averageLensTexture)

        let activeLensTextureIndex = (((currentLensIndex - SampleBufferProcessor.halfWindowSize) % SampleBufferProcessor.windowSampleSize) + SampleBufferProcessor.windowSampleSize) % SampleBufferProcessor.windowSampleSize
        let activeLensTexture = self.lensTextures[activeLensTextureIndex]
        for i in 0..<SampleBufferProcessor.windowSampleSize {
            if i != activeLensTextureIndex {
                let currentLensTexture = self.lensTextures[i];
                self.addKernel.encode(
                    commandBuffer: captureCommandBuffer,
                    primaryTexture: self.averageLensTexture,
                    secondaryTexture: activeLensTexture,
                    destinationTexture: tempLensTexture
                ) // tempLensTexture = self.averageLensTexture + activeLensTexture
                self.subtractKernel.encode(
                    commandBuffer: captureCommandBuffer,
                    primaryTexture: tempLensTexture,
                    secondaryTexture: currentLensTexture,
                    destinationTexture: self.averageLensTexture
                ) // self.averageLensTexture = tempLensTexture - currentLensTexture
            }
        }

        let localLensTexture = { () -> MTLTexture in
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: Int(Double(Constants.videoWidth) * Constants.decimation * Constants.decimationLens), height: Int(Double(Constants.videoHeight) * Constants.decimation * Constants.decimationLens), mipmapped: false)
            textureDescriptor.usage = [.shaderWrite, .shaderRead]
            let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
            return newTexture
        }()

        self.copyTexture(buffer: captureCommandBuffer, fromTexture: self.averageLensTexture, toTexture: localLensTexture)

        let currentLensTexture = self.lensTextures[currentLensIndex];
        #if os(OSX)
        self.flushTexture(buffer: captureCommandBuffer, resource: self.cclTexture)
        self.flushTexture(buffer: captureCommandBuffer, resource: localLensTexture)
        #endif

        weak var weakSelfOptional = self
        func handleComptetedbuffer(buffer: MTLCommandBuffer) {
            guard let weakSelf = weakSelfOptional else {
                return
            }
            currentFrameId += 1
            let bytesPerRow = weakSelf.cclTexture.width * 4
            let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                   size: MTLSize(width: weakSelf.cclTexture.width,
                                                 height: weakSelf.cclTexture.height,
                                                 depth: weakSelf.cclTexture.depth))
            weakSelf.cclTexture.getBytes(&weakSelf.processedImage,
                                          bytesPerRow: bytesPerRow,
                                          from: region,
                                          mipmapLevel: 0)
            let labelImage = CcImage(array: &weakSelf.processedImage,
                                     width: weakSelf.cclTexture.width,
                                     height: weakSelf.cclTexture.height,
                                     bytesPerPixel: 4);
            let labelResult = CcLabel.labelImageFast(data: labelImage,
                                                     calculateBoundingBoxes: true)

            if let boundingBoxes = labelResult.boundingBoxes {
                weakSelf.updateBoundingBoxes(boundingBoxes: boundingBoxes)
            }

            weakSelf.renderQueue.async {
//                weakSelf.displayTexture = weakSelf.brightCaptureTexture
                weakSelf.displayTexture = weakSelf.dilateTexture
            }

            for lens in weakSelf.delegate.historyLenses {
                if (lens.cyclesFound < SampleBufferProcessor.maxHistory) {
                    lens.processFrame(lensTexture: localLensTexture, imageProcessingQueue: self.computeQueue, frameDuration: frameDuration, frameId: currentFrameId)
                }
            }
        }

        if async {
            captureCommandBuffer.addCompletedHandler(handleComptetedbuffer)
        }
        captureCommandBuffer.commit()
        if !async {
            captureCommandBuffer.waitUntilCompleted()
            handleComptetedbuffer(buffer: captureCommandBuffer)
        }
        currentLensIndex = (currentLensIndex + 1) % SampleBufferProcessor.windowSampleSize
    }

    func copyTexture(buffer: MTLCommandBuffer, fromTexture: MTLTexture, toTexture: MTLTexture) {
        let blitEncoder = buffer.makeBlitCommandEncoder()!
        let copySize =
            MTLSize(width: min(fromTexture.width, toTexture.width),
                    height: min(fromTexture.height, toTexture.height),
                    depth: min(fromTexture.depth, toTexture.depth))
        blitEncoder.copy(from: fromTexture,
                         sourceSlice: 0,
                         sourceLevel: 0,
                         sourceOrigin: MTLOrigin(),
                         sourceSize: copySize,
                         to: toTexture,
                         destinationSlice: 0,
                         destinationLevel: 0,
                         destinationOrigin: MTLOrigin())
        blitEncoder.endEncoding()
    }

#if os(OSX)
    func flushTexture(buffer: MTLCommandBuffer, resource: MTLResource) {
        let blitEncoder = buffer.makeBlitCommandEncoder()!
        blitEncoder.synchronize(resource: resource)
        blitEncoder.endEncoding()
    }
#endif

    func copyDisplayTextureSync(to currentDrawable: CAMetalDrawable) {
        renderQueue.sync {
            let renderCommandBuffer = self.renderCommandQueue.makeCommandBuffer()!
            copyTexture(buffer: renderCommandBuffer, fromTexture: displayTexture, toTexture: currentDrawable.texture)
            renderCommandBuffer.present(currentDrawable)
            renderCommandBuffer.commit()
        }
    }


    // MARK: Deal with history lenses

    static let windowFrameSize = 5
    static let samplesPerFrame = 240/120
    static let halfWindowSize = (windowFrameSize * samplesPerFrame) / 2
    static let windowSampleSize = 2 * halfWindowSize + 1

    static let lensCount = 5
    static let boxesCount = 5
    static let movementsPerFrame = 1
    static let ignoreRaidus = 100
    static let maxHistory = 500

    class CandidateBox {
        var position: CGPoint
        var available: Bool

        init(_ position: CGPoint) {
//            print("candidate: \(position)")
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
            lens.poiPos = position
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
                eventLogger?.recordMessage(dict: ["lensPos": lens.poiPos])
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
                let newLens = createHistoryLens()
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
