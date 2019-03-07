//
//  HistoryProcessor.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 11/24/18.
//  Copyright © 2018 yangjunrui. All rights reserved.
//
import os.log

class HistoryProcessor {
    enum HistoryProcessorError: Error {
        case LevelError
    }

    var pixelHistory = [((Int, Int, Int), Double?)]()
    var adaptivePixelHistory = [((Int, Int, Int), Double?)]()
    var adaptiveGrayHistory = [(Int, Double?)]()
    var levelDurationHistory = [(Int, Double)]()
    var frameLevels = [Int]();
    var decodedPackets = [[Int]]();
    var verifiedPackets = [[Int]]();
    var currentLevel : Int = 0
    var currentLevelDuration : Double = 0
    var windowSampleSize : Int

    static let offThreshold = 2.75 / 240
    static let onThreshold = 3.6 / 240
    static let preamble = [0, 1, 1, 0, 1, 1, 0, 0, 1, 0];

    static let dataLength = 16
    static let hashLength = 2
    static let preambleLength = preamble.count

    static let verifiedPacketsLimit = 10
    static let frameLevelsLimit = preamble.count + (dataLength + hashLength) * 2 + 10
    static let levelDurationHistoryLimit = frameLevelsLimit
    static let adaptivePixelHistoryLimit = levelDurationHistoryLimit * 10
    static let pixelHistoryLimit = adaptivePixelHistoryLimit

    static let cleanUpLimit = 100

    var cleanUpTimer = 0

    let eventLogger: EventLogger?

    init(windowSampleSize : Int, eventLogger: EventLogger?) {
        self.windowSampleSize = windowSampleSize
        self.eventLogger = eventLogger
    }

    static func packetString(packet: [Int]) -> String {
        return String(packet.map { (bit) -> Character in
            return bit == 0 ? "0" : "1"
        })
    }

    func processNewPixel(pixel: (Int, Int, Int), frameDuration: Double?) -> Bool {
        cleanUpTimer += 1
        if (cleanUpTimer > HistoryProcessor.cleanUpLimit) {
            cleanUp()
            cleanUpTimer = 0
        }
        guard frameDuration != nil else {
            return false
        }
        if let result = try? processNewAdativePixel(adaptivePixel:(pixel, frameDuration)) {
            if result == true {
                return true
            }
        } else {
            print("wierd behavior, probably no tag");
        }
        return false
    }

    func processNewAdativePixel(adaptivePixel: ((Int, Int, Int), Double?)) throws -> Bool {
        adaptivePixelHistory.append(adaptivePixel)
        let adaptiveGray = adaptivePixel.0.0 + adaptivePixel.0.1 + adaptivePixel.0.2
        adaptiveGrayHistory.append((adaptiveGray, adaptivePixel.1))
        let newLevel = adaptiveGray;
        if (newLevel == 0 && currentLevel == 0) {
//            os_log("processNewAdativePixel: level error %@", adaptiveGrayHistory)
            throw HistoryProcessorError.LevelError
        }
        var verifiedPacketFound = false
        if (newLevel == 0 || newLevel * currentLevel < 0) { // End of a level duration
            currentLevelDuration += adaptivePixel.1! * Double(currentLevel) / Double(currentLevel - newLevel)
            let levelDuration = (currentLevel, currentLevelDuration)
            verifiedPacketFound = try! processNewLevelDuration(levelDuration: levelDuration)
        }
        if (currentLevel == 0 || newLevel * currentLevel < 0) { // Start of a level duration
            currentLevelDuration = adaptivePixel.1! * Double(newLevel) / Double(newLevel - currentLevel)
        } else { // not a start, then
            currentLevelDuration += adaptivePixel.1!
        }
        currentLevel = newLevel
        return verifiedPacketFound
    }

    func processNewLevelDuration(levelDuration: (Int, Double)) throws -> Bool {
        levelDurationHistory.append(levelDuration)
        let (level, Duration) = levelDuration;
        if level == 0 {
//            os_log("processNewLevelDuration: level error")
            throw HistoryProcessorError.LevelError
        } else if level > 0 {
            if Duration < HistoryProcessor.onThreshold {
                frameLevels += [1]
            } else {
                frameLevels += [1, 1]
            }
        } else {
            if Duration < HistoryProcessor.offThreshold {
                frameLevels += [0]
            } else {
                frameLevels += [0, 0]
            }
        }
        if decodeFrameLevels() {
//             os_log("levelDurationHistory: %@", levelDurationHistory)
//             os_log("frameLevels: %@", frameLevels)
            return true
        }
        return false
    }

    func decodeFrameLevels() -> Bool {
        let packetBitLength = HistoryProcessor.preambleLength + (HistoryProcessor.hashLength + HistoryProcessor.dataLength) * 2
        if (frameLevels.count > packetBitLength) {
            let indices = Array(frameLevels.startIndex...frameLevels.endIndex - packetBitLength)

            var result = [(Int, Int)]()
            print(indices)
            for index in indices {
                let subarray = frameLevels[index ..< (index + HistoryProcessor.preambleLength)]
                if (subarray == ArraySlice<Int>(HistoryProcessor.preamble)) {
                    let packetBegin = index + HistoryProcessor.preambleLength
                    let packetEnd = packetBegin + (HistoryProcessor.hashLength + HistoryProcessor.dataLength) * 2
                    assert(packetEnd <= frameLevels.count)
                    result += [(packetBegin, packetEnd)]
                }
            }
            let preambleRanges = result

            let newDecodedPackets = preambleRanges.map({ (start, end) in
                return frameLevels[start ..< end].enumerated().filter({ (index, element) -> Bool in
                    return index % 2 == 0
                }).map({ (_, element) in
                    element
                })
            })


            if let lastIndex = indices.last {
                frameLevels = Array(frameLevels.dropFirst(lastIndex + 1))
            }

            if newDecodedPackets.count != 0 {
                for packet in newDecodedPackets {
                    eventLogger?.recordMessage(dict: ["decodedPacket": packet])
                    withUnsafePointer(to: &cleanUpTimer) { (selfPointer) in
                        print("decodedPacket[\(selfPointer)]: \(packet)")
                    }
                }
            }

            var newVerifiedPacket = false
            for packet in newDecodedPackets {
                if verifyPacket(packet: packet) {
                    let verifiedPacket = Array(packet.dropFirst(2))
                    eventLogger?.recordMessage(dict: ["verifiedPacket": verifiedPacket])
                    verifiedPackets += [verifiedPacket]
                    newVerifiedPacket = true
                }
            }

            return newVerifiedPacket
        }
        return false
    }

    func verifyPacket(packet: [Int]) -> Bool {
        var hash = [Int].init(repeating: 0, count: HistoryProcessor.hashLength)

        for i in Swift.stride(from: 0, to: packet.count, by: HistoryProcessor.hashLength){
            for j in 0..<HistoryProcessor.hashLength {
                hash[j] ^= packet[i + j]
            }
        }

        return hash.reduce(true, { (result, hash_bit) -> Bool in
            return result && (hash_bit == 0)
        })
    }

    func getPopularPacket() -> [Int]? {
        let counts = verifiedPackets.reduce(into: [:]) {(result, packet) in
            result[packet, default: 0] += 1
        }

        if let (value, _) = counts.max(by: { $0.1 < $1.1 }) {
            return value
        } else {
            return nil
        }
    }

    func cleanUp() {
        if pixelHistory.count > HistoryProcessor.pixelHistoryLimit {
            pixelHistory = Array(pixelHistory.suffix(HistoryProcessor.pixelHistoryLimit))
        }
        if adaptivePixelHistory.count > HistoryProcessor.adaptivePixelHistoryLimit {
            adaptivePixelHistory = Array(adaptivePixelHistory.suffix(HistoryProcessor.adaptivePixelHistoryLimit))
        }
        if adaptiveGrayHistory.count > HistoryProcessor.adaptivePixelHistoryLimit {
            adaptiveGrayHistory = Array(adaptiveGrayHistory.suffix(HistoryProcessor.adaptivePixelHistoryLimit))
        }
        if levelDurationHistory.count > HistoryProcessor.levelDurationHistoryLimit {
            levelDurationHistory = Array(levelDurationHistory.suffix(HistoryProcessor.levelDurationHistoryLimit))
        }
        if frameLevels.count > HistoryProcessor.frameLevelsLimit {
            frameLevels = Array(frameLevels.suffix(HistoryProcessor.frameLevelsLimit))
        }
        if verifiedPackets.count > HistoryProcessor.verifiedPacketsLimit {
            verifiedPackets = Array(verifiedPackets.suffix(HistoryProcessor.verifiedPacketsLimit))
        }
    }
}
