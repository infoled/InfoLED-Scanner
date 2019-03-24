//
//  FlowGraph.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 3/22/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

class FlowGraph {
    var capcityMap: [[Int]]
    var costMap: [[Float]]
    var flowMap: [[Int]]
    var nodeCount: Int

    init(n: Int) {
        capcityMap = Array.init(repeating: Array.init(repeating: 0, count: n), count: n)
        flowMap = Array.init(repeating: Array.init(repeating: 0, count: n), count: n)
        costMap = Array.init(repeating: Array.init(repeating: Float(0), count: n), count: n)
        nodeCount = n
    }

    struct FlowCost {
        let flow: Int
        let cost: Float
    }


    func bellmanFord(source: Int, sink: Int) -> FlowCost {
        let q = Queue<Int>()
        var inQ = [Bool](repeating: false, count: nodeCount)
        var distance = [Float?](repeating: nil, count: nodeCount)
        var flowInc = [Int?](repeating: 0, count: nodeCount)
        var lastNode = [Int?](repeating: nil, count: nodeCount)

        inQ[source] = true
        q.enqueue(source)
        distance[source] = 0
        flowInc[source] = nil

        while true {
            guard let u = q.dequeue() else {
                break
            }
            inQ[u] = false
            for v in 0..<nodeCount {
                if capcityMap[u][v] > flowMap[u][v] &&
                    (distance[v] == nil || distance[v]! > distance[u]! + costMap[u][v]) {
                    distance[v] = distance[u]! + costMap[u][v]
                    lastNode[v] = u
                    if flowInc[u] != nil {
                        flowInc[v] = min(flowInc[u]!, capcityMap[u][v] - flowMap[u][v])
                    } else {
                        flowInc[v] = capcityMap[u][v] - flowMap[u][v]
                    }
                    if !inQ[v] {
                        q.enqueue(v)
                        inQ[v] = true
                    }
                }
            }
        }
        if distance[sink] == nil {
            return FlowCost(flow: 0, cost: Float(0))
        }
        var backtraceNode = sink
        while backtraceNode != source {
            guard let curLastNode = lastNode[backtraceNode] else {
                assert(false)
                return FlowCost(flow: 0, cost: 0)
            }
            flowMap[curLastNode][backtraceNode] += flowInc[sink]!
            flowMap[backtraceNode][curLastNode] -= flowInc[sink]!
            backtraceNode = curLastNode
        }
        return FlowCost(flow: flowInc[sink]!, cost: distance[sink]! * Float(flowInc[sink]!))
    }

    func minCostMaxFlow(source: Int, sink: Int) -> FlowCost {
        var flow = 0
        var cost = Float(0)
        while true {
            let flowCostInc = bellmanFord(source: source, sink: sink)
            if flowCostInc.flow == 0 {
                break
            }
            flow += flowCostInc.flow
            cost += flowCostInc.cost
        }
        return FlowCost(flow: flow, cost: cost)
    }

    func assignCapacityCost(capacity: Int, cost: Float, from i: Int, to j: Int) {
        capcityMap[i][j] = capacity
        costMap[i][j] = cost
    }

    func assignCost(cost: Float, from i: Int, to j: Int) {
        assignCapacityCost(capacity: 1, cost: cost, from: i, to: j)
    }
}
