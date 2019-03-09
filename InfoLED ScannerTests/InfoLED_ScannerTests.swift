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

class TestPacketResult {
    let frameId: Int
    let actualPacket: [Int]
    let BER: Float

    init(frameId: Int, actualPacket: [Int], correctPacket: inout [Int]) {
        var wrongBits = 0
        for (actualDigit, correctDigit) in zip(actualPacket, correctPacket) {
            wrongBits += actualDigit == correctDigit ? 0 : 1
        }
        self.BER = Float(wrongBits) / Float(correctPacket.count)
        self.actualPacket = actualPacket
        self.frameId = frameId
    }
}

let BER_THRESHOLD = Float(0.0)

class TestVideoResult {
    var packets = [TestPacketResult]()
    var averageBER: Float!
    var packetSuccessRate: Float!
    var totalFrames: Int!
    var firstPacketFrame: Int? = nil

    func calculateResult(totalFrames: Int, packetLength: Int = HistoryProcessor.totalPacketLength) {
        let totalPacketCount = totalFrames / packetLength
        self.totalFrames = totalFrames
        self.averageBER = packets.reduce(Float(0), { (sum, packetResult) in sum + packetResult.BER}) / Float(packets.count)
        self.packetSuccessRate = Float(self.packets.count) / Float(totalPacketCount)
        firstPacketFrame = packets.reduce(totalFrames + 1, { (result, packet) in
            if packet.BER <= BER_THRESHOLD && packet.frameId < result {
                return packet.frameId
            } else {
                return result
            }
        })
        firstPacketFrame = firstPacketFrame == totalFrames + 1 ? nil : firstPacketFrame
    }

    func printDescription() {
        print("""
            Test Summary:
            \(self.packets.count) packet(s) received
            First received packet at frame \(self.firstPacketFrame ?? -1)
            Average BER: \(self.averageBER ?? 1.0)
            BER: \(self.packets.map{$0.BER})
            """)
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

    func test0305_1() {
        let testFolderName = "03-05"
        let cameraConfigs = [1]
        let cameraConfigNames = cameraConfigs.map{"\($0)x"}
        let videoDistances = cameraConfigs.map{stride(from: 50 * $0, to: 0 * $0, by: -10 * $0)}
        let videoDistanceNames = videoDistances.map{$0.map{"\($0)cm"}}
        var resultDict = [String: TestVideoResult]()
        for (cameraConfigName, videoNames) in zip(cameraConfigNames, videoDistanceNames) {
            let directory = "\(testFolderName)/\(cameraConfigName)"
            for videoName in videoNames {
                print("\(cameraConfigName)/\(videoName)")
                let result = testVideo(directory: directory, name: videoName)
                resultDict["\(cameraConfigName)/\(videoName)"] = result
                result.printDescription()
            }
        }
        for (name, result) in resultDict {
            print("Test \(name):\n")
            result.printDescription()
        }
    }

    func test0305_2() {
        let testFolderName = "03-05"
        let cameraConfigs = [2]
        let cameraConfigNames = cameraConfigs.map{"\($0)x"}
        let videoDistances = cameraConfigs.map{stride(from: 50 * $0, to: 0 * $0, by: -10 * $0)}
        let videoDistanceNames = videoDistances.map{$0.map{"\($0)cm"}}
        var resultDict = [String: TestVideoResult]()
        for (cameraConfigName, videoNames) in zip(cameraConfigNames, videoDistanceNames) {
            let directory = "\(testFolderName)/\(cameraConfigName)"
            for videoName in videoNames {
                print("\(cameraConfigName)/\(videoName)")
                let result = testVideo(directory: directory, name: videoName)
                resultDict["\(cameraConfigName)/\(videoName)"] = result
            }
        }
        for (name, result) in resultDict {
            print("Test \(name):\n")
            result.printDescription()
        }
    }
    
    func testVideo(directory: String, name: String) -> TestVideoResult {
        let delegate = TestBufferProcessorDelegate()
        let eventLogger = MemoryEventLogger()
        let bufferProcessor = SampleBufferProcessor(delegate: delegate, eventLogger: eventLogger)
        let videoURL = Bundle(for: type(of: self)).url(forResource: name, withExtension: "MOV", subdirectory: directory)!
        let videoAsset = AVAsset(url: videoURL)
        let reader = try! AVAssetReader(asset: videoAsset)

        let videoTrack = videoAsset.tracks(withMediaType: .video)[0]

        let trackReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as [String : Any])

        reader.add(trackReaderOutput)

        reader.startReading()

        var lastEventCount = 0
        let videoResult = TestVideoResult()

        while let sampleBuffer = trackReaderOutput.copyNextSampleBuffer() {
            bufferProcessor.processSampleBufferSync(sampleBuffer: sampleBuffer)
            print("frame \(delegate.frameCount): ")
            for eventId in lastEventCount ..< eventLogger.events.count {
                print("event: \(eventLogger.events[eventId])")
                let currentEvent = eventLogger.events[eventId]
                if currentEvent.message.keys.contains("decodedPacket") {
                    var correctPackets = [0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1]
                    let actualPacket = Array((currentEvent.message["decodedPacket"] as! [Int]).dropFirst(2))
                    print(actualPacket)
                    let packetResult = TestPacketResult(frameId: delegate.frameCount - 1, actualPacket: actualPacket, correctPacket: &correctPackets)
                    videoResult.packets.append(packetResult)
                }
            }
            lastEventCount = eventLogger.events.count
            if delegate.frameCount >= 2400 {
                break;
            }
        }
        videoResult.calculateResult(totalFrames: delegate.frameCount)
        return videoResult
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
