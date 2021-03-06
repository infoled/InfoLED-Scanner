//
//  HistoryLens.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 2/11/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

func ScreenScale() -> CGFloat {
    #if os(OSX)
    return CGFloat(1)
    #elseif os(iOS)
    return UIScreen.main.scale
    #endif
}

class HistoryLens: Lens {
    public var historyProcessor: HistoryProcessor!

    public var poiPos: CGPoint {
        get {
            return CGPoint(x: position.x * ScreenScale(), y: position.y * ScreenScale())
        }
        set (newPos) {
            position = CGPoint(x: newPos.x / ScreenScale(), y: newPos.y / ScreenScale())
        }
    }

    public var poiSize: CGSize {
        get {
            return CGSize(width: size.width * ScreenScale(), height: size.height * ScreenScale())
        }
        set (newSize) {
            size = CGSize(width: newSize.width / ScreenScale(), height: newSize.height / ScreenScale())
        }
    }

    public var progress: Float? {
        get {
            if self.scanning {
                return Float(self.cycleCount) / Float(Constants.cycleLimit)
            } else {
                return nil
            }
        }
    }

    var lensHistory = 0
    var lensMissing = 0
    var lensSize = 0

    var scanning : Bool {
        return lensHistory > 0
    }

    var processCount = 0
    var cycleCount = 0

    let eventLogger: EventLogger?

    init(windowSize: Int, poiSize: CGSize, eventLogger: EventLogger?) {
        self.eventLogger = eventLogger
        super.init(position: CGPoint.zero, data: [], size: CGSize.zero)
        let processorLogger = self.eventLogger?.Logger { [weak self] () -> Dictionary<String, Any> in
            ["position": self!.poiPos]
        }
        self.historyProcessor = HistoryProcessor(windowSampleSize: windowSize, eventLogger: processorLogger)
        self.poiSize = poiSize
        self.poiPos = CGPoint(x: CGFloat(Constants.videoWidth) / 2, y: CGFloat(Constants.videoHeight) / 2)
    }

    func processFrame(lensTexture: MTLTexture, imageProcessingQueue: DispatchQueue, frameDuration: Double?, frameId: Int) {
        if self.scanning {
            let channelPerPixel = 4
            let bytesPerPixel = channelPerPixel * MemoryLayout<Float32>.size
            let lensPoiX = min(Double(poiPos.x) * Constants.decimation * Constants.decimationLens, Double(lensTexture.width))
            let lensPoiY = min(Double(poiPos.y) * Constants.decimation * Constants.decimationLens, Double(lensTexture.height))
            let readWidth = 2
            let readHeight = 2
            let pixelsCount = readWidth * readHeight
            let lensPoiXStart = min(Int(floor(lensPoiX)), Int(lensTexture.width - readWidth))
            let lensPoiYStart = min(Int(floor(lensPoiY)), Int(lensTexture.height - readHeight))
            let lensRegion = MTLRegionMake2D(lensPoiXStart, lensPoiYStart, readWidth, readHeight)
            var buffer = [Float32](repeating: 0, count: Int(pixelsCount * 4))
            let lensBytesPerRow = readWidth * bytesPerPixel
            lensTexture.getBytes(&buffer, bytesPerRow: lensBytesPerRow, from: lensRegion, mipmapLevel: 0)
            let pixels = stride(from: 0, to: readWidth, by: 1).map({ (x) -> [Float32] in
                stride(from: 0, to: readHeight, by: 1).map({ (y) -> Float32 in
                    let start = (y * readWidth + x) * channelPerPixel
                    let end = start + channelPerPixel
                    return buffer[start..<end].reduce(Float32(0), {(sum, pixel) -> Float32 in
                        return sum + Float32(pixel)
                    })
                })
            })
            let lensPoiXReminder = lensPoiX - Double(lensPoiXStart)
            let lensPoiYReminder = lensPoiY - Double(lensPoiYStart)
            var lensPixel = stride(from: 0, to: readWidth, by: 1).map({ (x) -> Double in
                stride(from: 0, to: readHeight, by: 1).map({ (y) -> Double in
                    let xFactor = x == 0 ? (1 - lensPoiXReminder) : lensPoiXReminder
                    let yFactor = y == 0 ? (1 - lensPoiYReminder) : lensPoiYReminder
                    return xFactor * yFactor * Double(pixels[x][y])
                }).reduce(0, +)
            }).reduce(0, +)
            if lensPixel.isNaN {
                lensPixel = 0
                print("lensPixel NaN")
            }
            let lensPixelInt = Int(lensPixel * 1000)
            imageProcessingQueue.sync {
                if (self.historyProcessor.processNewPixel(pixel: (lensPixelInt, lensPixelInt, lensPixelInt), frameDuration: frameDuration, frameId: frameId) || self.processCount == 2000) {
                    let packet = self.historyProcessor.getPopularPacket()
                    DispatchQueue.main.async {
                        if let validPacket = packet {
                            self.data = validPacket
                            self.detected = true
                        } else {
                            self.detected = false
                        }
                    }
                }
                self.processCount += 1
            }
            self.cycleCount += 1;
        }
    }
}
