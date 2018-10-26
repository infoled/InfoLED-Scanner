//
//  ImageDiff.metal
//  InfoLED Scanner
//
//  Created by Jackie Yang on 4/21/17.
//  Copyright © 2017 yangjunrui. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void image_diff_2d(texture2d<float, access::read> thisFrame [[texture(0)]],
                          texture2d<float, access::read> lastFrame [[texture(1)]],
                          texture2d<float, access::write> outFrame [[texture(2)]],
                          uint2 gid [[thread_position_in_grid]])
{
    outFrame.write(float4(4 * fabs(thisFrame.read(gid) - lastFrame.read(gid)).rgb, 1), gid);
}
