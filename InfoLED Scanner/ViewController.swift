//
//  ViewController.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/16/16.
//  Copyright © 2016 yangjunrui. All rights reserved.
//

import UIKit
import AVFoundation

let PoiWidth = CGFloat(30)
let PoiHeight = CGFloat(30)

extension CIImage {
    convenience init(buffer: CMSampleBuffer) {
        self.init(CVPixelBuffer: CMSampleBufferGetImageBuffer(buffer)!)
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

    @IBOutlet weak var videoPreviewView: UIView!
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var scanningProgress: UIProgressView!
    @IBOutlet weak var poiSquareHeight: NSLayoutConstraint!
    @IBOutlet weak var poiSquareWidth: NSLayoutConstraint!
    @IBOutlet weak var poiProgressWidth: NSLayoutConstraint!
    @IBOutlet weak var fpsLabel: UILabel!
    var previewLayer:AVCaptureVideoPreviewLayer?;
    let captureSession = AVCaptureSession()
    var cameraDevice:AVCaptureDevice?;
    let ciContext = CIContext();
    lazy var imageProcessingQueue = dispatch_queue_create("me.jackieyang.processing-queue", DISPATCH_QUEUE_SERIAL);
    let fpsCounter = FpsCounter();

    override func viewDidLoad() {
        super.viewDidLoad()

        // Adjust POI square size
        poiSquareWidth.constant = PoiWidth
        poiSquareHeight.constant = PoiHeight
        poiProgressWidth.constant = PoiWidth

        // Create processing queue

        // Adjust video settings
        captureSession.sessionPreset = AVCaptureSessionPresetInputPriority
        cameraDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)!;
        do {
            let cameraDeviceInput = try AVCaptureDeviceInput.init(device: cameraDevice);
            if (captureSession.canAddInput(cameraDeviceInput)) {
                captureSession.addInput(cameraDeviceInput);
            }
        } catch _ {
            print("No camera on device!");
        }

        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)]
        dataOutput.alwaysDiscardsLateVideoFrames = false

        dataOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("videoProcessingQueue", DISPATCH_QUEUE_SERIAL))

        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
        }

        do {
            try cameraDevice!.lockForConfiguration()
            let frameDuration = CMTimeMake(1, 240);
            var cameraFormat: AVCaptureDeviceFormat?;

            for format in cameraDevice!.formats as! [AVCaptureDeviceFormat] {
                let videoDimention = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                if videoDimention.width == 1280 && videoDimention.height == 720 {
                    for range in format.videoSupportedFrameRateRanges as! [AVFrameRateRange] {
                        if CMTimeCompare(range.minFrameDuration, frameDuration) <= 0 {
                            cameraFormat = format;
                            break;
                        }
                    }
                }
            }
            cameraDevice!.activeFormat = cameraFormat
            cameraDevice!.activeVideoMaxFrameDuration = frameDuration
            cameraDevice!.activeVideoMinFrameDuration = frameDuration

            unlockCameraSettings()

            print("Select format: " + cameraFormat!.description)
            cameraDevice!.unlockForConfiguration()
        } catch _ {
            print("error in acquiring device!");
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = AVLayerVideoGravityResize;
        videoPreviewView.layer.addSublayer(previewLayer!)

        captureSession.startRunning()
    }

    override func viewDidAppear(animated: Bool) {
        previewLayer?.frame = videoPreviewView.frame
        print(videoPreviewView.frame)
    }

    func unlockCameraSettings() {
        do {
            try cameraDevice!.lockForConfiguration()
            let center = CGPointMake(0.5, 0.5)
            cameraDevice!.focusPointOfInterest = center
            cameraDevice!.focusMode = AVCaptureFocusMode.ContinuousAutoFocus
            cameraDevice!.exposurePointOfInterest = center
            cameraDevice!.exposureMode = AVCaptureExposureMode.ContinuousAutoExposure
            cameraDevice!.flashMode = AVCaptureFlashMode.Off
            cameraDevice!.whiteBalanceMode = AVCaptureWhiteBalanceMode.ContinuousAutoWhiteBalance
            cameraDevice!.unlockForConfiguration()
        } catch _ {
            print("Cannot unlock camera settings!")
        }
    }

    func lockCameraSettings() {
        do {
            try cameraDevice!.lockForConfiguration()
            cameraDevice!.focusMode = AVCaptureFocusMode.Locked
            cameraDevice!.exposureMode = AVCaptureExposureMode.Locked
            cameraDevice!.flashMode = AVCaptureFlashMode.Off
            cameraDevice!.whiteBalanceMode = AVCaptureWhiteBalanceMode.Locked
//            cameraDevice!.setFocusModeLockedWithLensPosition(0.0, completionHandler: nil)
            cameraDevice!.unlockForConfiguration()
        } catch _ {
            print("Cannot lock camera settings!")
        }
    }

    var cycleCount = 0
    var processCount = 0
    static let cycleLimit = 360
    static let windowFrameSize = 5
    static let samplesPerFrame = 240/60
    let windowSampleSize = windowFrameSize * samplesPerFrame
    var scanning = false
    var history = [(Int, Int, Int)]()

    @IBAction func startScanning(sender: AnyObject) {
        scanButton.enabled = false
        lockCameraSettings()
        cycleCount = 0
        processCount = 0
        history = []
        print("=====START SCANNING=====")
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(100) * Int64(NSEC_PER_MSEC)), dispatch_get_main_queue(), {
//            dispatch_suspend(self.imageProcessingQueue)
            self.scanning = true
        })
    }

    func endScanning(dataOutput: AVCaptureOutput) {
        print("===== END SCANNING =====")
        scanning = false;
        unlockCameraSettings()
        scanButton.enabled = true
        scanningProgress.progress = 0.0
//        dispatch_resume(self.imageProcessingQueue)
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        self.fpsCounter.call()
        dispatch_async(dispatch_get_main_queue()) {
            self.fpsLabel.text = "\(self.fpsCounter.getFps())";
            if self.scanning {
                self.scanningProgress.progress = Float(self.cycleCount) / Float(ViewController.cycleLimit)
            }
        }
        if self.scanning {
            dispatch_async(imageProcessingQueue) {
                let image = CIImage(buffer: sampleBuffer)
                let imageWidth = image.extent.size.width
                let imageHeight = image.extent.size.height
                let poiHeightSize = Int(PoiHeight)
                let poiWidthSize = Int(PoiWidth)
                let poiOriginX = imageWidth / 2 - PoiWidth / 2
                let poiOriginY = imageHeight / 2 - PoiHeight / 2
                let byteCount = poiHeightSize * poiWidthSize * 4

                let bitmap = calloc(byteCount, sizeof(UInt8))

                self.ciContext.render(image,
                                      toBitmap: bitmap,
                                      rowBytes: poiWidthSize*4,
                                      bounds: CGRect(x: poiOriginX, y: poiOriginY, width: PoiWidth, height: PoiHeight),
                                      format: kCIFormatRGBA8,
                                      colorSpace: CGColorSpaceCreateDeviceRGB())

                let rgba = UnsafeBufferPointer<UInt8>(
                    start: UnsafePointer<UInt8>(bitmap),
                    count: byteCount)

                var red = 0, green = 0, blue = 0;

                for i in 0...byteCount / 4 - 1 {
                    red   += Int(rgba[i << 2 + 0])
                    green += Int(rgba[i << 2 + 1])
                    blue  += Int(rgba[i << 2 + 2])
                }
//                NSLog("\(red)\t\(green)\t\(blue)")
                self.history += [(red, green, blue)]
                self.processCount += 1
                if self.processCount == ViewController.cycleLimit {
                    self.processHistory(self.history)
                }
            }
            self.cycleCount += 1;
            if self.cycleCount == ViewController.cycleLimit {
                self.endScanning(captureOutput)
            }
        }
    }

    func processHistory(history: [(Int, Int, Int)]) {

        func stdDev(array: [Int]) -> Double {
            let length = array.count
            var average = array.reduce(0, combine: +)
            average /= length
            let sumOfSquareDiff = array.map {
                pow(Double($0 - average), 2.0)
                }.reduce(0, combine: +)
            return sumOfSquareDiff / Double(length)
        }

        if (history.count > 2 * windowSampleSize) {
            // Use adaptive threshold to process history captured
            var adaptiveHistory = [(Int, Int, Int)]()
            for i in windowSampleSize ... (history.count - windowSampleSize - 1) {
                var average = (0, 0, 0)
                for entry in history[(i - windowSampleSize)...(i + windowSampleSize)] {
                    average = average + entry
                }
                average = average / (2 * windowSampleSize + 1)
                adaptiveHistory += [history[i] - average]
            }

            // Map adaptiveHistory to adaptiveGrayHistory
            let adaptiveGrayHistory = adaptiveHistory.map({ (r,g,b) in
                return r + g + b;
            })

            print(adaptiveGrayHistory)

            // Reduce adaptiveGrayHistory to signal level and duration
            var lastLevel = 0;
            var duration = 0;
            var levelDuration = [(Int, Int)]()

            for level in adaptiveGrayHistory {
                switch (lastLevel, level) {
                case (let x, let y) where x < 0 && y <= 0:
                    duration = duration + 1
                case (let x, let y) where x < 0 && y > 0:
                    levelDuration += [(lastLevel, duration)]
                    lastLevel = 1
                    duration = 1
                case (let x, let y) where x > 0 && y > 0:
                    duration = duration + 1
                case (let x, let y) where x > 0 && y <= 0:
                    levelDuration += [(lastLevel, duration)]
                    lastLevel = -1
                    duration = 1
                case (0, let y) where y > 0:
                    lastLevel = 1
                    duration = 1
                case (0, let y) where y <= 0:
                    lastLevel = -1
                    duration = 1
                default: break
                }
            }
            levelDuration += [(lastLevel, duration)]

            print(levelDuration)

            //Convert level Duration to actual history
            var genaratedHistory = [Int]()
            for (level, duration) in levelDuration {
                if level == -1 {
                    switch duration {
                    case 1...4:
                        genaratedHistory += [0]
                    case 5...8:
                        genaratedHistory += [0, 0]
                    case 9...12:
                        genaratedHistory += [0, 0, 0]
                    default:
                        print("This seems strange?")
                    }
                } else if level == 1 {
                    switch duration {
                    case 1...5:
                        genaratedHistory += [1]
                    case 6...9:
                        genaratedHistory += [1, 1]
                    case 10...13:
                        genaratedHistory += [1, 1, 1]
                    default:
                        print("This seems strange?")
                    }
                } else {
                    assert(false)
                }
            }
            print(genaratedHistory)
            
            dispatch_async(dispatch_get_main_queue()) {
                let alert = UIAlertController(title: "Scan Result", message: "\(genaratedHistory)", preferredStyle: UIAlertControllerStyle.Alert)
                let action = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil)
                alert.addAction(action)
                self.presentViewController(alert, animated: true, completion: {})
            }
        } else {
            print("History is too short or window size is too long!")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

