//
//  ViewController.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/16/16.
//  Copyright © 2016 yangjunrui. All rights reserved.
//

import os
import UIKit
import AVFoundation
import Metal
import MetalKit
import MetalPerformanceShaders
import SpriteKit

extension CIImage {
    convenience init(buffer: CMSampleBuffer) {
        self.init(cvPixelBuffer: CMSampleBufferGetImageBuffer(buffer)!)
    }
}

extension CVPixelBuffer {
    func deepcopy() -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let format = CVPixelBufferGetPixelFormatType(self)
        var pixelBufferCopyOptional:CVPixelBuffer?
        let options = [(kCVPixelBufferMetalCompatibilityKey as AnyHashable): true]
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, format, options as NSDictionary, &pixelBufferCopyOptional)
        if let pixelBufferCopy = pixelBufferCopyOptional {
            CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
            CVPixelBufferLockBaseAddress(pixelBufferCopy, CVPixelBufferLockFlags(rawValue: 0))
            let baseAddress = CVPixelBufferGetBaseAddress(self)
            let dataSize = CVPixelBufferGetDataSize(self)
            let target = CVPixelBufferGetBaseAddress(pixelBufferCopy)
            memcpy(target, baseAddress, dataSize)
            CVPixelBufferUnlockBaseAddress(pixelBufferCopy, CVPixelBufferLockFlags(rawValue: 0))
            CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
        }
        return pixelBufferCopyOptional!
    }
}

func + (tuple1: (Int, Int, Int), tuple2: (Int, Int, Int)) -> (Int, Int, Int) {
    return (tuple1.0 + tuple2.0, tuple1.1 + tuple2.1, tuple1.2 + tuple2.2)
}

func - (tuple1: (Int, Int, Int), tuple2: (Int, Int, Int)) -> (Int, Int, Int) {
    return (tuple1.0 - tuple2.0, tuple1.1 - tuple2.1, tuple1.2 - tuple2.2)
}

func / (tuple: (Int, Int, Int), val: Int) -> (Int, Int, Int) {
    return (tuple.0 / val, tuple.1 / val, tuple.2 / val)
}

extension CGPoint {
    func distance(with point: CGPoint) -> CGFloat {
        return hypot(self.x - point.x, self.y - point.y)
    }
}

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var videoPreviewView: UIView!
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var scanningProgress: UIProgressView!
    @IBOutlet weak var poiSquareHeight: NSLayoutConstraint!
    @IBOutlet weak var poiSquareWidth: NSLayoutConstraint!
    @IBOutlet weak var poiSquareY: NSLayoutConstraint!
    @IBOutlet weak var poiSquareX: NSLayoutConstraint!
    @IBOutlet weak var fpsLabel: UILabel!
    @IBOutlet weak var metalPreviewLayer: MTKView!
    @IBOutlet weak var videoPreviewLayerHeight: NSLayoutConstraint!
    @IBOutlet weak var videoPreviewLayerWidth: NSLayoutConstraint!
    @IBOutlet weak var lensView: SKView!
    @IBOutlet weak var lensViewHeight: NSLayoutConstraint!
    @IBOutlet weak var lensViewWidth: NSLayoutConstraint!


    var lensScene: LedLens!

    var previewLayer:AVCaptureVideoPreviewLayer?;
    let captureSession = AVCaptureSession()
    var cameraDevice:AVCaptureDevice?;
    let ciContext = CIContext();
    lazy var imageProcessingQueue : DispatchQueue = DispatchQueue(label: "me.jackieyang.processing-queue");
    let fpsCounter = FpsCounter();

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

    override func viewDidLoad() {
        super.viewDidLoad()

        // Build MPS kernels
        buildKernels()

        // Update UI elements
        lensScene = lensView.scene as? LedLens

        // Create processing queue

        // Adjust video settings
        captureSession.sessionPreset = AVCaptureSession.Preset(rawValue: convertFromAVCaptureSessionPreset(AVCaptureSession.Preset.inputPriority))
        cameraDevice = AVCaptureDevice.default(for: AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.video)))!;
        do {
            let cameraDeviceInput = try AVCaptureDeviceInput.init(device: cameraDevice!);
            if (captureSession.canAddInput(cameraDeviceInput)) {
                captureSession.addInput(cameraDeviceInput);
            }
        } catch _ {
            print("No camera on device!");
        }

        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as [String : Any]
        dataOutput.alwaysDiscardsLateVideoFrames = false

        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoProcessingQueue", qos: .userInitiated))

        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
        }

        do {
            try cameraDevice!.lockForConfiguration()
            let frameDuration = CMTimeMake(value: 1, timescale: 240);
            var cameraFormat: AVCaptureDevice.Format?;

            for format in cameraDevice!.formats {
                let videoDimention = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                if videoDimention.width == Int32(Constants.videoWidth) &&
                    videoDimention.height == Int32(Constants.videoHeight) {
                    for range in format.videoSupportedFrameRateRanges {
                        if CMTimeCompare(range.minFrameDuration, frameDuration) <= 0 {
                            cameraFormat = format;
                            break;
                        }
                    }
                }
            }
            cameraDevice!.activeFormat = cameraFormat!
            cameraDevice!.activeVideoMaxFrameDuration = frameDuration
            cameraDevice!.activeVideoMinFrameDuration = frameDuration

            cameraDevice!.setExposureTargetBias(-5.0, completionHandler: nil)

            unlockCameraSettings()

            print("Select format: " + cameraFormat!.description)
            cameraDevice!.unlockForConfiguration()
        } catch _ {
            print("error in acquiring device!");
        }

        metalPreviewLayer.delegate = self
        metalPreviewLayer.device = self.metalDevice
        metalPreviewLayer.colorPixelFormat = .bgra8Unorm

        videoPreviewLayerWidth.constant = CGFloat(Constants.videoWidth) / UIScreen.main.scale * CGFloat(Constants.decimation)
        videoPreviewLayerHeight.constant = CGFloat(Constants.videoHeight) / UIScreen.main.scale * CGFloat(Constants.decimation)

        let videoViewScaleFactor = CGFloat(Constants.videoWidth) / UIScreen.main.bounds.height / CGFloat(Constants.decimation)

        videoPreviewView.transform =
            CGAffineTransform.init(rotationAngle: .pi / 2)
                .scaledBy(x: videoViewScaleFactor, y: videoViewScaleFactor)

        lensViewWidth.constant = CGFloat(Constants.videoWidth) / UIScreen.main.scale
        lensViewHeight.constant = CGFloat(Constants.videoHeight) / UIScreen.main.scale

        let lensViewScaleFactor = CGFloat(Constants.videoWidth) / UIScreen.main.bounds.height

        lensView.transform =
            CGAffineTransform.init(rotationAngle: .pi / 2)
                .scaledBy(x: lensViewScaleFactor, y: lensViewScaleFactor)

//        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//        previewLayer?.videoGravity = AVLayerVideoGravityResize;
//        videoPreviewView.layer.addSublayer(previewLayer!)

        captureSession.startRunning()

        historyLenses = (0..<ViewController.lensCount).map({ (_) in
            return HistoryLens(windowSize: windowSampleSize, poiSize: CGSize(width: Constants.poiWidth, height: Constants.poiHeight))
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        previewLayer?.frame = videoPreviewView.frame
        print(videoPreviewView.frame)
    }

    func unlockCameraSettings() {
        do {
            try cameraDevice!.lockForConfiguration()
            let center = CGPoint(x: 0.5, y: 0.5)
            cameraDevice!.focusPointOfInterest = center
            cameraDevice!.focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus
            cameraDevice!.exposurePointOfInterest = center
            cameraDevice!.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
            cameraDevice!.whiteBalanceMode = AVCaptureDevice.WhiteBalanceMode.continuousAutoWhiteBalance
            cameraDevice!.unlockForConfiguration()
        } catch _ {
            print("Cannot unlock camera settings!")
        }
    }

    func lockCameraSettings() {
        do {
            try cameraDevice!.lockForConfiguration()
            cameraDevice!.focusMode = AVCaptureDevice.FocusMode.locked
            cameraDevice!.exposureMode = AVCaptureDevice.ExposureMode.locked
            cameraDevice!.whiteBalanceMode = AVCaptureDevice.WhiteBalanceMode.locked
//            cameraDevice!.setFocusModeLockedWithLensPosition(0.0, completionHandler: nil)
            cameraDevice!.unlockForConfiguration()
        } catch _ {
            print("Cannot lock camera settings!")
        }
    }

    static let windowFrameSize = 5
    static let samplesPerFrame = 240/60
    let windowSampleSize = windowFrameSize * samplesPerFrame

    var historyLenses: [HistoryLens] {
        get {
            return lensScene.lenses as! [HistoryLens]
        }
        set(newLenses) {
            lensScene.lenses = newLenses
        }
    }

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
            lens.poiPos = CGPoint(x: poiX * 0.5 + position.x * 0.5, y: poiY * 0.5 + position.y * 0.5)
            self.available = false
        }

        func close(with candidate: CandidateBox) -> Bool {
            let distance = self.position.distance(with: candidate.position)
            if distance < CGFloat(ViewController.ignoreRaidus) {
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
            }.prefix(ViewController.boxesCount * 2)

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

        historyLenses = historyLenses.sorted(by: { (lens0, lens1) -> Bool in
            return lens0.cyclesFound < lens1.cyclesFound
        })

        var newHistoryLenses = [HistoryLens]()

        for lens in historyLenses {
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
                if (existedLens.poiPos.distance(with: lens.poiPos) < CGFloat(ViewController.ignoreRaidus)) {
                    close = true
                    break
                }
            }
            if (!close) {
                newHistoryLenses.append(lens)
            } else {
                let newLens = HistoryLens(windowSize: windowSampleSize, poiSize: CGSize(width: Constants.poiWidth, height: Constants.poiHeight))
                newLens.poiPos = CGPoint(x: Int.random(in: 0..<Constants.videoWidth), y: Int.random(in: 0..<Constants.videoHeight))
                newHistoryLenses.append(newLens)
            }
        }
        historyLenses = newHistoryLenses

//        if sortedBoxes.count > 0{
//            let largestBox = sortedBoxes[0].value
//            var poiX = self.historyLenses[0].poiPos.x
//            var poiY = self.historyLenses[0].poiPos.y
//            let newPoiX = CGFloat(Int(Double(largestBox.x_start + largestBox.x_end) / Constants.decimation / Constants.decimationCcl / 2))
//            let newPoiY = CGFloat(Int(Double(largestBox.y_start + largestBox.y_end) / Constants.decimation / Constants.decimationCcl / 2))
//            print("newPoi: (\(newPoiX), \(newPoiY))")
//            poiX = 0.05 * newPoiX + 0.95 * poiX
//            poiY = 0.05 * newPoiY + 0.95 * poiY
//            self.historyLenses[0].poiPos = CGPoint(x: poiX, y: poiY)
//        }
    }

    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let frameDuration = self.fpsCounter.call(time: presentationTime.seconds)

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

                for lens in self.historyLenses {
                    lens.processFrame(lensTexture: self.lensTexture, imageProcessingQueue: self.imageProcessingQueue, frameDuration: frameDuration)
                }
            })
            captureCommandBuffer.commit()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ViewController : MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        NSLog("MTKView drawable size will change to \(size)")
    }

    func draw(in view: MTKView) {
        DispatchQueue.main.async {
            self.fpsLabel.text = "\(self.fpsCounter.getFps())";
            print("\(self.fpsCounter.getFps())")
        }
        if let currentDrawable = metalPreviewLayer.currentDrawable {
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
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVCaptureSessionPreset(_ input: AVCaptureSession.Preset) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVMediaType(_ input: AVMediaType) -> String {
	return input.rawValue
}
