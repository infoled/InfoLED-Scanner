//
//  BoundingBoxConverter.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/23/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import Foundation

let BoundingBoxCloseThreshold = Float(5)

struct EdgeRange {
    var start: Int
    var end: Int

    func overlapse(with range: EdgeRange) -> Bool {
        return (self.start - range.end) * (self.end - range.start) <= 0
    }

    func distance(to range: EdgeRange) -> Int {
        if (overlapse(with: range)) {
            return 0
        } else {
            if (self.start > range.start) {
                return self.start - range.end
            } else {
                return range.start - self.end
            }
        }
    }
}

class BoundingBoxContainer {
    var boundingBox: BoundingBox
    var children = [BoundingBoxContainer]()

    var xRange: EdgeRange
    var yRange: EdgeRange

    init(box: BoundingBox) {
        self.boundingBox = box
        self.xRange = EdgeRange(start: box.x_start, end: box.x_end)
        self.yRange = EdgeRange(start: box.y_start, end: box.y_end)
    }

    func selfDistance(to box: BoundingBoxContainer) -> Float {
        let xDistance = self.xRange.distance(to: box.xRange)
        let yDistance = self.yRange.distance(to: box.yRange)
        return sqrtf(Float(xDistance * xDistance + yDistance + yDistance))
    }

    func selfMatch(box: BoundingBoxContainer) -> Bool {
        return selfDistance(to: box) < BoundingBoxCloseThreshold
    }

    func match(box: BoundingBoxContainer) -> Bool {
        assert(box.children.count == 0)
        var matched = self.selfMatch(box: box)
        for child in children {
            if matched {
                break
            }
            matched = child.match(box: box)
        }
        return matched
    }

    struct PosSize {
        let x: Float
        let y: Float
        let size: Float

        static func +(lhs: PosSize, rhs: PosSize) -> PosSize {
            let size = lhs.size + rhs.size
            let x = (lhs.size * lhs.x + rhs.size * rhs.x) / size
            let y = (lhs.size * lhs.y + rhs.size * rhs.y) / size
            return PosSize(x: x, y: y, size: size)
        }

        static func +=(lhs: inout PosSize, rhs: PosSize) {
            lhs = lhs + rhs
        }
    }

    var posSize: PosSize {
        let selfX = Float(Int(Double(boundingBox.x_start + boundingBox.x_end) / Constants.decimation / Constants.decimationCcl / 2))
        let selfY = Float(Int(Double(boundingBox.y_start + boundingBox.y_end) / Constants.decimation / Constants.decimationCcl / 2))
        let selfSize = boundingBox.getSize()
        var selfPosSize = PosSize(x: selfX, y: selfY, size: Float(selfSize))
        for box in children {
            selfPosSize += box.posSize
        }
        return selfPosSize
    }
}

class BoundingBoxConverter {
    static func convertBoundingBoxes(boxes: [BoundingBox]) -> [FrameBlob] {
        let sortedBoxes = boxes.sorted{$0.getSize() > $1.getSize()}.map{BoundingBoxContainer(box: $0)}
        var combinedBoxes = [BoundingBoxContainer]()
        for box in sortedBoxes {
            var valid = true
            for validBox in combinedBoxes {
                if validBox.match(box: box) {
                    validBox.children.append(box)
                    valid = false
                    break
                }
            }
            if valid {
                combinedBoxes.append(box)
            }
        }
        return combinedBoxes.map{FrameBlob(box: $0.boundingBox)}
    }
}
