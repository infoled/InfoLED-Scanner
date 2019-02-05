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

let PoiWidth = CGFloat(50)
let PoiHeight = CGFloat(50)

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

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let videoWidth = 1280
    private let videoHeight = 720
    private let decimation = 0.25
    private let decimationCcl = 0.25

    private lazy var poiX: CGFloat = CGFloat(videoWidth) / 2;
    private lazy var poiY: CGFloat = CGFloat(videoHeight) / 2;

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
    let captureQueue = DispatchQueue(label: "me.jackieyang.infoled.captureQueue", qos: .userInitiated, attributes: .concurrent)
    let renderQueue = DispatchQueue(label: "me.jackieyang.infoled.renderQueue")

    fileprivate lazy var captureTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(self.videoWidth) * self.decimation), height: Int(Double(self.videoHeight) * self.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var oldCaptureTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(self.videoWidth) * self.decimation), height: Int(Double(self.videoHeight) * self.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var brightCaptureTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(self.videoWidth) * self.decimation), height: Int(Double(self.videoHeight) * self.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var diffTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(self.videoWidth) * self.decimation), height: Int(Double(self.videoHeight) * self.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var thresholdTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(self.videoWidth) * self.decimation), height: Int(Double(self.videoHeight) * self.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var erodeTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(self.videoWidth) * self.decimation), height: Int(Double(self.videoHeight) * self.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var dilateTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(self.videoWidth) * self.decimation), height: Int(Double(self.videoHeight) * self.decimation), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var cclTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(self.videoWidth) * self.decimation * self.decimationCcl), height: Int(Double(self.videoHeight) * self.decimation * self.decimationCcl), mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    fileprivate lazy var displayTexture : MTLTexture = {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(Double(self.videoWidth) * self.decimation), height: Int(Double(self.videoHeight) * self.decimation), mipmapped: false)
        textureDescriptor.usage = MTLTextureUsage.shaderWrite
        let newTexture = self.metalDevice.makeTexture(descriptor: textureDescriptor)!
        return newTexture
    }()

    lazy var processedImage = [UInt8](repeating: 0, count: Int(Double(self.videoWidth * self.videoHeight * 4) * self.decimation * self.decimation * self.decimationCcl * self.decimationCcl))

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

    func updateUiElements() {
        // Adjust POI square size
        lensScene.setLensWidth(width: PoiWidth / UIScreen.main.scale)
        let x = poiX / UIScreen.main.scale
        let y = poiY / UIScreen.main.scale
        lensScene.lenses = [Lens(position: CGPoint(x: x, y: y), text: "")]
        poiSquareWidth.constant = PoiWidth / UIScreen.main.scale * CGFloat(decimation)
        poiSquareHeight.constant = PoiHeight / UIScreen.main.scale * CGFloat(decimation)
        poiSquareX.constant = poiX / UIScreen.main.scale * CGFloat(decimation)
        poiSquareY.constant = poiY / UIScreen.main.scale * CGFloat(decimation)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Build MPS kernels
        buildKernels()

        // Update UI elements
        lensScene = lensView.scene as? LedLens
        updateUiElements()

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
                if videoDimention.width == Int32(videoWidth) &&
                    videoDimention.height == Int32(videoHeight) {
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

        videoPreviewLayerWidth.constant = CGFloat(videoWidth) / UIScreen.main.scale * CGFloat(decimation)
        videoPreviewLayerHeight.constant = CGFloat(videoHeight) / UIScreen.main.scale * CGFloat(decimation)

        let videoViewScaleFactor = CGFloat(videoWidth) / UIScreen.main.bounds.height / CGFloat(decimation)

        videoPreviewView.transform =
            CGAffineTransform.init(rotationAngle: .pi / 2)
                .scaledBy(x: videoViewScaleFactor, y: videoViewScaleFactor)

        lensViewWidth.constant = CGFloat(videoWidth) / UIScreen.main.scale
        lensViewHeight.constant = CGFloat(videoHeight) / UIScreen.main.scale

        let lensViewScaleFactor = CGFloat(videoWidth) / UIScreen.main.bounds.height

        lensView.transform =
            CGAffineTransform.init(rotationAngle: .pi / 2)
                .scaledBy(x: lensViewScaleFactor, y: lensViewScaleFactor)

//        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//        previewLayer?.videoGravity = AVLayerVideoGravityResize;
//        videoPreviewView.layer.addSublayer(previewLayer!)

        captureSession.startRunning()
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

    var cycleCount = 0
    var processCount = 0
    static let cycleLimit = 240
    static let windowFrameSize = 5
    static let samplesPerFrame = 240/60
    let windowSampleSize = windowFrameSize * samplesPerFrame
    var scanning = false
    var historyProcessor : HistoryProcessor?

    @IBAction func startScanning(_ sender: AnyObject) {
        scanButton.isEnabled = false
        lockCameraSettings()
        cycleCount = 0
        processCount = 0
        historyProcessor = HistoryProcessor(windowSampleSize: windowSampleSize)
        print("=====START SCANNING=====")
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(100) * Int64(NSEC_PER_MSEC)) / Double(NSEC_PER_SEC), execute: {
//            self.imageProcessingQueue.suspend()
            self.scanning = true
        })
    }

    func endScanning(_ dataOutput: AVCaptureOutput) {
        print("===== END SCANNING =====")
        scanning = false;
        unlockCameraSettings()
        scanButton.isEnabled = true
        scanningProgress.progress = 0.0
//        self.imageProcessingQueue.resume()
    }

    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let currentProcessCount = processCount
        os_log("catpure id: %d", currentProcessCount)
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let frameDuration = self.fpsCounter.call(time: presentationTime.seconds)

        var samplebufferPtr = sampleBuffer

//        withUnsafePointer(to: &samplebufferPtr) { (ptr) -> Void in
//            print(ptr)
//        }
//        print("Start: " + String(CACurrentMediaTime()))

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
            var transform = MPSScaleTransform(scaleX: self.decimation, scaleY: self.decimation, translateX: 0, translateY: 0)

            withUnsafePointer(to: &transform, { (transformPtr) in
                self.resizeKernel.scaleTransform = transformPtr
                self.resizeKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: imageTexture, destinationTexture: self.captureTexture)
            })

            try! self.diffKernel.encode(commandBuffer: captureCommandBuffer, sourceTextureLhs: self.oldCaptureTexture, sourceTextureRhs: self.captureTexture, destinationTexture: self.diffTexture)

            self.thresholdKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.diffTexture, destinationTexture: self.thresholdTexture)

            self.erodeKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.thresholdTexture, destinationTexture: self.erodeTexture)

            self.dilateKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.erodeTexture, destinationTexture: self.dilateTexture)

            self.brightKernel.encode(commandBuffer: captureCommandBuffer, sourceTexture: self.captureTexture, destinationTexture: self.brightCaptureTexture)

            var transform2 = MPSScaleTransform(scaleX: self.decimationCcl, scaleY: self.decimationCcl, translateX: 0, translateY: 0)
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

                let largestBox = labelResult.boundingBoxes?.reduce(nil
                    , { (result: BoundingBox?, entry) -> BoundingBox? in
                        if let result = result {
                            if (result.getSize() >= entry.value.getSize()) {
                                return result
                            }
                        }
                        return entry.value
                })
                if let largestBox = largestBox {
                    self.poiX = 0.05 * CGFloat(Int(Double(largestBox.x_start + largestBox.x_end) / self.decimation / self.decimationCcl / 2)) + 0.95 * self.poiX
                    self.poiY = 0.05 * CGFloat(Int(Double(largestBox.y_start + largestBox.y_end) / self.decimation / self.decimationCcl / 2)) + 0.95 * self.poiY
                }

                self.renderQueue.async {
                    os_log("render id: %d", currentProcessCount)
                    //            print("Complete: " + String(CACurrentMediaTime()))
                    self.displayTexture = self.brightCaptureTexture
                }
            })
            captureCommandBuffer.commit()
        }
//        captureQueue.async {
//            print("Issue: " + String(CACurrentMediaTime()))
//            let captureCommandBuffer = self.captureCommandQueue.makeCommandBuffer()
//            let blitEncoder = captureCommandBuffer.makeBlitCommandEncoder()
//            let copySize =
//                MTLSize(width: imageTexture.width,
//                        height: imageTexture.height,
//                        depth: imageTexture.depth)
//            blitEncoder.copy(from: imageTexture,
//                             sourceSlice: 0,
//                             sourceLevel: 0,
//                             sourceOrigin: MTLOrigin(),
//                             sourceSize: copySize,
//                             to: self.displayTexture,
//                             destinationSlice: 0,
//                             destinationLevel: 0,
//                             destinationOrigin: MTLOrigin())
//            blitEncoder.endEncoding()
//            captureCommandBuffer.addCompletedHandler() { (_) in
//                print("Complete: " + String(CACurrentMediaTime()))
//                CVPixelBufferUnlockBaseAddress(localBuffer, CVPixelBufferLockFlags.readOnly)
//            }
//            captureCommandBuffer.commit()
////            self.renderQueue.async {
////                self.displayTexture = imageTexture
////            }
//        }

        if self.scanning {
            let localBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
            CVPixelBufferLockBaseAddress(localBuffer, CVPixelBufferLockFlags.readOnly)
            let imageWidth  = CVPixelBufferGetWidth(localBuffer)
            let imageHeight = CVPixelBufferGetHeight(localBuffer)
            let poiHeight = Int(PoiHeight)
            let poiWidth = Int(PoiWidth)

            let baseAddr = CVPixelBufferGetBaseAddress(localBuffer)
            let byteCount = CVPixelBufferGetDataSize(localBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(localBuffer)
            let bytesPerPixel = bytesPerRow / imageWidth

            let startx = Int(poiX) - poiWidth / 2
            let endx = Int(poiX) + poiWidth / 2
            let starty = Int(poiY) - poiHeight / 2
            let endy = Int(poiY) + poiHeight / 2

            var red = 0, green = 0, blue = 0;

            let rgba = UnsafeBufferPointer<UInt8>(
                start: baseAddr?.assumingMemoryBound(to: UInt8.self),
                count: byteCount)

            for i in startx...endx{
                for j in starty...endy {
                    let offset = j * bytesPerRow + i * bytesPerPixel
                    red   += Int(rgba[offset + 0])
                    green += Int(rgba[offset + 1])
                    blue  += Int(rgba[offset + 2])
                }
            }

            CVPixelBufferUnlockBaseAddress(localBuffer, CVPixelBufferLockFlags.readOnly)

            NSLog("\(red)\t\(green)\t\(blue)")
            imageProcessingQueue.async {
                if (self.historyProcessor!.processNewPixel(pixel: (red, green, blue), frameDuration: frameDuration) || self.processCount == 2000) {
                    DispatchQueue.main.async {
                        var notification: String?;
                        if (self.historyProcessor?.verifiedPackets.count != 0) {
                            notification = "\(self.historyProcessor!.verifiedPackets[0])"
                        } else {
                            notification = "tag not found"
                        }
                        let alert = UIAlertController(title: "Scan Result", message: notification, preferredStyle: UIAlertController.Style.alert)
                        let action = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil)
                        alert.addAction(action)
                        self.present(alert, animated: true, completion: {})
                        self.endScanning(captureOutput)
                    }
                }
                self.processCount += 1
            }
            self.cycleCount += 1;
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
        updateUiElements()
        DispatchQueue.main.async {
            self.fpsLabel.text = "\(self.fpsCounter.getFps())";
            if self.scanning {
                self.scanningProgress.progress = Float(self.cycleCount) / Float(ViewController.cycleLimit)
            }
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
