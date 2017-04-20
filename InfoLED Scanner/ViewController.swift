//
//  ViewController.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/16/16.
//  Copyright © 2016 yangjunrui. All rights reserved.
//

import UIKit
import AVFoundation

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
        CVPixelBufferCreate(nil, width, height, format, nil, &pixelBufferCopyOptional)
        if let pixelBufferCopy = pixelBufferCopyOptional {
            CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
            CVPixelBufferLockBaseAddress(pixelBufferCopy, CVPixelBufferLockFlags(rawValue: 0))
            let baseAddress = CVPixelBufferGetBaseAddress(self)
            let dataSize = CVPixelBufferGetDataSize(self)
            let target = CVPixelBufferGetBaseAddress(pixelBufferCopy)
            memcpy(target, baseAddress, dataSize)
            print(dataSize)
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
    lazy var imageProcessingQueue : DispatchQueue = DispatchQueue(label: "me.jackieyang.processing-queue");
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
        cameraDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)!;
        do {
            let cameraDeviceInput = try AVCaptureDeviceInput.init(device: cameraDevice);
            if (captureSession.canAddInput(cameraDeviceInput)) {
                captureSession.addInput(cameraDeviceInput);
            }
        } catch _ {
            print("No camera on device!");
        }

        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA)]
        dataOutput.alwaysDiscardsLateVideoFrames = false

        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoProcessingQueue", attributes: []))

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

    override func viewDidAppear(_ animated: Bool) {
        previewLayer?.frame = videoPreviewView.frame
        print(videoPreviewView.frame)
    }

    func unlockCameraSettings() {
        do {
            try cameraDevice!.lockForConfiguration()
            let center = CGPoint(x: 0.5, y: 0.5)
            cameraDevice!.focusPointOfInterest = center
            cameraDevice!.focusMode = AVCaptureFocusMode.continuousAutoFocus
            cameraDevice!.exposurePointOfInterest = center
            cameraDevice!.exposureMode = AVCaptureExposureMode.continuousAutoExposure
            cameraDevice!.flashMode = AVCaptureFlashMode.off
            cameraDevice!.whiteBalanceMode = AVCaptureWhiteBalanceMode.continuousAutoWhiteBalance
            cameraDevice!.unlockForConfiguration()
        } catch _ {
            print("Cannot unlock camera settings!")
        }
    }

    func lockCameraSettings() {
        do {
            try cameraDevice!.lockForConfiguration()
            cameraDevice!.focusMode = AVCaptureFocusMode.locked
            cameraDevice!.exposureMode = AVCaptureExposureMode.locked
            cameraDevice!.flashMode = AVCaptureFlashMode.off
            cameraDevice!.whiteBalanceMode = AVCaptureWhiteBalanceMode.locked
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

    @IBAction func startScanning(_ sender: AnyObject) {
        scanButton.isEnabled = false
        lockCameraSettings()
        cycleCount = 0
        processCount = 0
        history = []
        print("=====START SCANNING=====")
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(100) * Int64(NSEC_PER_MSEC)) / Double(NSEC_PER_SEC), execute: {
            self.imageProcessingQueue.suspend()
            self.scanning = true
        })
    }

    func endScanning(_ dataOutput: AVCaptureOutput) {
        print("===== END SCANNING =====")
        scanning = false;
        unlockCameraSettings()
        scanButton.isEnabled = true
        scanningProgress.progress = 0.0
        self.imageProcessingQueue.resume()
    }

    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        self.fpsCounter.call()
        DispatchQueue.main.async {
            self.fpsLabel.text = "\(self.fpsCounter.getFps())";
            if self.scanning {
                self.scanningProgress.progress = Float(self.cycleCount) / Float(ViewController.cycleLimit)
            }
        }
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

            let startx = imageWidth / 2 - poiWidth / 2
            let endx = imageWidth / 2 + poiWidth / 2
            let starty = imageHeight / 2 - poiHeight / 2
            let endy = imageHeight / 2 + poiHeight / 2

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
                self.history += [(red, green, blue)]
                self.processCount += 1
                if self.processCount == ViewController.cycleLimit {
                    self.processHistory(self.history)
                }
            }
            self.cycleCount += 1;
            if self.cycleCount == ViewController.cycleLimit {
                DispatchQueue.main.async {
                    self.endScanning(captureOutput)
                }
            }
        }
    }

    func processHistory(_ history: [(Int, Int, Int)]) {

        print("history: \(history)")

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
            print("adaptiveGrayHistory: \(adaptiveGrayHistory)")

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

            print("levelDuration: \(levelDuration)")

            //Convert level Duration to actual history
            var genaratedHistory = [Int]()
            for (level, duration) in levelDuration {
                if level == -1 {
                    switch duration {
                    case 1...2:
                        genaratedHistory += [0]
                    case 3...4:
                        genaratedHistory += [0, 0]
                    case 5...6:
                        genaratedHistory += [0, 0, 0]
                    default:
                        print("This seems strange?")
                    }
                } else if level == 1 {
                    switch duration {
                    case 1...3:
                        genaratedHistory += [1]
                    case 3...5:
                        genaratedHistory += [1, 1]
                    case 5...7:
                        genaratedHistory += [1, 1, 1]
                    default:
                        print("This seems strange?")
                    }
                } else {
                    assert(false)
                }
            }
            print("genaratedHistory: \(genaratedHistory)")

            let preamble = [0, 0, 1, 1, 1, 0];
            let indices = Array(genaratedHistory.startIndex...genaratedHistory.endIndex - preamble.count)

            let preamblePos = indices.reduce([]) { (result, index) -> [Int] in
                let subarray = genaratedHistory[index ... (index + preamble.count - 1)]
                if (subarray == ArraySlice<Int>(preamble)) {
                    return result + [index];
                } else {
                    return result;
                }
            }

            var preambleRanges = [(Int, Int)]();
            if preamblePos.count > 1 {
                for i in 1..<preamblePos.count {
                    let start = preamblePos[i - 1] + preamble.count
                    let end = preamblePos[i] - 1
                    if start < end {
                        preambleRanges += [(preamblePos[i - 1] + preamble.count, preamblePos[i] - 1)]
                    }
                }
            }

            let filteredHistorys = preambleRanges.map({ (start, end) in
                return genaratedHistory[start ... end].enumerated().filter({ (index, element) -> Bool in
                    return index % 2 == 0
                }).map({ (_, element) in
                    element
                })
            })

            print(filteredHistorys)

            var filteredHistory: [Int]?
            for history in filteredHistorys {
                if history.count == 8 && history[history.startIndex...history.startIndex + 1] != [1, 1] {
                    filteredHistory = history;
                    break;
                }
            }


            DispatchQueue.main.async {
                var notification: String?;
                if filteredHistory?.count == 8 {
                    let statuscode = filteredHistory![filteredHistory!.startIndex...(filteredHistory!.startIndex + 1)];
                    let speedArray = filteredHistory![(filteredHistory!.startIndex + 2)...(filteredHistory!.startIndex + 7)]
                    let speed = (speedArray[speedArray.startIndex + 0] << 0)
                        + (speedArray[speedArray.startIndex + 1] << 1)
                        + (speedArray[speedArray.startIndex + 2] << 2)
                        + (speedArray[speedArray.startIndex + 3] << 3)
                        + (speedArray[speedArray.startIndex + 4] << 4)
                        + (speedArray[speedArray.startIndex + 5] << 5)
                    if statuscode == [0, 0] {
                        notification = "Everything is fine :) Speed: \(speed)Mbps"
                    } else if statuscode == [0, 1] {
                        notification = "Network port is unplugged :("
                    } else if statuscode == [1, 0] {
                        notification = "No charge left in your account, please recharge."
                    } else {
                        notification = "The device might not be supported, please retry."
                    }
                } else {
                    notification = "The device might not be supported, please retry."
                }
                let alert = UIAlertController(title: "Scan Result", message: notification, preferredStyle: UIAlertControllerStyle.alert)
                let action = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil)
                alert.addAction(action)
                self.present(alert, animated: true, completion: {})
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

