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

    var pixelHistory = [(Int, Int, Int)]()
    var adaptivePixelHistory = [(Int, Int, Int)]()
    var adaptiveGrayHistory = [Int]()
    var levelDurationHistory = [(Int, Double)]()
    var frameLevels = [Int]();
    var decodedPackets = [[Int]]();
    var currentLevel : Int = 0
    var currentLevelDuration : Double = 0
    var windowSampleSize : Int

    let offThreshold = 2.75
    let onThreshold = 3.6
    let preamble = [0, 1, 1, 0, 1, 1, 0, 0, 1, 0];
    let epilogue = [1, 0, 0, 1, 0, 0, 1, 1, 0, 1];

    init(windowSampleSize : Int) {
        self.windowSampleSize = windowSampleSize
    }

    func processNewPixel(pixel: (Int, Int, Int)) -> Bool {
        pixelHistory += [pixel]
        if pixelHistory.count >= 2 * windowSampleSize + 1 {
            let centerIndex = pixelHistory.count - windowSampleSize - 1
            let windowRange = (centerIndex - windowSampleSize)...(centerIndex + windowSampleSize)
            let sum = pixelHistory[windowRange].reduce((0, 0, 0)
                , +)
            let average = sum / (windowSampleSize * 2 + 1)
            let adaptivePixel = pixelHistory[centerIndex] - average;
            if (try! processNewAdativePixel(adaptivePixel:adaptivePixel)) {
                return true
            }
        }
        return false
    }

    func processNewAdativePixel(adaptivePixel: (Int, Int, Int)) throws -> Bool {
        adaptivePixelHistory.append(adaptivePixel)
        let adaptiveGray = adaptivePixel.0 + adaptivePixel.1 + adaptivePixel.2
        adaptiveGrayHistory.append(adaptiveGray)
        let newLevel = adaptiveGray;
        if (newLevel == 0 && currentLevel == 0) {
            throw HistoryProcessorError.LevelError
        }
        if (newLevel == 0 || newLevel * currentLevel < 0) { // End of a level duration
            currentLevelDuration += Double(currentLevel) / Double(currentLevel - newLevel)
            let levelDuration = (currentLevel, currentLevelDuration)
            if (try! processNewLevelDuration(levelDuration: levelDuration)) {
                return true
            }
        }
        if (currentLevel == 0 || newLevel * currentLevel < 0) { // Start of a level duration
            currentLevelDuration = Double(newLevel) / Double(newLevel - currentLevel)
        } else { // not a start, then
            currentLevelDuration += 1
        }
        currentLevel = newLevel
        return false
    }

    func processNewLevelDuration(levelDuration: (Int, Double)) throws -> Bool {
        levelDurationHistory.append(levelDuration)
        let (level, Duration) = levelDuration;
        if level == 0 {
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
//             os_log("frameLevels: %@", frameLevels)
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

            var find_preamble = true;
            var last_preamble = 0;
            var result = [(Int, Int)]();
            for index in 1..<indices.count {
                let subarray = frameLevels[index ... (index + preamble.count - 1)]
                if (find_preamble) {
                    if (subarray == ArraySlice<Int>(preamble)) {
                        last_preamble = index
                        find_preamble = false
                    }
                } else {
                    if (subarray == ArraySlice<Int>(preamble)) {
                        result += [(last_preamble + preamble.count, index - 1)];
                    }
                }
            }
            let preambleRanges = result

            decodedPackets = preambleRanges.map({ (start, end) in
                return frameLevels[start ... end].enumerated().filter({ (index, element) -> Bool in
                    return index % 2 == 0
                }).map({ (_, element) in
                    element
                })
            })

            if decodedPackets.count != 0 {
//                os_log("filteredHistorys: %@", filteredHistorys)
                return true
            }
        }
        return false
    }
}
