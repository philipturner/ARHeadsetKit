//
//  MemoryUtilities.h
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/15/21.
//

#ifndef MemoryUtilities_h
#define MemoryUtilities_h

#include <metal_stdlib>
using namespace metal;

namespace BinarySearch {
    ushort binarySearch(uint element, constant uint *list, ushort listSizeMinus1);
}

// Stores pairs of 32-bit indices as 24-bit
// indices to conserve main memory bandwidth

namespace DualID {
    ushort3 pack(uint2 id);
    ushort3 pack(uint x, uint y);
    uint2 unpack(ushort3 id);
    
    uint getX(ushort3 id);
    uint getY(ushort3 id);
    
    void setX(device ushort3 *id, uint x);
    void setY(device ushort3 *id, uint y);
}

// Stores 10 24-bit indices in the same
// amount of memory as 8 32-bit indices

namespace PackedID10 {
    uint get(device void *device_32_bytes, ushort index, uint bufferOffset = 0);
    void set(device void *device_32_bytes, ushort index, uint id, uint bufferOffset = 0);
}

// When writing to vector components, the Metal compiler
// reads the entire vector, then writes all components back.
//
// This can cause data races that corrupt memory when
// multiple threads write to the same vector, increase main
// memory bandwidth consumption, and increase shader execution
// time by adding unnecessary memory reads.
//
// These utilities ensure that memory writes to
// vector components happen correctly. Writing to vector
// components this way adds extra arithmetic operations,
// so it may not always improve performance.

#define declareFunc(funcName, scalar, vecSize)                  \
void funcName(device vec<scalar, vecSize> *pointer, uint id,    \
                         scalar value);                         \

#define declareMultiFunc(funcName, scalar, vecSize, inputSize)  \
void funcName(device vec<scalar, vecSize> *pointer, uint id,    \
                     vec<scalar, inputSize> value);             \

#define declareFuncFamily(scalar)                               \
declareFunc(setX, scalar, 2)                                    \
declareFunc(setY, scalar, 2)                                    \
                                                                \
declareFunc(setX, scalar, 4)                                    \
declareFunc(setY, scalar, 4)                                    \
declareFunc(setZ, scalar, 4)                                    \
declareFunc(setW, scalar, 4)                                    \
                                                                \
declareMultiFunc(setXY, scalar, 4, 2)                           \
declareMultiFunc(setXZ, scalar, 4, 2)                           \
declareMultiFunc(setXW, scalar, 4, 2)                           \
declareMultiFunc(setYZ, scalar, 4, 2)                           \
declareMultiFunc(setYW, scalar, 4, 2)                           \
declareMultiFunc(setZW, scalar, 4, 2)                           \
                                                                \
declareMultiFunc(setXYZ, scalar, 4, 3)                          \
declareMultiFunc(setXYW, scalar, 4, 3)                          \
declareMultiFunc(setXZW, scalar, 4, 3)                          \
declareMultiFunc(setYZW, scalar, 4, 3)                          \

namespace CorrectWrite {
    declareFuncFamily(bool)
    declareFuncFamily(uchar)
    declareFuncFamily(ushort)
    declareFuncFamily(uint)
    declareFuncFamily(ulong)
    
    declareFuncFamily(char)
    declareFuncFamily(short)
    declareFuncFamily(int)
    declareFuncFamily(long)
    
    declareFuncFamily(half)
    declareFuncFamily(float)
}

#endif /* MemoryUtilities_h */
