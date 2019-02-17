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

    let offThreshold = 2.75 / 240
    let onThreshold = 3.6 / 240
    let preamble = [0, 1, 1, 0, 1, 1, 0, 0, 1, 0];

    init(windowSampleSize : Int) {
        self.windowSampleSize = windowSampleSize
    }

    func resetProecessing() {
        os_log("reset processing")
        pixelHistory = [((Int, Int, Int), Double?)]()
        adaptivePixelHistory = [((Int, Int, Int), Double?)]()
        adaptiveGrayHistory = [(Int, Double?)]()
        levelDurationHistory = [(Int, Double)]()
        frameLevels = [Int]();
        decodedPackets = [[Int]]();
        verifiedPackets = [[Int]]();
        currentLevel = 0
        currentLevelDuration = 0
    }

    static func packetString(packet: [Int]) -> String {
        return String(packet.map { (bit) -> Character in
            return bit == 0 ? "0" : "1"
        })
    }

    func processNewPixel(pixel: (Int, Int, Int), frameDuration: Double?) -> Bool {
        pixelHistory += [(pixel, frameDuration)]
        if pixelHistory.count >= 2 * windowSampleSize + 1 {
            let centerIndex = pixelHistory.count - windowSampleSize - 1
            let windowRange = (centerIndex - windowSampleSize)...(centerIndex + windowSampleSize)
            let sum = pixelHistory[windowRange].reduce((0, 0, 0)
                , {(sum: (Int, Int, Int), nextPixel: ((Int, Int, Int), Double?)) -> (Int, Int, Int) in
                    return sum + nextPixel.0
            })
            let average = sum / (windowSampleSize * 2 + 1)
            let adaptivePixel = (pixelHistory[centerIndex].0 - average, pixelHistory[centerIndex].1);
            if let result = try? processNewAdativePixel(adaptivePixel:adaptivePixel) {
                if result == true {
                    return true
                }
            } else {
                print("wierd behavior, probably no tag");
            }
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
        if (newLevel == 0 || newLevel * currentLevel < 0) { // End of a level duration
            currentLevelDuration += adaptivePixel.1! * Double(currentLevel) / Double(currentLevel - newLevel)
            let levelDuration = (currentLevel, currentLevelDuration)
            if (try! processNewLevelDuration(levelDuration: levelDuration)) {
                return true
            }
        }
        if (currentLevel == 0 || newLevel * currentLevel < 0) { // Start of a level duration
            currentLevelDuration = adaptivePixel.1! * Double(newLevel) / Double(newLevel - currentLevel)
        } else { // not a start, then
            currentLevelDuration += adaptivePixel.1!
        }
        currentLevel = newLevel
        return false
    }

    func processNewLevelDuration(levelDuration: (Int, Double)) throws -> Bool {
        levelDurationHistory.append(levelDuration)
        let (level, Duration) = levelDuration;
        if level == 0 {
//            os_log("processNewLevelDuration: level error")
            throw HistoryProcessorError.LevelError
        } else if level > 0 {
            if Duration < onThreshold {
                frameLevels += [1]
            } else {
                frameLevels += [1, 1]
            }
        } else {
            if Duration < offThreshold {
                frameLevels += [0]
            } else {
                frameLevels += [0, 0]
            }
        }
        if decodeFrameLevels() {
//             os_log("levelDurationHistory: %@", levelDurationHistory)
             os_log("frameLevels: %@", frameLevels)
            return true
        }
        return false
    }

    func decodeFrameLevels() -> Bool {
        if (frameLevels.count > 2 * preamble.count) {
            let indices = Array(frameLevels.startIndex...frameLevels.endIndex - preamble.count)

//            let preamblePos = indices.reduce([]) { (result, index) -> [Int] in
//                let subarray = frameLevels[index ... (index + preamble.count - 1)]
//                if (subarray == ArraySlice<Int>(preamble)) {
//                    return result + [index];
//                } else {
//                    return result;
//                }
//            }
//
//            var preambleRanges = [(Int, Int)]();
//            if preamblePos.count > 1 {
//                for i in 1..<preamblePos.count {
//                    let start = preamblePos[i - 1] + preamble.count
//                    let end = preamblePos[i] - 1
//                    if start < end {
//                        preambleRanges += [(preamblePos[i - 1] + preamble.count, preamblePos[i] - 1)]
//                    }
//                }
//            }

            var result = [(Int, Int)]();
            for index in 1..<indices.count {
                let subarray = frameLevels[index ... (index + preamble.count - 1)]
                if (subarray == ArraySlice<Int>(preamble)) {
                    let packetBegin = index + preamble.count
                    let packetEnd = packetBegin + (2 + 16) * 2
                    if packetEnd <= frameLevels.count {
                        result += [(packetBegin, packetEnd)]
                    } else {
                        break
                    }
                }
            }
            let preambleRanges = result

            decodedPackets = preambleRanges.map({ (start, end) in
                return frameLevels[start ..< end].enumerated().filter({ (index, element) -> Bool in
                    return index % 2 == 0
                }).map({ (_, element) in
                    element
                })
            })

            verifiedPackets = [[Int]]()
            for packet in decodedPackets {
                if verifyPacket(packet: packet) {
                    verifiedPackets += [Array(packet.dropFirst(2))]

                }
            }

            if verifiedPackets.count != 0 {
//                os_log("filteredHistorys: %@", verifiedPackets)
                return true
            }
        }
        return false
    }

    func verifyPacket(packet: [Int]) -> Bool {
        var hash = [0, 0]

        for i in Swift.stride(from: 0, to: packet.count, by: 2){
            hash[0] ^= packet[i + 0]
            hash[1] ^= packet[i + 1]
        }

        return hash[0] == 0 && hash[1] == 0;
    }
}
