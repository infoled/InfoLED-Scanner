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
    var levelDurationHistory = [(Int, Double, Double)]()
    var frameLevels = [Int]();
    var frameLevelsEnergy = [Double]();
    var frameLevelsFrameId = [Int]();
    var decodedPackets = [([Int], Double, Int)]();
    var verifiedPackets = [([Int], Double, Int)]();
    var currentLevel : Int = 0
    var currentLevelStrength: Double = 0
    var currentLevelDuration: Double = 0
    var currentLevelFrameId = 0
    var windowSampleSize : Int

    static let offThreshold = 2.75 / 240
    static let onThreshold = 3.6 / 240
    static let preamble = [0, 1, 1, 0, 1, 1, 0, 0, 1, 0];

    static let dataLength = 16
    static let hashLength = 2
    static let preambleLength = preamble.count
    static let totalPacketLength = preambleLength + (hashLength + dataLength) * 2

    static let verifiedPacketsLimit = 10
    static let frameLevelsLimit = totalPacketLength + 10
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

    static func packetToInt<T: RandomAccessCollection>(packet: T) -> Int where T.Iterator.Element == Int {
        if packet.count == 0 {
            return 0
        } else if packet.count == 1 {
            return packet.last!
        } else {
            return 2 * packetToInt(packet:packet.dropLast(1)) + packet.last!
        }
    }

    func processNewPixel(pixel: (Int, Int, Int), frameDuration: Double?, frameId: Int) -> Bool {
        cleanUpTimer += 1
        if (cleanUpTimer > HistoryProcessor.cleanUpLimit) {
            cleanUp()
            cleanUpTimer = 0
        }
        guard frameDuration != nil else {
            return false
        }
        if let result = try? processNewAdativePixel(adaptivePixel:(pixel, frameDuration), frameId: frameId) {
            if result == true {
                return true
            }
        } else {
            print("wierd behavior, probably no tag");
        }
        return false
    }

    func processNewAdativePixel(adaptivePixel: ((Int, Int, Int), Double?), frameId: Int) throws -> Bool {
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
            let currentLevelRatio = Double(currentLevel) / Double(currentLevel - newLevel)
            let currentLevelDurationInc = adaptivePixel.1! * currentLevelRatio
            currentLevelDuration += currentLevelDurationInc
            currentLevelStrength += (Double(abs(currentLevel)) * currentLevelDurationInc) / 2
            let levelDuration = (currentLevel, currentLevelDuration, currentLevelStrength)
            verifiedPacketFound = try! processNewLevelDuration(levelDuration: levelDuration, frameId: currentLevelFrameId)
        }
        if (currentLevel == 0 || newLevel * currentLevel < 0) { // Start of a level duration
            let newLevelRatio = Double(newLevel) / Double(newLevel - currentLevel)
            let newLevelDurationInc = adaptivePixel.1! * newLevelRatio
            currentLevelDuration = newLevelDurationInc
            currentLevelStrength = (Double(abs(newLevel)) * newLevelDurationInc) / 2
            currentLevelFrameId = frameId
        } else { // not a start, then
            let currentLevelDurationInc = adaptivePixel.1!
            currentLevelDuration += currentLevelDurationInc
            currentLevelStrength += (Double(abs(currentLevel + newLevel)) * currentLevelDurationInc) / 2
        }
        currentLevel = newLevel
        return verifiedPacketFound
    }

    func processNewLevelDuration(levelDuration: (Int, Double, Double), frameId: Int) throws -> Bool {
        levelDurationHistory.append(levelDuration)
        let (level, duration, energy) = levelDuration;
        func appendFrameLevels(_ levels: [Int]) {
            var energyAppended = false
            for level in levels {
                if !energyAppended {
                    frameLevels += [level]
                    frameLevelsEnergy += [energy]
                    frameLevelsFrameId += [frameId]
                    energyAppended = true
                } else {
                    frameLevels += [level]
                    frameLevelsEnergy += [0]
                    frameLevelsFrameId += [frameId]
                }
            }
        }
        if level == 0 {
//            os_log("processNewLevelDuration: level error")
            throw HistoryProcessorError.LevelError
        } else if level > 0 {
            if duration < HistoryProcessor.onThreshold {
                appendFrameLevels([1])
            } else {
                appendFrameLevels([1, 1])
            }
        } else {
            if duration < HistoryProcessor.offThreshold {
                appendFrameLevels([0])
            } else {
                appendFrameLevels([0, 0])
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
        let totalPacketLength = HistoryProcessor.totalPacketLength
        if (frameLevels.count >= totalPacketLength) {
            let indices = Array(frameLevels.startIndex...frameLevels.endIndex - totalPacketLength)

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

            let newDecodedPackets = preambleRanges.map({ (start, end) -> ([Int], Double, Int) in
                let packet = self.frameLevels[start ..< end].enumerated().filter({ (index, element) -> Bool in
                    return index % 2 == 0
                }).map({ (_, element) in
                    element
                })
                let energy = self.frameLevelsEnergy[start ..< end].reduce(0, +)
                let frameId = self.frameLevelsFrameId[start]
                return (packet, energy, frameId)
            })


            if let lastIndex = indices.last {
                frameLevels = Array(frameLevels.dropFirst(lastIndex + 1))
                frameLevelsEnergy = Array(frameLevelsEnergy.dropFirst(lastIndex + 1))
                frameLevelsFrameId = Array(frameLevelsFrameId.dropFirst(lastIndex + 1))
            }

            if newDecodedPackets.count != 0 {
                for packet in newDecodedPackets {
                    eventLogger?.recordMessage(dict: ["decodedPacket": packet])
                }
            }

            var newVerifiedPacket = false
            for packet in newDecodedPackets {
                if verifyPacket(packet: packet.0) {
                    let verifiedPacket = Array(packet.0.dropFirst(2))
                    eventLogger?.recordMessage(dict: ["verifiedPacket": verifiedPacket])
                    verifiedPackets += [(verifiedPacket, packet.1, packet.2)]
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
//        let counts = verifiedPackets.reduce(into: [:]) {(result, packet) in
//            result[packet.0, default: Double(0)] += packet.1
//        }
//
//        if let (value, _) = counts.max(by: { $0.1 < $1.1 }) {
//            return value
//        } else {
//            return nil
//        }
        return verifiedPackets.last?.0
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
        assert(frameLevels.count == frameLevelsEnergy.count && frameLevelsEnergy.count == frameLevelsFrameId.count)
        if frameLevels.count > HistoryProcessor.frameLevelsLimit {
            frameLevels = Array(frameLevels.suffix(HistoryProcessor.frameLevelsLimit))
            frameLevelsEnergy = Array(frameLevelsEnergy.suffix(from: HistoryProcessor.frameLevelsLimit))
            frameLevelsFrameId = Array(frameLevelsFrameId.suffix(from: HistoryProcessor.frameLevelsLimit))
        }
        if verifiedPackets.count > HistoryProcessor.verifiedPacketsLimit {
            verifiedPackets = Array(verifiedPackets.suffix(HistoryProcessor.verifiedPacketsLimit))
        }
    }
}
