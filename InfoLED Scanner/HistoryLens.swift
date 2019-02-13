//
//  HistoryLens.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 2/11/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import UIKit

class HistoryLens: Lens {
    public let historyProcessor: HistoryProcessor

    public var poiPos: CGPoint {
        get {
            return CGPoint(x: position.x * UIScreen.main.scale, y: position.y * UIScreen.main.scale)
        }
        set (newPos) {
            position = CGPoint(x: newPos.x / UIScreen.main.scale, y: newPos.y / UIScreen.main.scale)
        }
    }

    public var poiSize: CGSize {
        get {
            return CGSize(width: size.width * UIScreen.main.scale, height: size.height * UIScreen.main.scale)
        }
        set (newSize) {
            size = CGSize(width: newSize.width / UIScreen.main.scale, height: newSize.height / UIScreen.main.scale)
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

    var scanning = true

    var processCount = 0
    var cycleCount = 0

    var cyclesFound = 2400 //Never found before, so assign a large value

    init(windowSize: Int, poiSize: CGSize) {
        self.historyProcessor = HistoryProcessor(windowSampleSize: windowSize)
        super.init(position: CGPoint.zero, text: "loading", size: CGSize.zero)
        self.poiSize = poiSize
        self.poiPos = CGPoint(x: CGFloat(Constants.videoWidth) / 2, y: CGFloat(Constants.videoHeight) / 2)
    }

    func processFrame(lensTexture: MTLTexture, imageProcessingQueue: DispatchQueue, frameDuration: Double?) {
        if self.scanning {
            let bytesPerPixel = 4
            let lensPoiX = min(Double(poiPos.x) * Constants.decimation * Constants.decimationLens, Double(lensTexture.width))
            let lensPoiY = min(Double(poiPos.y) * Constants.decimation * Constants.decimationLens, Double(lensTexture.height))
            let readWidth = 2
            let readHeight = 2
            let pixelsCount = readWidth * readHeight
            let lensPoiXStart = min(Int(floor(lensPoiX)), Int(lensTexture.width - readWidth))
            let lensPoiYStart = min(Int(floor(lensPoiY)), Int(lensTexture.height - readHeight))
            let lensRegion = MTLRegionMake2D(lensPoiXStart, lensPoiYStart, readWidth, readHeight)
            let imageByteCount = pixelsCount * bytesPerPixel
            var buffer = [UInt8](repeating: 0, count: Int(imageByteCount))
            let lensBytesPerRow = readWidth * bytesPerPixel
            lensTexture.getBytes(&buffer, bytesPerRow: lensBytesPerRow, from: lensRegion, mipmapLevel: 0)
            let pixels = stride(from: 0, to: readWidth, by: 1).map({ (x) -> [Int] in
                stride(from: 0, to: readHeight, by: 1).map({ (y) -> Int in
                    let start = y * bytesPerPixel * readWidth + x * bytesPerPixel
                    let end = start + bytesPerPixel
                    return buffer[start..<end].reduce(0, {(sum, pixel) -> Int in
                        return sum + Int(pixel)
                    })
                })
            })
            let lensPoiXReminder = lensPoiX - Double(lensPoiXStart)
            let lensPoiYReminder = lensPoiY - Double(lensPoiYStart)
            let lensPixel = stride(from: 0, to: readWidth, by: 1).map({ (x) -> Double in
                stride(from: 0, to: readHeight, by: 1).map({ (y) -> Double in
                    let xFactor = x == 0 ? (1 - lensPoiXReminder) : lensPoiXReminder
                    let yFactor = y == 0 ? (1 - lensPoiYReminder) : lensPoiYReminder
                    return xFactor * yFactor * Double(pixels[x][y])
                }).reduce(0, +)
            }).reduce(0, +)
            let lensPixelInt = Int(lensPixel)
            imageProcessingQueue.async {
                if (self.historyProcessor.processNewPixel(pixel: (lensPixelInt, lensPixelInt, lensPixelInt), frameDuration: frameDuration) || self.processCount == 2000) {
                    var notification: String!;
                    let tagFound = self.historyProcessor.verifiedPackets.count != 0
                    if (tagFound) {
                        notification = "\(HistoryProcessor.packetString(packet: self.historyProcessor.verifiedPackets[0]))"
                    } else {
                        notification = "tag not found"
                    }
                    DispatchQueue.main.async {
                        self.text = notification
                        self.detected = tagFound
                    }
                    self.historyProcessor.resetProecessing()
                }
                self.processCount += 1
            }
            self.cycleCount += 1;
        }
    }
}
