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

    var previewLayer:AVCaptureVideoPreviewLayer?
    let captureSession = AVCaptureSession()
    var cameraDevice:AVCaptureDevice?
    let ciContext = CIContext()
    let fpsCounter = FpsCounter()
    var bufferProcessor: SampleBufferProcessor!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Update UI elements
        lensScene = lensView.scene as? LedLens

        // Adjust video settings
        captureSession.sessionPreset = AVCaptureSession.Preset(rawValue: convertFromAVCaptureSessionPreset(AVCaptureSession.Preset.inputPriority))
        cameraDevice = AVCaptureDevice.default(.builtInTelephotoCamera, for: AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.video)), position: .back)!;
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

            cameraDevice!.setExposureTargetBias(-4.5, completionHandler: nil)

            unlockCameraSettings()

            print("Select format: " + cameraFormat!.description)
            cameraDevice!.unlockForConfiguration()
        } catch _ {
            print("error in acquiring device!");
        }

        bufferProcessor = SampleBufferProcessor(delegate: self)

        metalPreviewLayer.delegate = self
        metalPreviewLayer.device = self.bufferProcessor.metalDevice
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

    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        bufferProcessor.processSampleBufferAsync(sampleBuffer: sampleBuffer)
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
            self.bufferProcessor.copyDisplayTextureSync(to: currentDrawable)
        }
    }
}

extension ViewController : SampleBufferProcessorDelegate {
    var historyLenses: [HistoryLens] {
        get {
            return lensScene.lenses as! [HistoryLens]
        }
        set(newLenses) {
            lensScene.lenses = newLenses
        }
    }

    func callFpsCounter(time: Double) -> Double? {
        return fpsCounter.call(time: time)
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
