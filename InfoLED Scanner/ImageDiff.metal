//
//  ImageDiff.metal
//  InfoLED Scanner
//
//  Created by Jackie Yang on 4/21/17.
//  Copyright © 2017 yangjunrui. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

void sumX(uint2 tid, threadgroup float groupDiff[3][3][8][8], threadgroup int groupAvail[3][3][8][8], uint id) {
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (tid.x % (id * 2) == 0) {
        for (int i = 0; i <= 3; i++) {
            for (int j = 0; j <= 3; j++) {
                groupDiff[i][j][tid.x][tid.y] += groupDiff[i][j][tid.x + id][tid.y];
                groupAvail[i][j][tid.x][tid.y] += groupAvail[i][j][tid.x + id][tid.y];
            }
        }
    }
}

void sumY(uint2 tid, threadgroup float groupDiff[3][3][8][8], threadgroup int groupAvail[3][3][8][8], uint id) {
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (tid.y % (id * 2) == 0) {
        for (int i = 0; i <= 3; i++) {
            for (int j = 0; j <= 3; j++) {
                groupDiff[i][j][tid.x][tid.y] += groupDiff[i][j][tid.x][tid.y + id];
                groupAvail[i][j][tid.x][tid.y] += groupAvail[i][j][tid.x][tid.y + id];
            }
        }
    }
}

float safeDivide(float var1, int var2) {
    if (var2 != 0) {
        return var1 / var2;
    } else {
        return 100000;
    }
}

kernel void image_diff_2d(texture2d<float, access::read> thisFrame [[texture(0)]],
                          texture2d<float, access::read> lastFrame [[texture(1)]],
                          texture2d<float, access::write> outFrame [[texture(2)]],
                          uint2 gid [[thread_position_in_grid]],
                          uint2 tid [[thread_position_in_threadgroup]],
                          uint2 tidCount [[threads_per_threadgroup]])
{
    threadgroup float groupDiff[3][3][8][8];
    threadgroup int groupAvail[3][3][8][8];
    int range = 1;
    for (int i = int(gid.x) - range; i <= int(gid.x) + range; i++) {
        int index_i = i - (int(gid.x) - range);
        for (int j = int(gid.y) - range; j <= int(gid.y) + range; j++) {
            int index_j = j - (int(gid.y) - range);
            if (i >= 0 && j >= 0) {
                uint2 pos = uint2(i, j);
                float difference = length(thisFrame.read(gid).rgb - lastFrame.read(pos).rgb);
                groupDiff[index_i][index_j][tid.x][tid.y] = sqrt(difference);
                groupAvail[index_i][index_j][tid.x][tid.y] = 1;
            } else {
                groupDiff[index_i][index_j][tid.x][tid.y] = 0;
                groupAvail[index_i][index_j][tid.x][tid.y] = 0;
            }
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    sumX(tid, groupDiff, groupAvail, 1);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    sumX(tid, groupDiff, groupAvail, 2);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    sumX(tid, groupDiff, groupAvail, 4);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    sumY(tid, groupDiff, groupAvail, 1);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    sumY(tid, groupDiff, groupAvail, 2);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    sumY(tid, groupDiff, groupAvail, 4);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    float minDifference = safeDivide(groupDiff[3][3][0][0], groupAvail[3][3][0][0]);
    uint2 minPos = uint2(gid.x - 1, gid.y - 1);
    for (int i = int(gid.x) - range; i <= int(gid.x) + range; i++) {
        int index_i = i - (int(gid.x) - range);
        for (int j = int(gid.y) - range; j <= int(gid.y) + range; j++) {
            int index_j = j - (int(gid.y) - range);
            float difference = safeDivide(groupDiff[index_i][index_j][0][0], groupAvail[index_i][index_j][0][0]);
            uint2 pos = uint2(i, j);
            if (pos.x == gid.x && pos.y == gid.y) continue; //Ignore central point
            if (difference < minDifference) {
                minDifference = difference;
                minPos = pos;
            }

        }
    }
    float3 lastPixel = lastFrame.read(gid).rgb;
    float3 lastClosePixel = lastFrame.read(minPos).rgb;
    float3 largerPixel = max(lastPixel, lastClosePixel);
    float3 smallerPixel = min(lastPixel, lastClosePixel);
    float3 thisPixel = thisFrame.read(gid).rgb;
    float3 clampPixel = clamp(thisPixel, smallerPixel, largerPixel);
    float3 difference = fabs(thisPixel - clampPixel);
    float3 sum = thisFrame.read(gid).rgb + lastFrame.read(minPos).rgb;
    outFrame.write(float4(4 * difference, 1), gid);
    //    outFrame.write(float4((float2((int2(minPos) - int2(gid)) + range) / 3.0), 0, 1), gid);
    //    float pixel = groupDiff[1][1][tid.x][tid.y];
    //    float pixel = minDifference * 1000;
    //    outFrame.write(float4(500 * float3(pixel, pixel, pixel), 1), gid);
}
