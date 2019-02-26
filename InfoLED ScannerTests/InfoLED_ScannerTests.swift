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

class InfoLED_ScannerTests: XCTestCase {
    var internalHistoryLens: [HistoryLens]!
    var fpsCounter: FpsCounter!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        fpsCounter = FpsCounter()
        let bufferProcessor = SampleBufferProcessor(delegate: self)
        let videoURL = Bundle(for: type(of: self)).url(forResource: "IMG_5622", withExtension: "MOV")!
        let videoAsset = AVAsset(url: videoURL)
        let reader = try! AVAssetReader(asset: videoAsset)

        let videoTrack = videoAsset.tracks(withMediaType: .video)[0]

        let trackReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as [String : Any])

        reader.add(trackReaderOutput)

        reader.startReading()

        while let sampleBuffer = trackReaderOutput.copyNextSampleBuffer() {
            bufferProcessor.processSampleBuffer(sampleBuffer: sampleBuffer)
        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}

extension InfoLED_ScannerTests: SampleBufferProcessorDelegate {
    var historyLenses: [HistoryLens] {
        get {
            return internalHistoryLens
        }
        set(newValue) {
            internalHistoryLens = newValue
        }
    }

    func callFpsCounter(time: Double) -> Double? {
        return fpsCounter.call(time: time)
    }
}
