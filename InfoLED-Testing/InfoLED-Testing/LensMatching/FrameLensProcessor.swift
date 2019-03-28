//
//  FrameLensProcessor.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/22/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

import Foundation
#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

fileprivate let Debug = false;

class FrameBlob: CustomStringConvertible {
    var x: Float
    var y: Float
    var size: Int

    init(x: Float, y: Float, size: Int) {
        self.x = x
        self.y = y
        self.size = size
    }

    init(box: BoundingBox) {
        self.x = Float(Int(Double(box.x_start + box.x_end) / Constants.decimation / Constants.decimationCcl / 2))
        self.y = Float(Int(Double(box.y_start + box.y_end) / Constants.decimation / Constants.decimationCcl / 2))
        self.size = box.getSize()
    }

    fileprivate func assign(blob: FrameBlob?) {
        if let blob = blob {
            self.x = blob.x
            self.y = blob.y
            self.size = blob.size
        }
    }

    func copyBlob() -> FrameBlob {
        return FrameBlob(x: x, y: y, size: size)
    }

    func distance(with blob: FrameBlob) -> Float {
        let xDiff = (self.x - blob.x)
        let yDiff = (self.y - blob.y)

        return sqrt(Float(xDiff * xDiff + yDiff * yDiff))
    }

    var description: String {
        return "Blob((\(x), \(y), size: \(size))"
    }
}

class FrameLens: FrameBlob{
    static let MissingLimit = 240

    var history: Int
    var missing: Int

    var lens: HistoryLens?

    init(lens: HistoryLens) {
        self.lens = lens
        self.history = lens.lensHistory
        self.missing = lens.lensMissing
        let x = Float(lens.poiPos.x)
        let y = Float(lens.poiPos.y)
        let size = lens.lensSize
        super.init(x: x, y: y, size: size)
    }

    func syncLens() {
        lens?.lensHistory = self.history
        lens?.lensMissing = self.missing
        lens?.lensSize = self.size
        lens?.poiPos = CGPoint(x: Double(self.x), y: Double(self.y))
        if (self.history == 0) {
            lens = nil
        }
    }

    init(history: Int = 0, missing: Int = 0) {
        self.history = 0
        self.missing = 0
        super.init(x: 0, y: 0, size: 0)
    }

    override var description: String {
        return "FrameLens((\(x), \(y), size: \(size), history: \(history), missing: \(missing))"
    }

    override func assign(blob: FrameBlob?) {
        if let blob = blob {
            super.assign(blob: blob)
            self.history += 1
        } else {
            if self.history != 0 {
                self.missing += 1
                if self.missing > (self.history * 2) || self.missing > FrameLens.MissingLimit {
                    self.history = 0
                    self.missing = 0
                }
            }
        }
    }

    func lensWeight() -> Float {
        return (log(Float(2 * history) + 1) + 1) / (log(Float(missing) + 1) + 1)
    }

    func costToBlob(blob: FrameBlob?) -> Float {
        if let blob = blob {
            if history != 0 {
                return lensWeight() * (distance(with:blob) + abs(Float(self.size - blob.size)) / 2) / log(Float(missing + 1) + 1)
            } else {
                return 0
            }
        } else {
            let noMatchWeight = Float(300.0)
            return lensWeight() * noMatchWeight
        }
    }
}

//let blobDistanceThreshold = Float(100.0)
//
//func mergeBlobs(blobs: [FrameBlob]) -> [FrameBlob] {
//    let sortedBlobs = blobs.sorted {$0.size > $1.size}
//    var validBlobs = [FrameBlob]()
//
//    for blob in sortedBlobs {
//        var valid = true
//        for validBlob in validBlobs {
//            if validBlob.distance(with: blob) < blobDistanceThreshold {
//                valid = false
//                break
//            }
//        }
//        if valid {
//            validBlobs.append(blob)
//        }
//    }
//    return validBlobs
//}

class FrameLensProcessor {
    static func processFrame(currentLenses: [HistoryLens], boxes: [BoundingBox]) -> [HistoryLens] {
        let frameLenses = currentLenses.map{FrameLens.init(lens: $0)}
//        let rawBlobs = boxes.map{FrameBlob(box: $0)}
//        let blobs = mergeBlobs(blobs: rawBlobs)
        let blobs = BoundingBoxConverter.convertBoundingBoxes(boxes: boxes)
        let s = 0
        let t = 1
        let startBegin = 0
        let startEnd = startBegin + 2
        let lensesBegin = startEnd
        let lensesEnd = lensesBegin + frameLenses.count
        let blobsBegin = lensesEnd
        let blobsEnd = blobsBegin + blobs.count
        let lensShadowsBegin = blobsEnd
        let lensShadowsEnd = lensShadowsBegin + frameLenses.count

        let graph = FlowGraph(n: lensShadowsEnd)

        // from s to lenses & lensShadows to t
        for i in frameLenses.indices {
            graph.assignCost(cost: 0, from: s, to: lensesBegin + i)
            graph.assignCost(cost: 0, from: lensShadowsBegin + i, to: t)
        }

        // from blobs to t
        for i in blobs.indices {
            graph.assignCost(cost: 0, from: blobsBegin + i, to: t)
        }

        // from lenses to blobs
        for (i, lens) in frameLenses.enumerated() {
            for (j, blob) in blobs.enumerated() {
                graph.assignCost(cost: lens.costToBlob(blob: blob), from: lensesBegin + i, to: blobsBegin + j)
            }
        }

        // from lenses to lensShadows
        for (i, lens) in frameLenses.enumerated() {
            graph.assignCost(cost: lens.costToBlob(blob: nil), from: lensesBegin + i, to: lensShadowsBegin + i)
        }

        let _ = graph.minCostMaxFlow(source: s, sink: t)
        for i in frameLenses.indices {
            let lensNode = lensesBegin + i
            let matchedFlow = graph.flowMap[lensNode]
            for j in blobs.indices {
                let blobNode = blobsBegin + j
                if matchedFlow[blobNode] > 0 {
                    if Debug {
                        print("lens[\(i)] = \(frameLenses[i]) --> blob[\(j)] = \(blobs[j])")
                    }
                    frameLenses[i].assign(blob: blobs[j])
                }
            }
            let lensShadowNode = lensShadowsBegin + i
            if matchedFlow[lensShadowNode] > 0 {
                if Debug {
                    print("lens[\(i)] = \(frameLenses[i]) --> lensShadow[\(lensShadowNode)]")
                }
                frameLenses[i].assign(blob: nil)
            }
        }
        var result = [HistoryLens]()
        for lens in frameLenses {
            lens.syncLens()
            if let historyLens = lens.lens {
                result.append(historyLens)
            }
        }
        if Debug {
            print(result)
        }
        return result
    }
}
