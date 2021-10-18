//
//  OpticalFlowMeasurementTypes.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 5/28/21.
//

#include <metal_stdlib>
using namespace metal;

class SmallRegionAccumulator {
    half4 columns[6];
    short2 externalOffset;

    bool2 didFillHalves;
    bool isEdge;

public:
    half2 opticalFlowAndArea;
    
    SmallRegionAccumulator(ushort2 externalCoords)
    {
        clearDepthCache();
        externalOffset = short2(externalCoords) - 1;

        isEdge = any(externalCoords == ushort2(0))
              || any(externalCoords == ushort2(252, 190));
    }

    half getOpticalFlow(ushort flowMask, texture2d<float, access::read> depthTexture)
    {
        if (flowMask == 0)
        {
            return 0;
        }

        opticalFlowAndArea[0] = 0;
        ushort2 flowMaskHalves = flowMask & ushort2(0x33, 0x33 << 2);

        if (flowMaskHalves[0] != 0)
        {
            prepareDepthHalf1(depthTexture);

            bool b = flowMaskHalves[0] == 0x33;
            
            if (b || bool(flowMask & 0x01)) { samplePixel(ushort2(0, 0), depthTexture); }
            if (b || bool(flowMask & 0x02)) { samplePixel(ushort2(1, 0), depthTexture); }
            if (b || bool(flowMask & 0x10)) { samplePixel(ushort2(0, 1), depthTexture); }
            if (b || bool(flowMask & 0x20)) { samplePixel(ushort2(1, 1), depthTexture); }
        }

        if (flowMaskHalves[1] != 0)
        {
            prepareDepthHalf2(depthTexture);

            bool b = flowMaskHalves[1] == 0x33 << 2;

            if (b || bool(flowMask & 0x04)) { samplePixel(ushort2(2, 0), depthTexture); }
            if (b || bool(flowMask & 0x08)) { samplePixel(ushort2(3, 0), depthTexture); }
            if (b || bool(flowMask & 0x40)) { samplePixel(ushort2(2, 1), depthTexture); }
            if (b || bool(flowMask & 0x80)) { samplePixel(ushort2(3, 1), depthTexture); }
        }

        return opticalFlowAndArea[0];
    }

    half getOpticalFlow(ushort flowMask, texture2d<float, access::read> depthTexture, ushort areaMask)
    {
        if (areaMask == 0)
        {
            opticalFlowAndArea[1] = 0;
            return 0;
        }

        opticalFlowAndArea = half2(0);
        ushort2 areaMaskHalves = areaMask & ushort2(0x33, 0x33 << 2);

        if (areaMaskHalves[0] != 0)
        {
            prepareDepthHalf1(depthTexture);

            bool b = areaMaskHalves[0] == 0x33;

            if (b || bool(areaMask & 0x01)) { samplePixel(ushort2(0, 0), depthTexture, flowMask, 0x01); }
            if (b || bool(areaMask & 0x02)) { samplePixel(ushort2(1, 0), depthTexture, flowMask, 0x02); }
            if (b || bool(areaMask & 0x10)) { samplePixel(ushort2(0, 1), depthTexture, flowMask, 0x10); }
            if (b || bool(areaMask & 0x20)) { samplePixel(ushort2(1, 1), depthTexture, flowMask, 0x20); }
        }

        if (areaMaskHalves[1] != 0)
        {
            prepareDepthHalf2(depthTexture);

            bool b = areaMaskHalves[1] == 0x33 << 2;

            if (b || bool(areaMask & 0x04)) { samplePixel(ushort2(2, 0), depthTexture, flowMask, 0x04); }
            if (b || bool(areaMask & 0x08)) { samplePixel(ushort2(3, 0), depthTexture, flowMask, 0x08); }
            if (b || bool(areaMask & 0x40)) { samplePixel(ushort2(2, 1), depthTexture, flowMask, 0x40); }
            if (b || bool(areaMask & 0x80)) { samplePixel(ushort2(3, 1), depthTexture, flowMask, 0x80); }
        }

        return opticalFlowAndArea[0];
    }

    void clearDepthCache()
    {
        didFillHalves = bool2(false);

        for (uchar i = 0; i < 6; ++i)
        {
            columns[i] = half4(NAN);
        }
    }

private:
    void prepareDepthHalf1(texture2d<float, access::read> depthTexture)
    {
        if (didFillHalves[0])
        {
            return;
        }

        didFillHalves[0] = true;
        fillColumnsCombined(0, select(4, 2, didFillHalves[1]), depthTexture);
    }

    void prepareDepthHalf2(texture2d<float, access::read> depthTexture)
    {
        if (didFillHalves[1])
        {
            return;
        }

        didFillHalves[1] = true;
        fillColumnsCombined(select(2, 4, didFillHalves[0]), 6, depthTexture);
    }

    void fillColumnsCombined(short columnStart, short columnEnd, texture2d<float, access::read> depthTexture)
    {
        for (short column = columnStart; column < columnEnd; ++column)
        {
            short  coordX  = externalOffset.x + column;
            short4 coordsY = externalOffset.y + short4(0, 1, 2, 3);

            if (isEdge)
            {
                coordX = clamp(coordX, short(0), short(255));

                coordsY[0] = max(coordsY[0], short(0));
                coordsY[3] = min(coordsY[3], short(191));
            }

            thread half4 *output = columns + column;

            output->x = depthTexture.read(ushort2(coordX, coordsY[0])).r;
            output->y = depthTexture.read(ushort2(coordX, coordsY[1])).r;
            output->z = depthTexture.read(ushort2(coordX, coordsY[2])).r;
            output->w = depthTexture.read(ushort2(coordX, coordsY[3])).r;
        }
    }

    half sampleDepth(ushort2 internalCoords, texture2d<float, access::read> depthTexture)
    {
        thread half4 *input = columns + internalCoords.x;

        if (internalCoords.y == 0)
        {
            return min3(min3(input[0].x, input[0].y, input[0].z),
                        min3(input[1].x, input[1].y, input[1].z),
                        min3(input[2].x, input[2].y, input[2].z));
        }
        else
        {
            return min3(min3(input[0].y, input[0].z, input[0].w),
                        min3(input[1].y, input[1].z, input[1].w),
                        min3(input[2].y, input[2].z, input[2].w));
        }
    }

    void samplePixel(ushort2 internalCoords, texture2d<float, access::read> depthTexture)
    {
        half depth = sampleDepth(internalCoords, depthTexture);
        bool2 depthComparisons = { depth < 0.15, depth > 0.8 };
        half depthSquared = depth * depth;

        if (any(depthComparisons))
        {
            if (depthComparisons[0])
            {
                opticalFlowAndArea[0] = fma(depthSquared, depthSquared, opticalFlowAndArea[0]);
            }

            return;
        }

        opticalFlowAndArea[0] = fma(depth, depthSquared, opticalFlowAndArea[0]);
    }

    void samplePixel(ushort2 internalCoords, texture2d<float, access::read> depthTexture, ushort flowMask, ushort selectionMask)
    {
        half depth = sampleDepth(internalCoords, depthTexture);
        bool2 depthComparisons = { depth < 0.15, depth > 0.8 };
        half depthSquared = depth * depth;
        
        if (any(depthComparisons))
        {
            if (depthComparisons[0])
            {
                if ((flowMask & selectionMask) != 0)
                {
                    opticalFlowAndArea = fma(half2(depthSquared, depth), depthSquared, opticalFlowAndArea);
                }
                else
                {
                    opticalFlowAndArea[1] = fma(depth, depthSquared, opticalFlowAndArea[1]);
                }
            }

            return;
        }
        
        if ((flowMask & selectionMask) != 0)
        {
            opticalFlowAndArea = {
                fma(depth, depthSquared,  opticalFlowAndArea[0]),
                           depthSquared + opticalFlowAndArea[1]
            };
        }
        else
        {
            opticalFlowAndArea[1] = depthSquared + opticalFlowAndArea[1];
        }
    }
};
