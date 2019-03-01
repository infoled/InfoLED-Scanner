//
//  InfoLED_ScannerTests.swift
//  InfoLED ScannerTests
//
//  Created by Jackie Yang on 3/16/16.
//  Copyright © 2016 yangjunrui. All rights reserved.
//

import XCTest
import AVFoundation
@testable import InfoLED_Scanner

class TestBufferProcessorDelegate: SampleBufferProcessorDelegate {
    var beginTimestamp: Double?
    var lastTimestamp: Double?
    var frameCount = 0
    var historyLenses: [HistoryLens] = []

    var elapsedTime: Double {
        get {
            if let beginTimestamp = self.beginTimestamp {
                if let lastTimestamp = self.lastTimestamp {
                    return lastTimestamp - beginTimestamp
                }
            }
            return Double(0)
        }
    }

    func callFpsCounter(time: Double) -> Double? {
        if beginTimestamp == nil {
            beginTimestamp = time
        }
        var frameTime: Double? = nil
        if let lastTimestamp = self.lastTimestamp {
            frameTime = time - lastTimestamp
        }
        lastTimestamp = time
        frameCount += 1
        return frameTime
    }


}

class InfoLED_ScannerTests: XCTestCase {
    var internalHistoryLens: [HistoryLens]!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        let delegate = TestBufferProcessorDelegate()
        let eventLogger = MemoryEventLogger()
        let bufferProcessor = SampleBufferProcessor(delegate: delegate, eventLogger: eventLogger)
        let videoURL = Bundle(for: type(of: self)).url(forResource: "IMG_5622", withExtension: "MOV")!
        let videoAsset = AVAsset(url: videoURL)
        let reader = try! AVAssetReader(asset: videoAsset)

        let videoTrack = videoAsset.tracks(withMediaType: .video)[0]

        let trackReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as [String : Any])

        reader.add(trackReaderOutput)

        reader.startReading()

        var lastEventCount = 0

        while let sampleBuffer = trackReaderOutput.copyNextSampleBuffer() {
            bufferProcessor.processSampleBuffer(sampleBuffer: sampleBuffer)
            print("frame \(delegate.frameCount): ")
            for eventId in lastEventCount ..< eventLogger.events.count {
                print("event: \(eventLogger.events[eventId])")
            }
            lastEventCount = eventLogger.events.count
        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
